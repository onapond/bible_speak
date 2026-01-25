import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import '../../services/auth_service.dart';
import '../../services/tts_service.dart';
import '../../services/recording_service.dart';
import '../../services/progress_service.dart';
import '../../services/esv_service.dart';
import '../../services/pronunciation/azure_pronunciation_service.dart';
import '../../services/pronunciation/pronunciation_feedback_service.dart';
import '../../data/bible_data.dart';

/// 구절 연습 화면
/// - ESV API로 성경 텍스트 동적 로딩
class VersePracticeScreen extends StatefulWidget {
  final AuthService authService;
  final String book;
  final int chapter;

  const VersePracticeScreen({
    super.key,
    required this.authService,
    this.book = 'malachi',
    this.chapter = 1,
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
  final AzurePronunciationService _pronunciation = AzurePronunciationService();
  final PronunciationFeedbackService _feedbackService = PronunciationFeedbackService();
  final AudioPlayer _myVoicePlayer = AudioPlayer();

  // 상태
  int _currentVerseIndex = 0;
  bool _isTTSPlaying = false;
  bool _isTTSLoading = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isPlayingMyVoice = false;
  bool _showEnglish = true;
  bool _isNewRecord = false;
  double _playbackSpeed = 1.0;

  // 로딩 상태
  bool _isLoadingVerses = true;
  String? _loadingError;

  String? _lastRecordingPath;
  PronunciationResult? _pronunciationResult;
  PronunciationFeedback? _feedback;
  Map<int, double> _verseScores = {};

  // 데이터 - ESV API에서 로드
  List<VerseText> _verses = [];

  VerseText? get _currentVerse =>
      _verses.isNotEmpty ? _verses[_currentVerseIndex] : null;
  int get _totalVerses => _verses.length;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    if (!kIsWeb) {
      await _recorder.init();
    }
    await _progress.init();
    await _loadVerses();
  }

  /// ESV API에서 구절 로드
  Future<void> _loadVerses() async {
    setState(() {
      _isLoadingVerses = true;
      _loadingError = null;
    });

    try {
      final bookName = BibleData.getEsvBookName(widget.book);
      final verses = await _esv.getChapter(
        book: bookName,
        chapter: widget.chapter,
      );

      // 한글 번역 매핑
      final versesWithKorean = verses.map((v) {
        final korean = BibleData.getKoreanVerse(
          widget.book,
          widget.chapter,
          v.verse,
        );
        return v.copyWith(korean: korean);
      }).toList();

      if (mounted) {
        setState(() {
          _verses = versesWithKorean;
          _isLoadingVerses = false;
        });
        await _loadAllScores();
      }
    } catch (e) {
      print('ESV API 오류: $e');
      if (mounted) {
        setState(() {
          _loadingError = '성경 데이터를 불러오는데 실패했습니다.\n$e';
          _isLoadingVerses = false;
        });
      }
    }
  }

  Future<void> _loadAllScores() async {
    if (_verses.isEmpty) return;

    final scores = <int, double>{};
    for (final verse in _verses) {
      scores[verse.verse] = await _progress.getScore(
        book: widget.book,
        chapter: widget.chapter,
        verse: verse.verse,
      );
    }
    if (mounted) {
      setState(() => _verseScores = scores);
    }
  }

  int get _masteredCount => _verseScores.values
      .where((score) => score >= ProgressService.masteryThreshold)
      .length;

  double get _progressPercent =>
      _totalVerses > 0 ? _masteredCount / _totalVerses : 0;

  void _goToPreviousVerse() {
    if (_currentVerseIndex > 0) {
      setState(() {
        _currentVerseIndex--;
        _resetState();
      });
    }
  }

  void _goToNextVerse() {
    if (_currentVerseIndex < _verses.length - 1) {
      setState(() {
        _currentVerseIndex++;
        _resetState();
      });
    }
  }

  void _resetState() {
    _pronunciationResult = null;
    _feedback = null;
    _lastRecordingPath = null;
    _isNewRecord = false;
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
      final bookName = BibleData.getEsvBookName(widget.book);
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
    if (kIsWeb) {
      _showSnackBar('웹에서는 녹음이 지원되지 않습니다.', isError: true);
      return;
    }

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

      // 피드백 생성
      final feedback = _feedbackService.generateFeedback(result);

      // 점수 저장
      final isNew = await _progress.saveScore(
        book: widget.book,
        chapter: widget.chapter,
        verse: _currentVerse!.verse,
        score: result.overallScore,
      );

      await _loadAllScores();

      // 달란트 적립 (70% 이상)
      if (result.overallScore >= 70.0) {
        final added = await widget.authService.addTalant(_currentVerse!.verse);
        if (added) {
          _showSnackBar('달란트 +1 획득!', isError: false);
        }
      }

      setState(() {
        _pronunciationResult = result;
        _feedback = feedback;
        _isProcessing = false;
        _isNewRecord = isNew;
      });

      if (isNew && result.overallScore >= ProgressService.masteryThreshold) {
        _showSnackBar(
            '암기 완료! 새 최고 기록: ${result.overallScore.toStringAsFixed(0)}%',
            isError: false);
      } else if (isNew) {
        _showSnackBar('새 최고 기록: ${result.overallScore.toStringAsFixed(0)}%',
            isError: false);
      }
    } catch (e) {
      _showSnackBar('처리 중 오류: $e', isError: true);
      setState(() => _isProcessing = false);
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
      await _myVoicePlayer.play(DeviceFileSource(_lastRecordingPath!));
      _myVoicePlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlayingMyVoice = false);
      });
    } catch (e) {
      setState(() => _isPlayingMyVoice = false);
      _showSnackBar('재생 오류', isError: true);
    }
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

  @override
  void dispose() {
    _tts.dispose();
    _recorder.dispose();
    _myVoicePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookName = BibleData.getBookName(widget.book);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentVerse != null
            ? '$bookName ${widget.chapter}장 ${_currentVerse!.verse}절'
            : '$bookName ${widget.chapter}장'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_showEnglish ? Icons.translate : Icons.language),
            tooltip: _showEnglish ? '한글만 보기' : '영어 보기',
            onPressed: () => setState(() => _showEnglish = !_showEnglish),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 로딩 중
    if (_isLoadingVerses) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('성경 구절을 불러오는 중...'),
          ],
        ),
      );
    }

    // 에러
    if (_loadingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _loadingError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadVerses,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    // 데이터 없음
    if (_verses.isEmpty) {
      return const Center(
        child: Text('구절 데이터가 없습니다.'),
      );
    }

    // 정상 표시
    return Column(
      children: [
        _buildProgressBar(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('학습 진척도',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text('$_masteredCount / $_totalVerses 구절 완료',
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

  Widget _buildVerseNavigator() {
    if (_currentVerse == null) return const SizedBox.shrink();

    final currentScore = _verseScores[_currentVerse!.verse] ?? 0.0;
    final isMastered = currentScore >= ProgressService.masteryThreshold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentVerseIndex > 0 ? _goToPreviousVerse : null,
            icon: const Icon(Icons.chevron_left, size: 30),
            color: Colors.indigo,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isMastered ? Colors.green.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isMastered ? Colors.green : Colors.indigo.shade200,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMastered)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child:
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ),
                Text(
                  '${_currentVerse!.verse}절',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMastered
                        ? Colors.green.shade700
                        : Colors.indigo.shade700,
                  ),
                ),
                if (currentScore > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${currentScore.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: _getScoreColor(currentScore),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed:
                _currentVerseIndex < _verses.length - 1 ? _goToNextVerse : null,
            icon: const Icon(Icons.chevron_right, size: 30),
            color: Colors.indigo,
          ),
        ],
      ),
    );
  }

  Widget _buildVerseCard() {
    if (_currentVerse == null) return const SizedBox.shrink();

    final korean = _currentVerse!.korean;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentVerse!.verse}절',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isTTSLoading ? null : _playTTS,
                  icon: _isTTSLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isTTSPlaying ? Icons.stop_circle : Icons.play_circle,
                          size: 32,
                          color: _isTTSPlaying ? Colors.red : Colors.indigo,
                        ),
                  tooltip: _isTTSPlaying ? '중지' : '전체 듣기',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_showEnglish) ...[
              const Text('English',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 8),
              Text(_currentVerse!.english,
                  style: const TextStyle(fontSize: 18, height: 1.6)),
              const SizedBox(height: 16),
            ],
            const Text('한국어',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 8),
            Text(
              korean ?? '(한글 번역 준비 중)',
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: korean != null ? Colors.black : Colors.grey,
                fontStyle: korean != null ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    final isWebDisabled = kIsWeb;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                (_isProcessing || _isTTSPlaying || isWebDisabled || _currentVerse == null)
                    ? null
                    : _toggleRecording,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_isRecording ? Icons.stop : Icons.mic, size: 24),
            label: Text(
              isWebDisabled
                  ? '웹 미지원'
                  : (_isProcessing
                      ? '발음 분석 중...'
                      : (_isRecording ? '녹음 중지' : '암송 시작')),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.red : Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('재생 속도',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_playbackSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('0.5x', style: TextStyle(fontSize: 12)),
              Expanded(
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
              const Text('1.5x', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _pronunciationResult!;
    final feedback = _feedback;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 종합 점수
            _buildScoreHeader(result),

            // 세부 점수 (정확도, 유창성, 운율)
            const SizedBox(height: 16),
            _buildDetailedScores(result),

            // 격려 메시지
            if (feedback != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.indigo.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  feedback.encouragement,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],

            // 틀린 단어 상세 피드백
            if (feedback != null && feedback.hasIssues) ...[
              const SizedBox(height: 16),
              _buildWordFeedback(feedback),
            ],

            // 발음 팁
            if (feedback != null && feedback.tips.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPronunciationTips(feedback),
            ],

            // 인식된 텍스트
            const SizedBox(height: 16),
            _buildRecognizedText(result),

            // 비교 듣기 버튼
            const SizedBox(height: 16),
            _buildPlaybackButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreHeader(PronunciationResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.overallScore >= 70
            ? Colors.green.shade100
            : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '등급: ${result.grade}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_isNewRecord)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('NEW RECORD!',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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
    return Row(
      children: [
        Expanded(child: _buildScoreItem('정확도', result.accuracyScore, Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _buildScoreItem('유창성', result.fluencyScore, Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _buildScoreItem('운율', result.prosodyScore, Colors.purple)),
      ],
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
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('발음 교정 필요',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          ...feedback.details.take(5).map((detail) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(detail.status),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    detail.word,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(detail.message, style: const TextStyle(fontSize: 13)),
                      if (detail.phonemeIssues.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            children: detail.phonemeIssues.take(3).map((p) =>
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${p.phoneme} → ${p.koreanHint}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${detail.score.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(detail.score),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
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
          const Text('인식된 발음',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            result.recognizedText.isEmpty ? '(인식된 내용 없음)' : result.recognizedText,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackButtons() {
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
      ],
    );
  }
}
