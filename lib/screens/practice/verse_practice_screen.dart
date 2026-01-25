import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import '../../services/auth_service.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';
import '../../services/recording_service.dart';
import '../../services/accuracy_service.dart';
import '../../services/gemini_service.dart';
import '../../services/progress_service.dart';
import '../../services/esv_service.dart';
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
  final STTService _stt = STTService();
  final RecordingService _recorder = RecordingService();
  final AccuracyService _accuracy = AccuracyService();
  final GeminiService _gemini = GeminiService();
  final ProgressService _progress = ProgressService();
  final EsvService _esv = EsvService();
  final AudioPlayer _myVoicePlayer = AudioPlayer();

  // 상태
  int _currentVerseIndex = 0;
  bool _isTTSPlaying = false;
  bool _isTTSLoading = false;
  bool _isRecording = false;
  bool _isProcessingSTT = false;
  bool _isPlayingMyVoice = false;
  bool _showEnglish = true;
  bool _isNewRecord = false;
  double _playbackSpeed = 1.0;

  // 로딩 상태
  bool _isLoadingVerses = true;
  String? _loadingError;

  String? _lastRecordingPath;
  EvaluationResult? _evaluationResult;
  String? _aiFeedback;
  bool _isLoadingFeedback = false;
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
    _evaluationResult = null;
    _lastRecordingPath = null;
    _isNewRecord = false;
    _aiFeedback = null;
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
      _isProcessingSTT = true;
    });

    try {
      final audioPath = await _recorder.stopRecording();

      if (audioPath == null) {
        _showSnackBar('녹음 파일 저장 실패', isError: true);
        setState(() => _isProcessingSTT = false);
        return;
      }

      _lastRecordingPath = audioPath;

      // STT
      final sttResult = await _stt.transcribeAudio(
        audioFilePath: audioPath,
        languageCode: 'en',
      );

      if (!sttResult.isSuccess) {
        _showSnackBar(sttResult.errorMessage ?? 'STT 실패', isError: true);
        setState(() => _isProcessingSTT = false);
        return;
      }

      // 정확도 평가
      final result = _accuracy.evaluate(
        originalText: _currentVerse!.english,
        spokenText: sttResult.text ?? '',
      );

      // 점수 저장
      final isNew = await _progress.saveScore(
        book: widget.book,
        chapter: widget.chapter,
        verse: _currentVerse!.verse,
        score: result.score,
      );

      await _loadAllScores();

      // 달란트 적립 (70% 이상)
      if (result.score >= 70.0) {
        final added =
            await widget.authService.addTalant(_currentVerse!.verse);
        if (added) {
          _showSnackBar('달란트 +1 획득!', isError: false);
        }
      }

      setState(() {
        _evaluationResult = result;
        _isProcessingSTT = false;
        _isNewRecord = isNew;
      });

      // AI 피드백
      _requestAIFeedback(result);

      if (isNew && result.score >= ProgressService.masteryThreshold) {
        _showSnackBar(
            '암기 완료! 새 최고 기록: ${result.score.toStringAsFixed(0)}%',
            isError: false);
      } else if (isNew) {
        _showSnackBar('새 최고 기록: ${result.score.toStringAsFixed(0)}%',
            isError: false);
      }
    } catch (e) {
      _showSnackBar('처리 중 오류: $e', isError: true);
      setState(() => _isProcessingSTT = false);
    }
  }

  Future<void> _requestAIFeedback(EvaluationResult result) async {
    if (_currentVerse == null) return;

    setState(() => _isLoadingFeedback = true);

    try {
      final feedback = await _gemini.getFeedback(
        originalText: _currentVerse!.english,
        spokenText: result.spokenText,
        incorrectWords:
            result.incorrectWords.map((w) => w.originalWord).toList(),
        score: result.score,
      );

      if (mounted) {
        setState(() {
          _aiFeedback = feedback;
          _isLoadingFeedback = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFeedback = false);
      }
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
                if (_evaluationResult != null) _buildResultCard(),
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
                (_isProcessingSTT || _isTTSPlaying || isWebDisabled || _currentVerse == null)
                    ? null
                    : _toggleRecording,
            icon: _isProcessingSTT
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
                  : (_isProcessingSTT
                      ? '분석 중...'
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
    final result = _evaluationResult!;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 점수
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: result.score >= 70
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
                      Text(result.grade,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      if (_isNewRecord)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('NEW RECORD!',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${result.score.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(result.score),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // AI 피드백
            const SizedBox(height: 16),
            _buildAIFeedback(),

            // 상세 정보
            const SizedBox(height: 16),
            Text('정확한 단어: ${result.correctCount} / ${result.totalCount}'),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('내가 말한 내용',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(result.spokenText.isEmpty
                      ? '(인식된 내용 없음)'
                      : result.spokenText),
                ],
              ),
            ),

            // 비교 듣기
            const SizedBox(height: 16),
            Row(
              children: [
                if (_lastRecordingPath != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _playMyVoice,
                      icon: Icon(
                          _isPlayingMyVoice ? Icons.stop : Icons.person,
                          size: 18),
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
                    icon: Icon(
                        _isTTSPlaying ? Icons.stop : Icons.record_voice_over,
                        size: 18),
                    label: Text(_isTTSPlaying ? '중지' : '원어민'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIFeedback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Colors.purple),
              SizedBox(width: 8),
              Text('AI 튜터 피드백',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.purple)),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingFeedback)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.purple.shade300),
                ),
                const SizedBox(width: 8),
                const Text('AI가 피드백을 작성 중...',
                    style:
                        TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
              ],
            )
          else if (_aiFeedback != null)
            Text(_aiFeedback!,
                style: const TextStyle(fontSize: 14, height: 1.5))
          else
            const Text('피드백을 불러오는 중...',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}
