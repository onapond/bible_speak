import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import 'quiz_screen.dart';

/// 퀴즈 결과 화면
class QuizResultScreen extends StatelessWidget {
  final int totalQuestions;
  final int correctCount;
  final List<BibleWord> wrongWords;
  final String bookName;
  final int chapter;
  final List<BibleWord> allWords;

  const QuizResultScreen({
    super.key,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongWords,
    required this.bookName,
    required this.chapter,
    required this.allWords,
  });

  int get scorePercent => (correctCount * 100 / totalQuestions).round();

  String get gradeEmoji {
    if (scorePercent >= 90) return '🏆';
    if (scorePercent >= 70) return '👍';
    if (scorePercent >= 50) return '💪';
    return '📚';
  }

  String get gradeMessage {
    if (scorePercent >= 90) return '완벽해요!';
    if (scorePercent >= 70) return '잘했어요!';
    if (scorePercent >= 50) return '조금만 더!';
    return '다시 도전!';
  }

  Color get gradeColor {
    if (scorePercent >= 90) return Colors.amber;
    if (scorePercent >= 70) return Colors.green;
    if (scorePercent >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈 결과'),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 점수 카드
                _buildScoreCard(),
                const SizedBox(height: 20),

                // 틀린 단어
                if (wrongWords.isNotEmpty) ...[
                  _buildWrongWordsCard(),
                  const SizedBox(height: 20),
                ],

                // 버튼들
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // 이모지
            Text(
              gradeEmoji,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),

            // 메시지
            Text(
              gradeMessage,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: gradeColor,
              ),
            ),
            const SizedBox(height: 24),

            // 점수
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: gradeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$scorePercent',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: gradeColor,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: gradeColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 상세 점수
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn('정답', correctCount, Colors.green),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _buildStatColumn('오답', wrongWords.length, Colors.red),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _buildStatColumn('총 문제', totalQuestions, Colors.indigo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildWrongWordsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: 8),
                const Text(
                  '틀린 단어',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${wrongWords.length}개',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...wrongWords.map((word) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              word.word,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              word.allMeanings,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          word.partOfSpeechKo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // 틀린 단어만 다시 풀기
        if (wrongWords.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(
                      words: wrongWords,
                      bookName: bookName,
                      chapter: chapter,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.replay),
              label: const Text('틀린 단어만 다시 풀기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),

        // 전체 다시 풀기
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    words: allWords,
                    bookName: bookName,
                    chapter: chapter,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('전체 다시 풀기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 완료
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/word_list');
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('완료'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
