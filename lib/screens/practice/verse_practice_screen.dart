import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import '../../services/auth_service.dart';
import '../../services/tts_service.dart';
import '../../services/recording_service.dart';
import '../../services/progress_service.dart';
import '../../services/esv_service.dart';
import '../../services/bible_data_service.dart';
import '../../services/pronunciation/azure_pronunciation_service.dart';
import '../../services/pronunciation/pronunciation_feedback_service.dart';
import '../../services/tutor/tutor_coordinator.dart';
import '../../services/social/group_activity_service.dart';
import '../../services/social/group_challenge_service.dart';
import '../../services/social/streak_service.dart';
import '../../services/review_service.dart';
import '../../widgets/social/streak_widget.dart';
import '../../widgets/pronunciation/pronunciation_widgets.dart';
import '../../models/learning_stage.dart';
import '../../models/verse_progress.dart';

/// 구절 연습 화면
/// - 3단계 학습: Listen & Repeat → Key Expressions → Real Speak
class VersePracticeScreen extends StatefulWidget {
  final AuthService authService;
  final String book;
  final int chapter;
  final int? initialVerse;

  const VersePracticeScreen({
    super.key,
    required this.authService,
    this.book = 'malachi',
    this.chapter = 1,
    this.initialVerse,
  });

  @override
  State<VersePracticeScreen> createState() => _VersePracticeScreenState();
}

class _VersePracticeScreenState extends State<VersePracticeScreen> {
  // 서비스
  final TTSService _tts = TTSService();
  final RecordingService _recorder = RecordingService();
  final ProgressService _progress = ProgressService();
  final EsvService _esv = EsvService();
  final BibleDataService _bibleData = BibleDataService.instance;
  final AzurePronunciationService _pronunciation = AzurePronunciationService();
  final PronunciationFeedbackService _feedbackService = PronunciationFeedbackService();
  final AudioPlayer _myVoicePlayer = AudioPlayer();
  final GroupActivityService _activityService = GroupActivityService();
  final GroupChallengeService _challengeService = GroupChallengeService();
  final StreakService _streakService = StreakService();
  final ReviewService _reviewService = ReviewService();

  // Cached book info
  String _bookNameKo = '';
  String _bookNameEn = '';

  // 상태
  int _currentVerseIndex = 0;
  LearningStage _currentStage = LearningStage.listenRepeat;
  bool _isTTSPlaying = false;
  bool _isTTSLoading = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isPlayingMyVoice = false;
  double _playbackSpeed = 1.0;

  // 로딩 상태
  bool _isLoadingVerses = true;
  String? _loadingError;

  String? _lastRecordingPath;
  PronunciationResult? _pronunciationResult;
  PronunciationFeedback? _feedback;
  TutorFeedback? _aiFeedback; // Gemini AI 피드백
  bool _isLoadingAiFeedback = false;
  Map<int, VerseProgress> _verseProgressMap = {};

  // 데이터
  List<VerseText> _verses = [];

  VerseText? get _currentVerse =>
      _verses.isNotEmpty ? _verses[_currentVerseIndex] : null;
  int get _totalVerses => _verses.length;

  VerseProgress? get _currentVerseProgress =>
      _currentVerse != null ? _verseProgressMap[_currentVerse!.verse] : null;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    // 웹과 모바일 모두 녹음기 초기화
    await _recorder.init();
    await _progress.init();
    await _loadVerses();
  }

  Future<void> _loadVerses() async {
    setState(() {
      _isLoadingVerses = true;
      _loadingError = null;
    });

    try {
      // 1단계: 책 이름 로드 (타임아웃 3초)
      final bookNames = await Future.wait([
        _bibleData.getBookNameKo(widget.book),
        _bibleData.getBookNameEn(widget.book),
      ]).timeout(const Duration(seconds: 3));

      _bookNameKo = bookNames[0];
      _bookNameEn = bookNames[1];

      // 2단계: ESV 구절 로드 (타임아웃 8초)
      final verses = await _esv.getChapter(
        book: _bookNameEn,
        chapter: widget.chapter,
      ).timeout(const Duration(seconds: 8));

      // 3단계: 한글 번역 병렬 로드 (타임아웃 5초, 실패해도 계속)
      List<String?> koreanTexts;
      try {
        final koreanFutures = verses.map((v) => _bibleData.getKoreanText(
          widget.book,
          widget.chapter,
          v.verse,
        )).toList();
        koreanTexts = await Future.wait(koreanFutures).timeout(const Duration(seconds: 5));
      } catch (e) {
        // 한글 로드 실패해도 영어만으로 진행
        print('⚠️ 한글 번역 로드 실패: $e');
        koreanTexts = List.filled(verses.length, null);
      }

      final versesWithKorean = <VerseText>[];
      for (int i = 0; i < verses.length; i++) {
        versesWithKorean.add(verses[i].copyWith(korean: koreanTexts[i]));
      }

      if (mounted) {
        setState(() {
          _verses = versesWithKorean;
          _isLoadingVerses = false;
        });
        // 진행 상태 로드 (비동기, 블로킹 안 함)
        _loadAllProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingError = '성경 데이터를 불러오는데 실패했습니다.\n$e';
          _isLoadingVerses = false;
        });
      }
    }
  }

  Future<void> _loadAllProgress() async {
    if (_verses.isEmpty) return;

    try {
      // 진행도 병렬 로드 (타임아웃 5초)
      final progressFutures = _verses.map((verse) => _progress.getVerseProgress(
        book: widget.book,
        chapter: widget.chapter,
        verse: verse.verse,
      )).toList();

      final progressList = await Future.wait(progressFutures).timeout(const Duration(seconds: 5));

      final progressMap = <int, VerseProgress>{};
      for (int i = 0; i < _verses.length; i++) {
        progressMap[_verses[i].verse] = progressList[i];
      }

      if (mounted) {
        setState(() {
          _verseProgressMap = progressMap;

          // initialVerse가 지정된 경우 해당 구절로 이동
          if (widget.initialVerse != null) {
            final initialIndex = _verses.indexWhere(
              (v) => v.verse == widget.initialVerse,
            );
            if (initialIndex >= 0) {
              _currentVerseIndex = initialIndex;
            }
          }

          // 현재 구절의 스테이지로 설정
          if (_currentVerseProgress != null) {
            _currentStage = _currentVerseProgress!.currentStage;
          }
        });
      }
    } catch (e) {
      // 진행 상태 로드 실패해도 계속 사용 가능
      print('⚠️ 진행 상태 로드 실패: $e');
    }
  }

  int get _completedCount => _verseProgressMap.values
      .where((p) => p.isCompleted)
      .length;

  double get _progressPercent =>
      _totalVerses > 0 ? _completedCount / _totalVerses : 0;

  void _goToPreviousVerse() {
    if (_currentVerseIndex > 0) {
      setState(() {
        _currentVerseIndex--;
        _resetState();
        _loadCurrentVerseStage();
      });
    }
  }

  void _goToNextVerse() {
    if (_currentVerseIndex < _verses.length - 1) {
      setState(() {
        _currentVerseIndex++;
        _resetState();
        _loadCurrentVerseStage();
      });
    }
  }

  void _loadCurrentVerseStage() {
    final progress = _currentVerseProgress;
    if (progress != null) {
      _currentStage = progress.currentStage;
    } else {
      _currentStage = LearningStage.listenRepeat;
    }
  }

  void _resetState() {
    _pronunciationResult = null;
    _feedback = null;
    _aiFeedback = null;
    _isLoadingAiFeedback = false;
    _lastRecordingPath = null;
  }

  void _selectStage(LearningStage stage) {
    final progress = _currentVerseProgress;
    if (progress == null) {
      // 진행 기록 없으면 Stage 1만 가능
      if (stage == LearningStage.listenRepeat) {
        setState(() {
          _currentStage = stage;
          _resetState();
        });
      }
      return;
    }

    // 잠금 해제 확인
    if (stage.stageNumber <= progress.currentStage.stageNumber) {
      setState(() {
        _currentStage = stage;
        _resetState();
      });
    } else {
      _showSnackBar(
        '이전 단계를 완료해야 잠금 해제됩니다',
        isError: true,
      );
    }
  }

  Future<void> _playTTS() async {
    if (_isTTSPlaying) {
      await _tts.stop();
      setState(() => _isTTSPlaying = false);
      return;
    }

    if (_currentVerse == null) return;

    setState(() => _isTTSLoading = true);

    try {
      final bookName = _bookNameEn;
      await _tts.playBibleVerse(
        book: bookName,
        chapter: widget.chapter,
        verse: _currentVerse!.verse,
      );

      setState(() {
        _isTTSPlaying = true;
        _isTTSLoading = false;
      });

      if (mounted) setState(() => _isTTSPlaying = false);
    } catch (e) {
      _showSnackBar('TTS 오류: $e', isError: true);
      setState(() {
        _isTTSLoading = false;
        _isTTSPlaying = false;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndEvaluate();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() => _resetState());

    final success = await _recorder.startRecording();
    if (success) {
      setState(() => _isRecording = true);
    } else {
      _showSnackBar('마이크 권한을 허용해주세요', isError: true);
    }
  }

  Future<void> _stopAndEvaluate() async {
    if (_currentVerse == null) return;

    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    try {
      final audioPath = await _recorder.stopRecording();

      if (audioPath == null) {
        _showSnackBar('녹음 파일 저장 실패', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      _lastRecordingPath = audioPath;

      // Azure 발음 평가
      final result = await _pronunciation.evaluate(
        audioFilePath: audioPath,
        referenceText: _currentVerse!.english,
      );

      if (!result.isSuccess) {
        _showSnackBar(result.errorMessage ?? '발음 평가 실패', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      // 로컬 피드백 생성 (즉시)
      final feedback = _feedbackService.generateFeedback(result);

      // AI 피드백 비동기 요청 (Gemini)
      _requestAiFeedback(result);

      // 점수 저장 (스테이지 포함)
      final updatedProgress = await _progress.saveScore(
        book: widget.book,
        chapter: widget.chapter,
        verse: _currentVerse!.verse,
        score: result.overallScore,
        stage: _currentStage,
      );

      // 진척도 맵 업데이트
      _verseProgressMap[_currentVerse!.verse] = updatedProgress;

      // 달란트 적립 (Stage 3에서 85% 이상)
      if (_currentStage == LearningStage.realSpeak &&
          result.overallScore >= LearningStage.realSpeak.passThreshold) {
        final added = await widget.authService.addTalant(_currentVerse!.verse);
        if (added) {
          _showSnackBar('달란트 +1 획득! 암송 완료!', isError: false);
        }
        // 복습 큐에 추가
        await _reviewService.addReviewItem(
          verseReference: '$_bookNameEn ${widget.chapter}:${_currentVerse!.verse}',
          book: widget.book,
          chapter: widget.chapter,
          verse: _currentVerse!.verse,
          verseText: _currentVerse!.english,
        );
      }

      // 스테이지 통과 처리
      final passed = _currentStage.isPassed(result.overallScore);

      // 그룹 활동, 챌린지 기여 및 스트릭 기록 (통과 시)
      if (passed) {
        _postActivityAndChallenge(
          isStage3: _currentStage == LearningStage.realSpeak,
        );
        // 스트릭 기록 (마일스톤 달성 시 알림)
        _recordStreakAndCheckMilestone();
      }

      setState(() {
        _pronunciationResult = result;
        _feedback = feedback;
        _isProcessing = false;
      });

      // Speak 스타일 바텀시트로 결과 표시
      _showResultBottomSheet(result, passed);
    } catch (e) {
      _showSnackBar('처리 중 오류: $e', isError: true);
      setState(() => _isProcessing = false);
    }
  }

  /// Speak 스타일 결과 바텀시트
  void _showResultBottomSheet(PronunciationResult result, bool passed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => _ResultBottomSheet(
        result: result,
        passed: passed,
        stage: _currentStage,
        aiFeedback: _aiFeedback,
        isLoadingAiFeedback: _isLoadingAiFeedback,
        onRetry: () {
          Navigator.pop(context);
          _resetState();
        },
        onNextStage: () {
          Navigator.pop(context);
          _goToNextStage();
        },
        onPlayMyVoice: _playMyVoice,
        isPlayingMyVoice: _isPlayingMyVoice,
      ),
    );
  }

  /// Gemini AI 피드백 비동기 요청 (기존 발음 결과 사용)
  Future<void> _requestAiFeedback(PronunciationResult result) async {
    if (!mounted) return;

    setState(() => _isLoadingAiFeedback = true);

    try {
      final tutor = TutorCoordinator.instance;
      // 이미 평가된 결과로 AI 피드백만 생성 (Azure 재호출 없음)
      final aiFeedback = await tutor.generateFeedbackFromResult(
        pronunciationResult: result,
        currentStage: _currentStage.stageNumber,
      );

      if (mounted && aiFeedback.isSuccess) {
        setState(() {
          _aiFeedback = aiFeedback;
          _isLoadingAiFeedback = false;
        });
        // AI 피드백 팁 토스트 표시
        _showAiTipToast(aiFeedback);
      } else {
        setState(() => _isLoadingAiFeedback = false);
      }
    } catch (e) {
      print('❌ AI 피드백 오류: $e');
      if (mounted) {
        setState(() => _isLoadingAiFeedback = false);
      }
    }
  }

  /// AI 코치 팁 토스트 표시
  void _showAiTipToast(TutorFeedback feedback) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber.shade300, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.encouragement,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (feedback.detailedFeedback.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      feedback.detailedFeedback,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _goToNextStage() {
    final nextStage = _currentStage.nextStage;
    if (nextStage != null) {
      setState(() {
        _currentStage = nextStage;
        _resetState();
      });
    }
  }

  Future<void> _playMyVoice() async {
    if (_lastRecordingPath == null) return;

    if (_isPlayingMyVoice) {
      await _myVoicePlayer.stop();
      setState(() => _isPlayingMyVoice = false);
      return;
    }

    try {
      setState(() => _isPlayingMyVoice = true);
      // 웹에서는 blob URL을 UrlSource로 재생
      if (kIsWeb) {
        await _myVoicePlayer.play(UrlSource(_lastRecordingPath!));
      } else {
        await _myVoicePlayer.play(DeviceFileSource(_lastRecordingPath!));
      }
      _myVoicePlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlayingMyVoice = false);
      });
    } catch (e) {
      setState(() => _isPlayingMyVoice = false);
      _showSnackBar('재생 오류', isError: true);
    }
  }

  /// 스트릭 기록 및 마일스톤 체크
  Future<void> _recordStreakAndCheckMilestone() async {
    try {
      final milestone = await _streakService.recordLearning();

      // 마일스톤 달성 시 축하 다이얼로그 표시
      if (milestone != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => MilestoneAchievedDialog(
            milestone: milestone,
            onDismiss: () => Navigator.pop(context),
          ),
        );
      }
    } catch (e) {
      print('스트릭 기록 오류: $e');
    }
  }

  /// 그룹 활동 게시 및 챌린지 기여 (비동기, UI 블로킹 없음)
  Future<void> _postActivityAndChallenge({bool isStage3 = false}) async {
    final user = widget.authService.currentUser;
    if (user == null || user.groupId.isEmpty || _currentVerse == null) return;

    final verseRef = '$_bookNameKo ${widget.chapter}:${_currentVerse!.verse}';

    // 비동기로 처리 (await 없이 fire-and-forget)
    _activityService.postVerseComplete(
      groupId: user.groupId,
      userName: user.name,
      verseRef: verseRef,
      isStage3: isStage3,
    );

    // 챌린지 기여도 추가
    _challengeService.addContribution(
      groupId: user.groupId,
      userName: user.name,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.lightGreen.shade700;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  /// Stage 2: 핵심 단어를 빈칸으로 변환
  String _getBlankText(String text) {
    final words = text.split(' ');
    final keyWords = _getKeyWords(text);

    return words.map((word) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      if (keyWords.contains(cleanWord)) {
        // 구두점 유지
        final punctuation = word.replaceAll(RegExp(r'\w'), '');
        return '_____$punctuation';
      }
      return word;
    }).join(' ');
  }

  /// 핵심 단어 추출 (명사, 동사 위주)
  List<String> _getKeyWords(String text) {
    final words = text.split(' ');
    final keyWords = <String>[];

    // 간단한 휴리스틱: 4글자 이상 단어 중 일부 선택
    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      if (cleanWord.length >= 4 && keyWords.length < 3) {
        // 일반적인 단어 제외
        if (!['have', 'with', 'that', 'this', 'from', 'will', 'been', 'were']
            .contains(cleanWord)) {
          keyWords.add(cleanWord);
        }
      }
    }

    return keyWords;
  }

  @override
  void dispose() {
    _tts.dispose();
    _recorder.dispose();
    _myVoicePlayer.dispose();
    super.dispose();
  }

  // 디자인 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          _currentVerse != null
              ? '$_bookNameKo ${widget.chapter}장 ${_currentVerse!.verse}절'
              : '$_bookNameKo ${widget.chapter}장',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingVerses) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _accentColor),
            const SizedBox(height: 16),
            Text(
              '성경 구절을 불러오는 중...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    if (_loadingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _loadingError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadVerses,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_verses.isEmpty) {
      return Center(
        child: Text(
          '구절 데이터가 없습니다.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }

    return Column(
      children: [
        _buildProgressBar(),
        _buildStageIndicator(),
        _buildVerseNavigator(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildVerseCard(),
                const SizedBox(height: 20),
                _buildControlButtons(),
                const SizedBox(height: 12),
                _buildSpeedControl(),
                const SizedBox(height: 20),
                if (_pronunciationResult != null) _buildResultCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, Colors.purple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('학습 진척도',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('$_completedCount / $_totalVerses 구절 완료',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progressPercent,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                _progressPercent >= 1.0 ? Colors.amber : Colors.greenAccent,
              ),
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageIndicator() {
    final progress = _currentVerseProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: LearningStage.values.map((stage) {
          final isUnlocked = progress == null
              ? stage == LearningStage.listenRepeat
              : stage.stageNumber <= progress.currentStage.stageNumber;
          final isCurrentStage = stage == _currentStage;
          final stageProgress = progress?.stages[stage];
          final isPassed = stageProgress != null &&
              stage.isPassed(stageProgress.bestScore);

          return Expanded(
            child: GestureDetector(
              onTap: () => _selectStage(stage),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrentStage
                      ? _accentColor
                      : (isPassed ? Colors.green.withValues(alpha: 0.2) : _bgColor),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentStage
                        ? _accentColor
                        : (isPassed ? Colors.green : Colors.white.withValues(alpha: 0.2)),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    // 스테이지 아이콘
                    Icon(
                      isPassed
                          ? Icons.check_circle
                          : (isUnlocked ? _getStageIcon(stage) : Icons.lock),
                      color: isCurrentStage
                          ? Colors.white
                          : (isPassed
                              ? Colors.green
                              : (isUnlocked ? _accentColor : Colors.grey)),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    // 스테이지 번호
                    Text(
                      'Stage ${stage.stageNumber}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isCurrentStage ? Colors.white70 : Colors.white54,
                      ),
                    ),
                    // 스테이지 이름
                    Text(
                      stage.koreanName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCurrentStage
                            ? Colors.white
                            : (isPassed ? Colors.green : Colors.white70),
                      ),
                    ),
                    // 최고 점수
                    if (stageProgress != null)
                      Text(
                        '${stageProgress.bestScore.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentStage
                              ? Colors.white70
                              : _getScoreColor(stageProgress.bestScore),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getStageIcon(LearningStage stage) {
    switch (stage) {
      case LearningStage.listenRepeat:
        return Icons.hearing;
      case LearningStage.keyExpressions:
        return Icons.edit_note;
      case LearningStage.realSpeak:
        return Icons.record_voice_over;
    }
  }

  Widget _buildVerseNavigator() {
    if (_currentVerse == null) return const SizedBox.shrink();

    final progress = _currentVerseProgress;
    final isCompleted = progress?.isCompleted ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: _bgColor),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentVerseIndex > 0 ? _goToPreviousVerse : null,
            icon: const Icon(Icons.chevron_left, size: 30),
            color: _accentColor,
            disabledColor: Colors.white24,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withValues(alpha: 0.2) : _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCompleted ? Colors.green : _accentColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ),
                Text(
                  '${_currentVerse!.verse}절',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.green : _accentColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _currentVerseIndex < _verses.length - 1 ? _goToNextVerse : null,
            icon: const Icon(Icons.chevron_right, size: 30),
            color: _accentColor,
            disabledColor: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildVerseCard() {
    if (_currentVerse == null) return const SizedBox.shrink();

    final korean = _currentVerse!.korean;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 스테이지 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentColor, Colors.purple.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStageIcon(_currentStage), color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _currentStage.englishName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // 통과 기준 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '통과 기준: ${_currentStage.passThreshold.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isTTSLoading ? null : _playTTS,
                  icon: _isTTSLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accentColor,
                          ),
                        )
                      : Icon(
                          _isTTSPlaying ? Icons.stop_circle : Icons.play_circle,
                          size: 32,
                          color: _isTTSPlaying ? Colors.red : _accentColor,
                        ),
                  tooltip: _isTTSPlaying ? '중지' : '듣기',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 스테이지별 텍스트 표시
            _buildStageContent(korean),
          ],
        ),
      ),
    );
  }

  Widget _buildStageContent(String? korean) {
    switch (_currentStage) {
      case LearningStage.listenRepeat:
        // Stage 1: 전체 텍스트 표시
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('English',
                style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor)),
            const SizedBox(height: 8),
            Text(_currentVerse!.english,
                style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.white)),
            const SizedBox(height: 16),
            const Text('한국어',
                style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor)),
            const SizedBox(height: 8),
            Text(
              korean ?? '(한글 번역 준비 중)',
              style: TextStyle(
                fontSize: 16, height: 1.6,
                color: korean != null ? Colors.white70 : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.blue.shade300, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '전체 문장을 보면서 원어민 발음을 듣고 따라해보세요.',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade300),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case LearningStage.keyExpressions:
        // Stage 2: 빈칸 채우기
        final blankText = _getBlankText(_currentVerse!.english);
        final keyWords = _getKeyWords(_currentVerse!.english);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('빈칸을 채우며 말해보세요',
                style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor)),
            const SizedBox(height: 8),
            Text(blankText, style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.white)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                const Text('힌트: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                ...keyWords.map((word) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(word, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.amber)),
                )),
              ],
            ),
            const SizedBox(height: 16),
            const Text('한국어',
                style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor)),
            const SizedBox(height: 8),
            Text(
              korean ?? '(한글 번역 준비 중)',
              style: TextStyle(fontSize: 16, height: 1.6,
                  color: korean != null ? Colors.white70 : Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.orange.shade300, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '핵심 단어를 기억하며 전체 문장을 말해보세요.',
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade300),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case LearningStage.realSpeak:
        // Stage 3: 영어 텍스트 숨김
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.visibility_off, size: 48, color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    '영어 텍스트 없이 암송하세요',
                    style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('한국어 (참고용)',
                style: TextStyle(fontWeight: FontWeight.bold, color: _accentColor)),
            const SizedBox(height: 8),
            Text(
              korean ?? '(한글 번역 준비 중)',
              style: TextStyle(fontSize: 16, height: 1.6,
                  color: korean != null ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.purple.shade300, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '최종 단계입니다! 85% 이상 달성하면 암송 완료!',
                      style: TextStyle(fontSize: 13, color: Colors.purple.shade300),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                (_isProcessing || _isTTSPlaying || _currentVerse == null)
                    ? null
                    : _toggleRecording,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_isRecording ? Icons.stop : Icons.mic, size: 24),
            label: Text(
              _isProcessing
                  ? '발음 분석 중...'
                  : (_isRecording ? '녹음 중지' : '암송 시작'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.red : _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedControl() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('재생 속도', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_playbackSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('0.5x', style: TextStyle(fontSize: 12, color: Colors.white54)),
              Expanded(
                child: Slider(
                  value: _playbackSpeed,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  activeColor: _accentColor,
                  inactiveColor: Colors.white24,
                  onChanged: (value) {
                    setState(() => _playbackSpeed = value);
                    _tts.setPlaybackRate(value);
                  },
                ),
              ),
              const Text('1.5x', style: TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _pronunciationResult!;
    final feedback = _feedback;
    final passed = _currentStage.isPassed(result.overallScore);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreHeader(result, passed),
            const SizedBox(height: 16),
            _buildDetailedScores(result),

            // AI 피드백 (Gemini)
            if (_aiFeedback != null && _aiFeedback!.isSuccess) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.withValues(alpha: 0.15), Colors.purple.withValues(alpha: 0.15)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.blue.shade300),
                        const SizedBox(width: 6),
                        Text(
                          'AI 코치 피드백',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiFeedback!.encouragement,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                    if (_aiFeedback!.detailedFeedback.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _aiFeedback!.detailedFeedback,
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (_isLoadingAiFeedback) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade300),
                    ),
                    const SizedBox(width: 10),
                    Text('AI 코치가 분석 중...', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ] else if (feedback != null) ...[
              // 로컬 피드백 (AI 실패 시 fallback)
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.withValues(alpha: 0.15), _accentColor.withValues(alpha: 0.15)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  feedback.encouragement,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ),
            ],

            if (feedback != null && feedback.hasIssues) ...[
              const SizedBox(height: 16),
              _buildWordFeedback(feedback),
            ],

            if (feedback != null && feedback.tips.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPronunciationTips(feedback),
            ],

            const SizedBox(height: 16),
            _buildRecognizedText(result),

            const SizedBox(height: 16),
            _buildActionButtons(passed),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreHeader(PronunciationResult result, bool passed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: passed ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: passed ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '등급: ${result.grade}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (passed)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PASS!',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                ],
              ),
              Text(
                passed
                    ? '${_currentStage.koreanName} 통과!'
                    : '${_currentStage.passThreshold.toStringAsFixed(0)}% 이상 필요',
                style: TextStyle(
                  fontSize: 12,
                  color: passed ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${result.overallScore.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getScoreColor(result.overallScore),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedScores(PronunciationResult result) {
    return Column(
      children: [
        // 기존 점수 행
        Row(
          children: [
            Expanded(child: _buildScoreItem('정확도', result.accuracyScore, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _buildScoreItem('유창성', result.fluencyScore, Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _buildScoreItem('운율', result.prosodyScore, Colors.purple)),
          ],
        ),
        // 취약 음소 표시 (있을 경우만)
        if (result.weakestPhonemes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildWeakPhonemesSection(result),
        ],
      ],
    );
  }

  /// 취약 음소 섹션
  Widget _buildWeakPhonemesSection(PronunciationResult result) {
    final weakPhonemes = result.weakestPhonemes.take(4).toList();
    if (weakPhonemes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over, size: 16, color: Colors.orange[300]),
              const SizedBox(width: 8),
              Text(
                '집중 연습이 필요한 발음',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[300],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: weakPhonemes.map((phoneme) => _buildWeakPhonemeChip(phoneme)).toList(),
          ),
        ],
      ),
    );
  }

  /// 취약 음소 칩 (확장된 정보)
  Widget _buildWeakPhonemeChip(PhonemePronunciation phoneme) {
    return GestureDetector(
      onTap: () => _showPhonemeHelpDialog(phoneme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // IPA 심볼
            Text(
              phoneme.phoneme,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 6),
            // 한글 힌트
            Text(
              phoneme.koreanHint,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(width: 6),
            // 점수
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${phoneme.accuracyScore.toInt()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 음소 도움말 다이얼로그
  void _showPhonemeHelpDialog(PhonemePronunciation phoneme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                phoneme.phoneme,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                phoneme.koreanHint,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 점수 바
            PhonemeScoreBar(phoneme: phoneme, showTip: true),
            // 추가 팁
            if (phoneme.pronunciationTip != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, size: 16, color: Colors.amber[300]),
                        const SizedBox(width: 8),
                        Text(
                          '발음 팁',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[300],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phoneme.pronunciationTip!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, double score, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            '${score.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildWordFeedback(PronunciationFeedback feedback) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              const Text('단어별 발음 분석',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
              const Spacer(),
              Text(
                '탭하여 상세 보기',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 단어별 피드백 (탭 가능)
          ...feedback.details.take(6).map((detail) => _buildTappableWordCard(detail)),
        ],
      ),
    );
  }

  /// 탭 가능한 단어 카드
  Widget _buildTappableWordCard(FeedbackDetail detail) {
    // 원본 결과에서 해당 단어의 WordPronunciation 찾기
    final wordPronunciation = _pronunciationResult?.words.firstWhere(
      (w) => w.word.toLowerCase() == detail.word.toLowerCase(),
      orElse: () => WordPronunciation(
        word: detail.word,
        accuracyScore: detail.score,
        errorType: detail.status == FeedbackStatus.omitted ? 'Omission' : 'None',
        phonemes: detail.phonemeIssues.map((p) => PhonemePronunciation(
          phoneme: p.phoneme,
          accuracyScore: p.score,
        )).toList(),
      ),
    );

    return GestureDetector(
      onTap: () => _showWordDetailPopup(wordPronunciation!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getStatusColor(detail.status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _getStatusColor(detail.status).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 단어 + 점수
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getStatusColor(detail.status),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    detail.word,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detail.message,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(detail.score).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${detail.score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(detail.score),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ],
            ),
            // 음소 칩 (스코어 포함)
            if (detail.phonemeIssues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: detail.phonemeIssues.take(5).map((p) => PhonemeChip(
                  phoneme: PhonemePronunciation(
                    phoneme: p.phoneme,
                    accuracyScore: p.score,
                  ),
                  onTap: () => _showWordDetailPopup(wordPronunciation!),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 단어 상세 팝업 표시
  void _showWordDetailPopup(WordPronunciation word) {
    WordPronunciationPopup.show(
      context,
      word,
      onPlayWord: (text) async {
        // ElevenLabs TTS로 단어 재생
        try {
          await _tts.speakWithElevenLabs(text);
        } catch (e) {
          debugPrint('TTS 재생 실패: $e');
        }
      },
    );
  }

  Color _getStatusColor(FeedbackStatus status) {
    switch (status) {
      case FeedbackStatus.correct:
        return Colors.green;
      case FeedbackStatus.needsImprovement:
        return Colors.orange;
      case FeedbackStatus.incorrect:
        return Colors.red;
      case FeedbackStatus.omitted:
        return Colors.grey;
    }
  }

  Widget _buildPronunciationTips(PronunciationFeedback feedback) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, size: 18, color: Colors.blue),
              SizedBox(width: 8),
              Text('발음 팁', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 8),
          ...feedback.tips.take(3).map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(tip, style: const TextStyle(fontSize: 13, height: 1.4)),
          )),
        ],
      ),
    );
  }

  Widget _buildRecognizedText(PronunciationResult result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('인식된 발음', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            result.recognizedText.isEmpty ? '(인식된 내용 없음)' : result.recognizedText,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool passed) {
    return Row(
      children: [
        if (_lastRecordingPath != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _playMyVoice,
              icon: Icon(_isPlayingMyVoice ? Icons.stop : Icons.person, size: 18),
              label: Text(_isPlayingMyVoice ? '중지' : '내 목소리'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (_lastRecordingPath != null) const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTTSPlaying ? null : _playTTS,
            icon: Icon(_isTTSPlaying ? Icons.stop : Icons.record_voice_over, size: 18),
            label: Text(_isTTSPlaying ? '중지' : '원어민'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (passed && _currentStage.nextStage != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _goToNextStage,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('다음 단계'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Speak 스타일 결과 바텀시트 (다크 테마)
class _ResultBottomSheet extends StatelessWidget {
  final PronunciationResult result;
  final bool passed;
  final LearningStage stage;
  final TutorFeedback? aiFeedback;
  final bool isLoadingAiFeedback;
  final VoidCallback onRetry;
  final VoidCallback onNextStage;
  final VoidCallback onPlayMyVoice;
  final bool isPlayingMyVoice;

  // 다크 테마 색상 상수
  static const _bgColor = Color(0xFF1E1E2E);
  static const _cardColor = Color(0xFF2A2A3E);
  static const _accentColor = Color(0xFF6C63FF);
  static const _successColor = Color(0xFF4CAF50);
  static const _warningColor = Color(0xFFFF9800);

  const _ResultBottomSheet({
    required this.result,
    required this.passed,
    required this.stage,
    required this.aiFeedback,
    required this.isLoadingAiFeedback,
    required this.onRetry,
    required this.onNextStage,
    required this.onPlayMyVoice,
    required this.isPlayingMyVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // 점수 표시 (Speak 스타일)
              _buildScoreCircle(),
              const SizedBox(height: 16),

              // 통과/실패 텍스트
              Text(
                passed ? '${stage.koreanName} 통과!' : '다시 도전해보세요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: passed ? _successColor : _warningColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '통과 기준: ${stage.passThreshold.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),

              // AI 코치 피드백
              _buildAiFeedbackSection(),
              const SizedBox(height: 24),

              // 액션 버튼들
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCircle() {
    final scoreColor = passed ? _successColor : _warningColor;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scoreColor.withValues(alpha: 0.8),
            scoreColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${result.overallScore.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            '%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiFeedbackSection() {
    if (isLoadingAiFeedback) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'AI 코치가 분석 중...',
              style: TextStyle(color: _accentColor),
            ),
          ],
        ),
      );
    }

    if (aiFeedback != null && aiFeedback!.isSuccess) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _accentColor.withValues(alpha: 0.2),
              const Color(0xFF9C27B0).withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: _accentColor),
                const SizedBox(width: 8),
                Text(
                  'AI 코치',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              aiFeedback!.encouragement,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (aiFeedback!.detailedFeedback.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                aiFeedback!.detailedFeedback,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 기본 피드백 (AI 없을 때)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        passed
            ? '잘하셨어요! 다음 단계로 넘어가세요.'
            : '천천히 또박또박 다시 읽어보세요.',
        style: TextStyle(
          fontSize: 15,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // 내 목소리 듣기
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPlayMyVoice,
            icon: Icon(
              isPlayingMyVoice ? Icons.stop : Icons.headphones,
              size: 20,
            ),
            label: Text(isPlayingMyVoice ? '중지' : '내 목소리'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 다시 시도 / 다음 단계
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: passed && stage.nextStage != null ? onNextStage : onRetry,
            icon: Icon(
              passed && stage.nextStage != null
                  ? Icons.arrow_forward
                  : Icons.refresh,
              size: 20,
            ),
            label: Text(
              passed && stage.nextStage != null ? '다음 단계' : '다시 도전',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: passed ? _successColor : _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
