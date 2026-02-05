import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../models/quiz_type.dart';
import '../../services/word_progress_service.dart';
import '../../services/auth_service.dart';
import '../../services/daily_goal_service.dart';
import '../../styles/parchment_theme.dart';
import 'quiz_result_screen.dart';

/// 퀴즈 화면 (4지선다)
class QuizScreen extends StatefulWidget {
  final List<BibleWord> words;
  final String bookName;
  final int chapter;
  final QuizType quizType;

  const QuizScreen({
    super.key,
    required this.words,
    required this.bookName,
    required this.chapter,
    this.quizType = QuizType.englishToKorean,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final WordProgressService _progressService = WordProgressService();

  late List<BibleWord> _quizWords;
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _hasAnswered = false;
  int _correctCount = 0;
  final List<BibleWord> _wrongWords = [];

  @override
  void initState() {
    super.initState();
    _quizWords = List.from(widget.words)..shuffle();
    _progressService.init();
  }

  List<String> _generateOptions(BibleWord correctWord) {
    if (widget.quizType == QuizType.koreanToEnglish) {
      return _generateEnglishOptions(correctWord);
    } else {
      return _generateKoreanOptions(correctWord);
    }
  }

  /// Type A: 한글 뜻 선택지 생성 (영→한)
  List<String> _generateKoreanOptions(BibleWord correctWord) {
    final correctMeaning = correctWord.primaryMeaning;
    final options = <String>[correctMeaning];

    // 다른 단어들에서 오답 선택지 생성
    final otherWords = widget.words.where((w) => w.id != correctWord.id).toList()
      ..shuffle();

    for (final word in otherWords) {
      if (options.length >= 4) break;
      final meaning = word.primaryMeaning;
      if (!options.contains(meaning)) {
        options.add(meaning);
      }
    }

    // 부족하면 기본 오답 추가
    final defaultWrongs = ['축복', '사랑', '평화', '기쁨', '소망', '믿음', '은혜', '영광'];
    for (final wrong in defaultWrongs) {
      if (options.length >= 4) break;
      if (!options.contains(wrong)) {
        options.add(wrong);
      }
    }

    options.shuffle();
    return options;
  }

  /// Type B: 영어 단어 선택지 생성 (한→영)
  List<String> _generateEnglishOptions(BibleWord correctWord) {
    final correctAnswer = correctWord.word;
    final options = <String>[correctAnswer];

    // 다른 단어들에서 오답 선택지 생성
    final otherWords = widget.words.where((w) => w.id != correctWord.id).toList()
      ..shuffle();

    for (final word in otherWords) {
      if (options.length >= 4) break;
      if (!options.contains(word.word)) {
        options.add(word.word);
      }
    }

    // 부족하면 기본 오답 추가 (성경 관련 영단어)
    final defaultWrongs = ['blessing', 'covenant', 'sacrifice', 'messenger', 'prophet', 'glory', 'grace', 'faith'];
    for (final wrong in defaultWrongs) {
      if (options.length >= 4) break;
      if (!options.contains(wrong)) {
        options.add(wrong);
      }
    }

    options.shuffle();
    return options;
  }

  int _getCorrectIndex(List<String> options, BibleWord word) {
    if (widget.quizType == QuizType.koreanToEnglish) {
      return options.indexOf(word.word);
    } else {
      return options.indexOf(word.primaryMeaning);
    }
  }

  Future<void> _selectAnswer(int index, int correctIndex, BibleWord word) async {
    if (_hasAnswered) return;

    setState(() {
      _selectedAnswer = index;
      _hasAnswered = true;
    });

    final isCorrect = index == correctIndex;

    if (isCorrect) {
      _correctCount++;
    } else {
      _wrongWords.add(word);
    }

    await _progressService.recordAnswer(
      wordId: word.id,
      isCorrect: isCorrect,
    );
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _hasAnswered = false;
      });
    } else {
      _showResult();
    }
  }

  void _showResult() async {
    // 탈란트 적립
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
          quizType: widget.quizType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = _quizWords[_currentIndex];
    final options = _generateOptions(word);
    final correctIndex = _getCorrectIndex(options, word);

    final quizTitle = widget.chapter > 0
        ? '${widget.bookName} ${widget.chapter}장'
        : widget.bookName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ParchmentTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      color: ParchmentTheme.ancientInk,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        '$quizTitle ${widget.quizType.displayName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // 진행률
              _buildProgress(),

              // 문제
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildQuestionCard(word),
                      const SizedBox(height: 24),
                      ...List.generate(
                        options.length,
                        (i) => _buildOptionButton(
                          i,
                          options[i],
                          correctIndex,
                          word,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 다음 버튼
              if (_hasAnswered) _buildNextButton(),
            ],
          ),
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
          bottom: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
        ),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '문제 ${_currentIndex + 1} / ${_quizWords.length}',
                style: const TextStyle(
                  color: ParchmentTheme.ancientInk,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: ParchmentTheme.success),
                  const SizedBox(width: 4),
                  Text(
                    '$_correctCount',
                    style: const TextStyle(
                      color: ParchmentTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.cancel, size: 16, color: ParchmentTheme.error),
                  const SizedBox(width: 4),
                  Text(
                    '${_wrongWords.length}',
                    style: const TextStyle(
                      color: ParchmentTheme.error,
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
              backgroundColor: ParchmentTheme.warmVellum,
              valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BibleWord word) {
    final isKoreanToEnglish = widget.quizType == QuizType.koreanToEnglish;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isKoreanToEnglish ? '이 뜻의 영단어는?' : '이 단어의 뜻은?',
              style: const TextStyle(
                color: ParchmentTheme.manuscriptGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isKoreanToEnglish) ...[
            // 한→영: 한글 뜻을 크게 표시
            Text(
              word.primaryMeaning,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ParchmentTheme.warmVellum,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                word.partOfSpeechKo,
                style: const TextStyle(
                  fontSize: 12,
                  color: ParchmentTheme.fadedScript,
                ),
              ),
            ),
            if (word.meanings.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                '(${word.meanings.skip(1).join(", ")})',
                style: const TextStyle(
                  fontSize: 14,
                  color: ParchmentTheme.weatheredGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ] else ...[
            // 영→한: 영어 단어를 크게 표시
            Text(
              word.word,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              word.pronunciation,
              style: const TextStyle(
                fontSize: 16,
                color: ParchmentTheme.fadedScript,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ParchmentTheme.warmVellum,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                word.partOfSpeechKo,
                style: const TextStyle(
                  fontSize: 12,
                  color: ParchmentTheme.fadedScript,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionButton(
    int index,
    String option,
    int correctIndex,
    BibleWord word,
  ) {
    Color backgroundColor = _cardColor;
    Color borderColor = Colors.transparent;
    Color textColor = ParchmentTheme.ancientInk;

    if (_hasAnswered) {
      if (index == correctIndex) {
        backgroundColor = ParchmentTheme.success.withValues(alpha: 0.15);
        borderColor = ParchmentTheme.success;
        textColor = ParchmentTheme.success;
      } else if (index == _selectedAnswer) {
        backgroundColor = ParchmentTheme.error.withValues(alpha: 0.15);
        borderColor = ParchmentTheme.error;
        textColor = ParchmentTheme.error;
      }
    } else if (index == _selectedAnswer) {
      borderColor = _accentColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _selectAnswer(index, correctIndex, word),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor == Colors.transparent
                    ? _accentColor.withValues(alpha: 0.2)
                    : borderColor,
                width: 2,
              ),
              boxShadow: ParchmentTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hasAnswered
                        ? (index == correctIndex
                            ? ParchmentTheme.success
                            : (index == _selectedAnswer
                                ? ParchmentTheme.error
                                : ParchmentTheme.warmVellum))
                        : _accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _hasAnswered
                        ? Icon(
                            index == correctIndex
                                ? Icons.check
                                : (index == _selectedAnswer
                                    ? Icons.close
                                    : null),
                            size: 20,
                            color: ParchmentTheme.softPapyrus,
                          )
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ParchmentTheme.manuscriptGold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _currentIndex >= _quizWords.length - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          top: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: ParchmentTheme.goldButtonGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ParchmentTheme.buttonShadow,
        ),
        child: ElevatedButton(
          onPressed: _nextQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: ParchmentTheme.softPapyrus,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            isLast ? '결과 보기' : '다음 문제',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
