import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../services/word_progress_service.dart';
import 'quiz_result_screen.dart';

/// 퀴즈 화면 (영→한 4지선다)
class QuizScreen extends StatefulWidget {
  final List<BibleWord> words;
  final String bookName;
  final int chapter;

  const QuizScreen({
    super.key,
    required this.words,
    required this.bookName,
    required this.chapter,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
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

  int _getCorrectIndex(List<String> options, BibleWord word) {
    return options.indexOf(word.primaryMeaning);
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

  void _showResult() {
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = _quizWords[_currentIndex];
    final options = _generateOptions(word);
    final correctIndex = _getCorrectIndex(options, word);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bookName} ${widget.chapter}장 퀴즈'),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade600, Colors.indigo.shade400],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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
                  const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
                  const SizedBox(width: 4),
                  Text(
                    '$_correctCount',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(
                    '${_wrongWords.length}',
                    style: const TextStyle(
                      color: Colors.redAccent,
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
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BibleWord word) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '이 단어의 뜻은?',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              word.word,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              word.pronunciation,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                word.partOfSpeechKo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    int index,
    String option,
    int correctIndex,
    BibleWord word,
  ) {
    Color backgroundColor = Colors.white;
    Color borderColor = Colors.transparent;
    Color textColor = Colors.black87;

    if (_hasAnswered) {
      if (index == correctIndex) {
        backgroundColor = Colors.green.shade100;
        borderColor = Colors.green;
        textColor = Colors.green.shade800;
      } else if (index == _selectedAnswer) {
        backgroundColor = Colors.red.shade100;
        borderColor = Colors.red;
        textColor = Colors.red.shade800;
      }
    } else if (index == _selectedAnswer) {
      borderColor = Colors.indigo;
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
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hasAnswered
                        ? (index == correctIndex
                            ? Colors.green
                            : (index == _selectedAnswer
                                ? Colors.red
                                : Colors.grey.shade300))
                        : Colors.indigo.shade100,
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
                            color: Colors.white,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.indigo,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
