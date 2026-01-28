import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../models/quiz_type.dart';
import '../../services/word_progress_service.dart';
import '../../services/auth_service.dart';
import '../../services/daily_goal_service.dart';
import 'quiz_result_screen.dart';

/// 빈칸 채우기 퀴즈 화면
class FillBlankQuizScreen extends StatefulWidget {
  final List<BibleWord> words;
  final String bookName;
  final int chapter;

  const FillBlankQuizScreen({
    super.key,
    required this.words,
    required this.bookName,
    required this.chapter,
  });

  @override
  State<FillBlankQuizScreen> createState() => _FillBlankQuizScreenState();
}

class _FillBlankQuizScreenState extends State<FillBlankQuizScreen> {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);
  static const _successColor = Color(0xFF4CAF50);

  final WordProgressService _progressService = WordProgressService();
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late List<BibleWord> _quizWords;
  int _currentIndex = 0;
  bool _hasAnswered = false;
  bool _isCorrect = false;
  int _correctCount = 0;
  final List<BibleWord> _wrongWords = [];
  int _hintLevel = 0; // 0: no hint, 1: first letter, 2: more letters

  @override
  void initState() {
    super.initState();
    // 구절이 있는 단어만 필터링
    _quizWords = widget.words.where((w) => w.verses.isNotEmpty).toList()..shuffle();
    if (_quizWords.isEmpty) {
      // 구절이 없으면 전체 단어 사용
      _quizWords = List.from(widget.words)..shuffle();
    }
    _progressService.init();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _createBlankSentence(BibleWord word) {
    if (word.verses.isEmpty) {
      // 구절이 없으면 간단한 문장 생성
      return 'The word "______" means "${word.primaryMeaning}"';
    }

    final verse = word.verses.first;
    final excerpt = verse.excerpt;

    // 단어를 빈칸으로 대체 (대소문자 무시)
    final pattern = RegExp(word.word, caseSensitive: false);
    final blanked = excerpt.replaceAll(pattern, '______');

    return blanked;
  }

  String _getHint(BibleWord word) {
    if (_hintLevel == 0) return '';

    final letters = word.word.split('');
    if (_hintLevel == 1) {
      // 첫 글자만
      return letters.first + '_' * (letters.length - 1);
    } else {
      // 첫 글자 + 마지막 글자
      if (letters.length <= 2) return word.word;
      return '${letters.first}${'_' * (letters.length - 2)}${letters.last}';
    }
  }

  void _checkAnswer(BibleWord word) {
    if (_hasAnswered) return;

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
    if (_hintLevel < 2) {
      setState(() {
        _hintLevel++;
      });
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _hasAnswered = false;
        _isCorrect = false;
        _hintLevel = 0;
        _answerController.clear();
      });
      _focusNode.requestFocus();
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
          quizType: QuizType.fillInBlank,
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
          title: const Text('빈칸 채우기'),
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
        title: Text('$quizTitle 빈칸 채우기'),
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
                    _buildQuestionCard(word),
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

  Widget _buildQuestionCard(BibleWord word) {
    final blankSentence = _createBlankSentence(word);
    final hint = _getHint(word);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
              '빈칸에 들어갈 단어는?',
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 문장
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              blankSentence,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // 한글 뜻
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '뜻: ${word.primaryMeaning}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  word.partOfSpeechKo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),

          // 힌트
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '힌트: $hint',
              style: TextStyle(
                color: Colors.orange.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // 구절 참조
          if (word.verses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '- ${word.verses.first.reference}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
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
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: '영단어 입력',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontWeight: FontWeight.normal,
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
            onSubmitted: (_) => _checkAnswer(word),
          ),
          const SizedBox(height: 12),
          Text(
            '${word.word.length}글자',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
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
      child: Row(
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
                if (!_isCorrect) ...[
                  const SizedBox(height: 4),
                  Text(
                    '정답: ${word.word}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
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
          if (!_hasAnswered)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _hintLevel < 2 ? _showHint : null,
                icon: const Icon(Icons.lightbulb_outline),
                label: Text(_hintLevel == 0 ? '힌트' : '힌트 +'),
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
          if (!_hasAnswered) const SizedBox(width: 12),

          // 확인/다음 버튼
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _hasAnswered ? _nextQuestion : () => _checkAnswer(word),
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
