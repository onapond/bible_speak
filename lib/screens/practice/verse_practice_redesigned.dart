import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/auth_provider.dart';
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
import '../../services/achievement_service.dart';
import '../../styles/parchment_theme.dart';
import '../../widgets/social/streak_widget.dart';
import '../../widgets/ux_widgets.dart';
import '../../widgets/verse_memorization_card.dart';
import '../../models/learning_stage.dart';
import '../../models/verse_progress.dart';

/// 리디자인된 구절 연습 화면
/// Warm Parchment Theme 적용
/// - 따뜻한 양피지 색상
/// - 골드 악센트
/// - 영적/명상적 분위기
class VersePracticeRedesigned extends ConsumerStatefulWidget {
  final String book;
  final int chapter;
  final int? initialVerse;
  final String? dailyVerseKoreanText;

  const VersePracticeRedesigned({
    super.key,
    this.book = 'malachi',
    this.chapter = 1,
    this.initialVerse,
    this.dailyVerseKoreanText,
  });

  @override
  ConsumerState<VersePracticeRedesigned> createState() => _VersePracticeRedesignedState();
}

class _VersePracticeRedesignedState extends ConsumerState<VersePracticeRedesigned>
    with TickerProviderStateMixin {
  // Parchment 테마 색상
  static const _primaryColor = ParchmentTheme.manuscriptGold;
  static const _primaryLight = ParchmentTheme.goldHighlight;
  static const _successColor = ParchmentTheme.success;
  static const _warningColor = ParchmentTheme.warning;
  static const _bgGradientStart = ParchmentTheme.softPapyrus;
  static const _bgGradientEnd = ParchmentTheme.warmVellum;

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
  bool _isAudioReady = false;

  String? _lastRecordingPath;
  TutorFeedback? _aiFeedback;
  bool _isLoadingAiFeedback = false;
  Map<int, VerseProgress> _verseProgressMap = {};

  // 데이터
  List<VerseText> _verses = [];

  // 애니메이션
  late AnimationController _bgAnimationController;
  late Animation<double> _bgAnimation;

  VerseText? get _currentVerse =>
      _verses.isNotEmpty ? _verses[_currentVerseIndex] : null;
  int get _totalVerses => _verses.length;

  VerseProgress? get _currentVerseProgress =>
      _currentVerse != null ? _verseProgressMap[_currentVerse!.verse] : null;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initServices();
  }

  void _initAnimations() {
    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _bgAnimation = Tween<double>(begin: 0, end: 1).animate(_bgAnimationController);
    _bgAnimationController.repeat(reverse: true);
  }

  Future<void> _initServices() async {
    await Future.wait([
      _recorder.init().then((_) => _recorder.preCheckPermission()),
      _progress.init(),
    ]);
    await _loadVerses();
  }

  Future<void> _loadVerses() async {
    setState(() {
      _isLoadingVerses = true;
      _loadingError = null;
    });

    try {
      final bookNames = await Future.wait([
        _bibleData.getBookNameKo(widget.book),
        _bibleData.getBookNameEn(widget.book),
      ]).timeout(const Duration(seconds: 3));

      _bookNameKo = bookNames[0];
      _bookNameEn = bookNames[1];

      if (kIsWeb) {
        final initialVerse = widget.initialVerse ?? 1;
        _tts.preloadWebAudio(
          book: _bookNameEn,
          chapter: widget.chapter,
          verse: initialVerse,
          onComplete: () {
            if (mounted) setState(() => _isAudioReady = true);
          },
        );
      } else {
        _isAudioReady = true;
      }

      final verses = await _esv.getChapter(
        book: _bookNameEn,
        chapter: widget.chapter,
      ).timeout(const Duration(seconds: 8));

      List<String?> koreanTexts;
      final initialVerse = widget.initialVerse;
      final dailyKorean = widget.dailyVerseKoreanText;

      try {
        final koreanFutures = verses.map((v) => _bibleData.getKoreanText(
          widget.book,
          widget.chapter,
          v.verse,
        )).toList();
        koreanTexts = await Future.wait(koreanFutures).timeout(const Duration(seconds: 5));

        if (dailyKorean != null && dailyKorean.isNotEmpty && initialVerse != null) {
          for (int i = 0; i < verses.length; i++) {
            if (verses[i].verse == initialVerse && (koreanTexts[i] == null || koreanTexts[i]!.isEmpty)) {
              koreanTexts[i] = dailyKorean;
            }
          }
        }
      } catch (e) {
        koreanTexts = List.filled(verses.length, null);
        if (dailyKorean != null && dailyKorean.isNotEmpty && initialVerse != null) {
          for (int i = 0; i < verses.length; i++) {
            if (verses[i].verse == initialVerse) {
              koreanTexts[i] = dailyKorean;
            }
          }
        }
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
        _loadAllProgress();
        _preloadInitialAudio();
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

          if (widget.initialVerse != null) {
            final initialIndex = _verses.indexWhere(
              (v) => v.verse == widget.initialVerse,
            );
            if (initialIndex >= 0) {
              _currentVerseIndex = initialIndex;
            }
          }

          if (_currentVerseProgress != null) {
            _currentStage = _currentVerseProgress!.currentStage;
          }
        });
      }
    } catch (e) {
      debugPrint('진행 상태 로드 실패: $e');
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
        _checkAudioReady();
      });
      _preloadCurrentVerseAudio();
    }
  }

  void _goToNextVerse() {
    if (_currentVerseIndex < _verses.length - 1) {
      setState(() {
        _currentVerseIndex++;
        _resetState();
        _loadCurrentVerseStage();
        _checkAudioReady();
      });
      _preloadCurrentVerseAudio();
    }
  }

  void _preloadCurrentVerseAudio() {
    if (!kIsWeb || _currentVerse == null) return;
    if (_isAudioReady) return;

    _tts.preloadWebAudio(
      book: _bookNameEn,
      chapter: widget.chapter,
      verse: _currentVerse!.verse,
      onComplete: () {
        if (mounted) setState(() => _isAudioReady = true);
      },
    );
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
    _aiFeedback = null;
    _isLoadingAiFeedback = false;
    _lastRecordingPath = null;
  }

  void _selectStage(LearningStage stage) {
    final progress = _currentVerseProgress;
    if (progress == null) {
      if (stage == LearningStage.listenRepeat) {
        setState(() {
          _currentStage = stage;
          _resetState();
        });
      }
      return;
    }

    if (stage.stageNumber <= progress.currentStage.stageNumber) {
      setState(() {
        _currentStage = stage;
        _resetState();
      });
    } else {
      _showSnackBar('이전 단계를 완료해야 잠금 해제됩니다', isError: true);
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
      await _tts.playBibleVerse(
        book: _bookNameEn,
        chapter: widget.chapter,
        verse: _currentVerse!.verse,
      );

      setState(() {
        _isTTSPlaying = true;
        _isTTSLoading = false;
      });

      _preloadNextAudio();

      if (mounted) setState(() => _isTTSPlaying = false);
    } catch (e) {
      _showSnackBar('TTS 오류: $e', isError: true);
      setState(() {
        _isTTSLoading = false;
        _isTTSPlaying = false;
      });
    }
  }

  void _preloadNextAudio() {
    if (!kIsWeb || _currentVerse == null) return;
    if (_currentVerseIndex + 1 >= _totalVerses) return;

    final nextVerse = _verses[_currentVerseIndex + 1];
    _tts.preloadWebAudio(
      book: _bookNameEn,
      chapter: widget.chapter,
      verse: nextVerse.verse,
    );
  }

  void _preloadInitialAudio() {
    if (!kIsWeb || _verses.isEmpty) return;

    final firstVerse = _verses[_currentVerseIndex];
    _tts.preloadWebAudio(
      book: _bookNameEn,
      chapter: widget.chapter,
      verse: firstVerse.verse,
      onComplete: () {
        if (mounted) setState(() => _isAudioReady = true);
      },
    );
  }

  void _checkAudioReady() {
    if (!kIsWeb || _currentVerse == null) {
      _isAudioReady = true;
      return;
    }
    _isAudioReady = _tts.isWebAudioCached(
      book: _bookNameEn,
      chapter: widget.chapter,
      verse: _currentVerse!.verse,
    );
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

      final result = await _pronunciation.evaluate(
        audioFilePath: audioPath,
        referenceText: _currentVerse!.english,
      );

      if (!result.isSuccess) {
        _showSnackBar(result.errorMessage ?? '발음 평가 실패', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      final feedback = _feedbackService.generateFeedback(result);
      _requestAiFeedback(result);

      final updatedProgress = await _progress.saveScore(
        book: widget.book,
        chapter: widget.chapter,
        verse: _currentVerse!.verse,
        score: result.overallScore,
        stage: _currentStage,
      );

      _verseProgressMap[_currentVerse!.verse] = updatedProgress;

      if (_currentStage == LearningStage.realSpeak &&
          result.overallScore >= LearningStage.realSpeak.passThreshold) {
        final added = await ref.read(authServiceProvider).addTalant(_currentVerse!.verse);
        if (added) {
          _showSnackBar('달란트 +1 획득! 암송 완료!', isError: false);
          _checkAchievements();
        }
        await _reviewService.addReviewItem(
          verseReference: '$_bookNameEn ${widget.chapter}:${_currentVerse!.verse}',
          book: widget.book,
          chapter: widget.chapter,
          verse: _currentVerse!.verse,
          verseText: _currentVerse!.english,
        );
      }

      final passed = _currentStage.isPassed(result.overallScore);

      if (passed) {
        _postActivityAndChallenge(
          isStage3: _currentStage == LearningStage.realSpeak,
        );
        _recordStreakAndCheckMilestone();
      }

      setState(() {
        _isProcessing = false;
      });

      _showResultBottomSheet(result, passed);
    } catch (e) {
      _showSnackBar('처리 중 오류: $e', isError: true);
      setState(() => _isProcessing = false);
    }
  }

  void _showResultBottomSheet(PronunciationResult result, bool passed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => _ModernResultBottomSheet(
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

  Future<void> _requestAiFeedback(PronunciationResult result) async {
    if (!mounted) return;

    setState(() => _isLoadingAiFeedback = true);

    try {
      final tutor = TutorCoordinator.instance;
      final aiFeedback = await tutor.generateFeedbackFromResult(
        pronunciationResult: result,
        currentStage: _currentStage.stageNumber,
      );

      if (mounted && aiFeedback.isSuccess) {
        setState(() {
          _aiFeedback = aiFeedback;
          _isLoadingAiFeedback = false;
        });
      } else {
        setState(() => _isLoadingAiFeedback = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAiFeedback = false);
      }
    }
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

  Future<void> _recordStreakAndCheckMilestone() async {
    try {
      final milestone = await _streakService.recordLearning();

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
      debugPrint('스트릭 기록 오류: $e');
    }
  }

  Future<void> _checkAchievements() async {
    try {
      final achievementService = AchievementService();
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final verseResults = await achievementService.checkVerseAchievements(
        user.completedVerses.length,
      );

      final talantResults = await achievementService.checkTalantAchievements(
        user.talants,
      );

      final allResults = [...verseResults, ...talantResults];
      for (final result in allResults) {
        if (result.isNewUnlock && mounted) {
          _showSnackBar(
            '업적 해금! ${result.achievement.emoji} ${result.achievement.name}',
            isError: false,
          );
        }
      }
    } catch (e) {
      debugPrint('업적 체크 오류: $e');
    }
  }

  Future<void> _postActivityAndChallenge({bool isStage3 = false}) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || user.groupId.isEmpty || _currentVerse == null) return;

    final verseRef = '$_bookNameKo ${widget.chapter}:${_currentVerse!.verse}';

    _activityService.postVerseComplete(
      groupId: user.groupId,
      userName: user.name,
      verseRef: verseRef,
      isStage3: isStage3,
    );

    _challengeService.addContribution(
      groupId: user.groupId,
      userName: user.name,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? ParchmentTheme.softPapyrus : ParchmentTheme.ancientInk,
          ),
        ),
        backgroundColor: isError ? ParchmentTheme.error : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _tts.dispose();
    _recorder.dispose();
    _myVoicePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _bgAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _bgGradientStart,
                  Color.lerp(ParchmentTheme.agedParchment, _primaryColor.withValues(alpha: 0.1), _bgAnimation.value * 0.2)!,
                  _bgGradientEnd,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: _buildBody(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingVerses) {
      return _buildLoadingState();
    }

    if (_loadingError != null) {
      return _buildErrorState();
    }

    if (_verses.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildAppBar(),
        _buildProgressHeader(),
        _buildStageSelector(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildVerseNavigator(),
                const SizedBox(height: 16),
                _buildMainCard(),
                const SizedBox(height: 24),
                _buildRecordingSection(),
                const SizedBox(height: 16),
                _buildSpeedControl(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '구절을 불러오는 중...',
            style: TextStyle(
              fontSize: 16,
              color: ParchmentTheme.fadedScript,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: ParchmentTheme.error.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              _loadingError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ParchmentTheme.fadedScript,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadVerses,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: ParchmentTheme.softPapyrus,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: EmptyStateWidget(
        emoji: '',
        title: '구절 데이터가 없습니다',
        description: '이 장에는 구절이 없거나 불러올 수 없습니다.',
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParchmentTheme.warmVellum.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: ParchmentTheme.ancientInk,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _currentVerse != null
                  ? '$_bookNameKo ${widget.chapter}장 ${_currentVerse!.verse}절'
                  : '$_bookNameKo ${widget.chapter}장',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: ParchmentTheme.softPapyrus,
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.3),
        ),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_graph_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '학습 진척도',
                    style: TextStyle(
                      color: ParchmentTheme.ancientInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _successColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_completedCount / $_totalVerses',
                  style: const TextStyle(
                    color: _successColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progressPercent,
              backgroundColor: ParchmentTheme.warmVellum,
              valueColor: AlwaysStoppedAnimation<Color>(
                _progressPercent >= 1.0 ? _successColor : _primaryColor,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSelector() {
    final progress = _currentVerseProgress;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: LearningStage.values.map((stage) {
          final isUnlocked = progress == null
              ? stage == LearningStage.listenRepeat
              : stage.stageNumber <= progress.currentStage.stageNumber;
          final isActive = stage == _currentStage;
          final stageProgress = progress?.stages[stage];
          final isPassed = stageProgress != null &&
              stage.isPassed(stageProgress.bestScore);

          return Expanded(
            child: GestureDetector(
              onTap: () => _selectStage(stage),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? ParchmentTheme.goldButtonGradient
                      : null,
                  color: isActive
                      ? null
                      : (isPassed
                          ? _successColor.withValues(alpha: 0.1)
                          : ParchmentTheme.softPapyrus),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? _primaryColor
                        : (isPassed
                            ? _successColor.withValues(alpha: 0.5)
                            : _primaryColor.withValues(alpha: 0.2)),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: isActive ? ParchmentTheme.buttonShadow : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      isPassed
                          ? Icons.check_circle_rounded
                          : (isUnlocked
                              ? _getStageIcon(stage)
                              : Icons.lock_rounded),
                      color: isActive
                          ? ParchmentTheme.softPapyrus
                          : (isPassed
                              ? _successColor
                              : (isUnlocked
                                  ? _primaryColor
                                  : ParchmentTheme.weatheredGray)),
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.koreanName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? ParchmentTheme.softPapyrus
                            : (isPassed
                                ? _successColor
                                : ParchmentTheme.fadedScript),
                      ),
                    ),
                    if (stageProgress != null)
                      Text(
                        '${stageProgress.bestScore.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive
                              ? ParchmentTheme.softPapyrus.withValues(alpha: 0.9)
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
        return Icons.hearing_rounded;
      case LearningStage.keyExpressions:
        return Icons.edit_note_rounded;
      case LearningStage.realSpeak:
        return Icons.record_voice_over_rounded;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 85) return _successColor;
    if (score >= 70) return _primaryColor;
    if (score >= 50) return _warningColor;
    return ParchmentTheme.error;
  }

  Widget _buildVerseNavigator() {
    if (_currentVerse == null) return const SizedBox.shrink();

    final progress = _currentVerseProgress;
    final isCompleted = progress?.isCompleted ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.chevron_left_rounded,
            onTap: _currentVerseIndex > 0 ? _goToPreviousVerse : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? LinearGradient(
                      colors: [
                        _successColor.withValues(alpha: 0.2),
                        _successColor.withValues(alpha: 0.1),
                      ],
                    )
                  : null,
              color: isCompleted ? null : ParchmentTheme.softPapyrus,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isCompleted
                    ? _successColor.withValues(alpha: 0.5)
                    : _primaryColor.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: ParchmentTheme.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _successColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${_currentVerse!.verse}절',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? _successColor : _primaryColor,
                  ),
                ),
              ],
            ),
          ),
          _buildNavButton(
            icon: Icons.chevron_right_rounded,
            onTap: _currentVerseIndex < _verses.length - 1 ? _goToNextVerse : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEnabled
              ? ParchmentTheme.warmVellum.withValues(alpha: 0.6)
              : ParchmentTheme.warmVellum.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
                ? _primaryColor.withValues(alpha: 0.3)
                : ParchmentTheme.warmVellum,
          ),
        ),
        child: Icon(
          icon,
          color: isEnabled
              ? ParchmentTheme.ancientInk
              : ParchmentTheme.weatheredGray,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    if (_currentVerse == null) return const SizedBox.shrink();

    return VerseMemorizationCard(
      verseReference: '$_bookNameKo ${widget.chapter}:${_currentVerse!.verse}',
      englishText: _currentVerse!.english,
      koreanText: _currentVerse!.korean,
      currentStage: _currentStage.stageNumber,
      bestScore: _currentVerseProgress?.stages[_currentStage]?.bestScore,
      isCompleted: _currentVerseProgress?.isCompleted ?? false,
      isCurrentVerse: true,
      onPlayAudio: _playTTS,
      isAudioPlaying: _isTTSPlaying,
      isAudioLoading: _isTTSLoading,
    );
  }

  Widget _buildRecordingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // AI 분석 중 메시지
          if (_isProcessing) _buildProcessingMessage(),

          // 녹음 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RecordButton(
                isRecording: _isRecording,
                isProcessing: _isProcessing,
                isDisabled: _isTTSPlaying || _currentVerse == null,
                onPressed: _toggleRecording,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 안내 텍스트
          Text(
            _isRecording
                ? '녹음 중... 탭하여 중지'
                : (_isProcessing ? 'AI 분석 중...' : '탭하여 암송 시작'),
            style: TextStyle(
              fontSize: 14,
              color: _isRecording
                  ? ParchmentTheme.error
                  : ParchmentTheme.fadedScript,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParchmentTheme.softPapyrus,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.3),
        ),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: _primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 코치가 분석 중이에요',
                  style: TextStyle(
                    color: ParchmentTheme.ancientInk,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '발음, 억양, 유창성을 꼼꼼히 확인하고 있어요',
                  style: TextStyle(
                    color: ParchmentTheme.fadedScript,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParchmentTheme.softPapyrus,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.2),
        ),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    color: ParchmentTheme.fadedScript,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '재생 속도',
                    style: TextStyle(
                      color: ParchmentTheme.ancientInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: ParchmentTheme.goldButtonGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_playbackSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: ParchmentTheme.softPapyrus,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '0.5x',
                style: TextStyle(
                  fontSize: 12,
                  color: ParchmentTheme.weatheredGray,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _primaryColor,
                    inactiveTrackColor: ParchmentTheme.warmVellum,
                    thumbColor: _primaryLight,
                    overlayColor: _primaryColor.withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    onChanged: (value) {
                      setState(() => _playbackSpeed = value);
                      _tts.setPlaybackRate(value);
                    },
                  ),
                ),
              ),
              const Text(
                '1.5x',
                style: TextStyle(
                  fontSize: 12,
                  color: ParchmentTheme.weatheredGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 모던한 결과 바텀시트 (Parchment Theme)
class _ModernResultBottomSheet extends StatelessWidget {
  final PronunciationResult result;
  final bool passed;
  final LearningStage stage;
  final TutorFeedback? aiFeedback;
  final bool isLoadingAiFeedback;
  final VoidCallback onRetry;
  final VoidCallback onNextStage;
  final VoidCallback onPlayMyVoice;
  final bool isPlayingMyVoice;

  static const _primaryColor = ParchmentTheme.manuscriptGold;
  static const _successColor = ParchmentTheme.success;
  static const _warningColor = ParchmentTheme.warning;

  const _ModernResultBottomSheet({
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ParchmentTheme.softPapyrus,
            passed
                ? _successColor.withValues(alpha: 0.1)
                : _warningColor.withValues(alpha: 0.1),
            ParchmentTheme.warmVellum,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: passed
              ? _successColor.withValues(alpha: 0.5)
              : _warningColor.withValues(alpha: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ParchmentTheme.warmVellum,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // 점수 서클
              _buildScoreCircle(),
              const SizedBox(height: 20),

              // 결과 텍스트
              Text(
                passed ? '${stage.koreanName} 통과!' : '다시 도전해보세요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: passed ? _successColor : _warningColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '통과 기준: ${stage.passThreshold.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  color: ParchmentTheme.fadedScript,
                ),
              ),
              const SizedBox(height: 24),

              // 상세 점수
              _buildDetailScores(),
              const SizedBox(height: 20),

              // AI 피드백
              _buildAiFeedbackSection(),
              const SizedBox(height: 24),

              // 액션 버튼
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCircle() {
    final color = passed ? _successColor : _warningColor;

    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ParchmentTheme.softPapyrus,
        border: Border.all(color: color, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${result.overallScore.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '%',
              style: TextStyle(
                fontSize: 18,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailScores() {
    return Row(
      children: [
        _buildScoreItem('정확도', result.accuracyScore, const Color(0xFF42A5F5)),
        const SizedBox(width: 12),
        _buildScoreItem('유창성', result.fluencyScore, const Color(0xFF66BB6A)),
        const SizedBox(width: 12),
        _buildScoreItem('운율', result.prosodyScore, const Color(0xFFAB47BC)),
      ],
    );
  }

  Widget _buildScoreItem(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiFeedbackSection() {
    if (isLoadingAiFeedback) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _primaryColor,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'AI 코치가 분석 중...',
              style: TextStyle(
                color: _primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (aiFeedback != null && aiFeedback!.isSuccess) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParchmentTheme.softPapyrus,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _primaryColor.withValues(alpha: 0.3),
          ),
          boxShadow: ParchmentTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: _primaryColor),
                SizedBox(width: 8),
                Text(
                  'AI 코치',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              aiFeedback!.encouragement,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ParchmentTheme.ancientInk,
              ),
            ),
            if (aiFeedback!.detailedFeedback.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                aiFeedback!.detailedFeedback,
                style: const TextStyle(
                  fontSize: 13,
                  color: ParchmentTheme.fadedScript,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        passed
            ? '잘하셨어요! 다음 단계로 넘어가세요.'
            : '천천히 또박또박 다시 읽어보세요.',
        style: const TextStyle(
          fontSize: 14,
          color: ParchmentTheme.fadedScript,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPlayMyVoice,
            icon: Icon(
              isPlayingMyVoice ? Icons.stop_rounded : Icons.headphones_rounded,
              size: 20,
            ),
            label: Text(isPlayingMyVoice ? '중지' : '내 목소리'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ParchmentTheme.ancientInk,
              side: const BorderSide(color: _primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: passed && stage.nextStage != null ? onNextStage : onRetry,
            icon: Icon(
              passed && stage.nextStage != null
                  ? Icons.arrow_forward_rounded
                  : Icons.refresh_rounded,
              size: 20,
            ),
            label: Text(
              passed && stage.nextStage != null ? '다음 단계' : '다시 도전',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: passed ? _successColor : _primaryColor,
              foregroundColor: passed ? ParchmentTheme.ancientInk : ParchmentTheme.softPapyrus,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
