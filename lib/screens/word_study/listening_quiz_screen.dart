import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../models/quiz_type.dart';
import '../../services/word_progress_service.dart';
import '../../services/auth_service.dart';
import '../../services/daily_goal_service.dart';
import '../../services/tts_service.dart';
import 'quiz_result_screen.dart';

/// 듣고 맞추기 퀴즈 화면
class ListeningQuizScreen extends StatefulWidget {
  final List<BibleWord> words;
  final String bookName;
  final int chapter;

  const ListeningQuizScreen({
    super.key,
    required this.words,
    required this.bookName,
    required this.chapter,
  });

  @override
  State<ListeningQuizScreen> createState() => _ListeningQuizScreenState();
}

class _ListeningQuizScreenState extends State<ListeningQuizScreen> {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);
  static const _successColor = Color(0xFF4CAF50);

  final WordProgressService _progressService = WordProgressService();
  final TTSService _tts = TTSService();
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late List<BibleWord> _quizWords;
  int _currentIndex = 0;
  bool _hasAnswered = false;
  bool _isCorrect = false;
  int _correctCount = 0;
  final List<BibleWord> _wrongWords = [];
  bool _isPlaying = false;
  int _playCount = 0;
  bool _showMeaningHint = false;

  @override
  void initState() {
    super.initState();
    _quizWords = List.from(widget.words)..shuffle();
    _progressService.init();
    // 첫 문제 자동 재생
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playWord();
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _focusNode.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _playWord() async {
    if (_isPlaying || _hasAnswered) return;

    final word = _quizWords[_currentIndex];
    setState(() => _isPlaying = true);

    try {
      await _tts.speakText(word.word);
      _playCount++;
    } catch (e) {
      // TTS 실패 시 무시
    }

    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _checkAnswer() {
    if (_hasAnswered) return;

    final word = _quizWords[_currentIndex];
    final userAnswer = _answerController.text.trim().toLowerCase();
    final correctAnswer = word.word.toLowerCase();
    final isCorrect = userAnswer == correctAnswer;

    setState(() {
      _hasAnswered = true;
      _isCorrect = isCorrect;
    });

    if (isCorrect) {
      _correctCount++;
    } else {
      _wrongWords.add(word);
    }

    _progressService.recordAnswer(
      wordId: word.id,
      isCorrect: isCorrect,
    );
  }

  void _showHint() {
    setState(() {
      _showMeaningHint = true;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _hasAnswered = false;
        _isCorrect = false;
        _playCount = 0;
        _showMeaningHint = false;
        _answerController.clear();
      });
      _focusNode.requestFocus();
      // 다음 단어 자동 재생
      Future.delayed(const Duration(milliseconds: 300), _playWord);
    } else {
      _showResult();
    }
  }

  void _showResult() async {
    final earnedTalants = await AuthService().earnWordStudyTalant(
      activityType: 'quiz',
      totalWords: _quizWords.length,
      correctCount: _correctCount,
    );

    // 일일 목표 진행 기록
    final goalService = DailyGoalService();
    await goalService.init();
    await goalService.recordQuizCompletion();
    await goalService.recordWordStudy(_quizWords.length);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          totalQuestions: _quizWords.length,
          correctCount: _correctCount,
          wrongWords: _wrongWords,
          bookName: widget.bookName,
          chapter: widget.chapter,
          allWords: widget.words,
          earnedTalants: earnedTalants,
          quizType: QuizType.listening,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_quizWords.isEmpty) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          title: const Text('듣고 맞추기'),
          backgroundColor: _cardColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            '퀴즈에 사용할 단어가 없습니다.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final word = _quizWords[_currentIndex];
    final quizTitle = widget.chapter > 0
        ? '${widget.bookName} ${widget.chapter}장'
        : widget.bookName;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text('$quizTitle 듣고 맞추기'),
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildListeningCard(word),
                    const SizedBox(height: 24),
                    _buildAnswerInput(word),
                    if (_hasAnswered) ...[
                      const SizedBox(height: 16),
                      _buildResultFeedback(word),
                    ],
                  ],
                ),
              ),
            ),
            _buildBottomButtons(word),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          bottom: BorderSide(color: _accentColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '문제 ${_currentIndex + 1} / ${_quizWords.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: _successColor),
                  const SizedBox(width: 4),
                  Text(
                    '$_correctCount',
                    style: TextStyle(
                      color: _successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.cancel, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    '${_wrongWords.length}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _quizWords.length,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningCard(BibleWord word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '들리는 단어를 입력하세요',
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 재생 버튼
          GestureDetector(
            onTap: _playWord,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isPlaying
                      ? [Colors.green, Colors.teal]
                      : [_accentColor, _accentColor.withValues(alpha: 0.7)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isPlaying ? Colors.green : _accentColor)
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.volume_up : Icons.play_arrow,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            _isPlaying ? '재생 중...' : '탭하여 다시 듣기',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),

          if (_playCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '재생 횟수: $_playCount',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],

          // 힌트 (뜻)
          if (_showMeaningHint) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Text(
                    '힌트: ${word.primaryMeaning}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(${word.partOfSpeechKo})',
                    style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerInput(BibleWord word) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextField(
            controller: _answerController,
            focusNode: _focusNode,
            enabled: !_hasAnswered,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: '영단어 입력',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontWeight: FontWeight.normal,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: _hasAnswered
                  ? (_isCorrect
                      ? _successColor.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2))
                  : Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _accentColor.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _hasAnswered
                      ? (_isCorrect ? _successColor : Colors.red)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (_) => _checkAnswer(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                '${word.word.length}글자',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultFeedback(BibleWord word) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCorrect
            ? _successColor.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCorrect ? _successColor : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _isCorrect ? Icons.check_circle : Icons.cancel,
                color: _isCorrect ? _successColor : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCorrect ? '정답입니다!' : '오답입니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isCorrect ? _successColor : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      word.pronunciation,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              // 정답 듣기 버튼
              IconButton(
                onPressed: () async {
                  setState(() => _isPlaying = true);
                  await _tts.speakText(word.word);
                  if (mounted) setState(() => _isPlaying = false);
                },
                icon: Icon(
                  _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
                  color: _accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${word.primaryMeaning} (${word.partOfSpeechKo})',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BibleWord word) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          top: BorderSide(color: _accentColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // 힌트 버튼
          if (!_hasAnswered && !_showMeaningHint)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showHint,
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('뜻 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (!_hasAnswered && !_showMeaningHint) const SizedBox(width: 12),

          // 확인/다음 버튼
          Expanded(
            flex: _hasAnswered || _showMeaningHint ? 1 : 2,
            child: ElevatedButton(
              onPressed: _hasAnswered ? _nextQuestion : _checkAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasAnswered ? _accentColor : _successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _hasAnswered
                    ? (_currentIndex >= _quizWords.length - 1 ? '결과 보기' : '다음 문제')
                    : '정답 확인',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
