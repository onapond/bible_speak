import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../models/quiz_type.dart';
import 'quiz_screen.dart';
import 'fill_blank_quiz_screen.dart';

/// 퀴즈 결과 화면
class QuizResultScreen extends StatelessWidget {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);
  static const _successColor = Color(0xFF4CAF50);

  final int totalQuestions;
  final int correctCount;
  final List<BibleWord> wrongWords;
  final String bookName;
  final int chapter;
  final List<BibleWord> allWords;
  final int earnedTalants;
  final QuizType quizType;

  const QuizResultScreen({
    super.key,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongWords,
    required this.bookName,
    required this.chapter,
    required this.allWords,
    this.earnedTalants = 0,
    this.quizType = QuizType.englishToKorean,
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
    if (scorePercent >= 70) return _successColor;
    if (scorePercent >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('퀴즈 결과'),
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SafeArea(
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
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
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
              color: gradeColor.withValues(alpha: 0.2),
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
              _buildStatColumn('정답', correctCount, _successColor),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              _buildStatColumn('오답', wrongWords.length, Colors.red),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              _buildStatColumn('총 문제', totalQuestions, _accentColor),
            ],
          ),
          // 탈란트 보상
          if (earnedTalants > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '+$earnedTalants 달란트 획득!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      fontSize: 18,
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
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildWrongWordsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              const Text(
                '틀린 단어',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${wrongWords.length}개',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: Colors.white.withValues(alpha: 0.1)),
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
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            word.allMeanings,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
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
                        color: _accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        word.partOfSpeechKo,
                        style: TextStyle(
                          fontSize: 11,
                          color: _accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _createQuizScreen(List<BibleWord> words) {
    if (quizType == QuizType.fillInBlank) {
      return FillBlankQuizScreen(
        words: words,
        bookName: bookName,
        chapter: chapter,
      );
    } else {
      return QuizScreen(
        words: words,
        bookName: bookName,
        chapter: chapter,
        quizType: quizType,
      );
    }
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
                    builder: (_) => _createQuizScreen(wrongWords),
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
                elevation: 0,
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
                  builder: (_) => _createQuizScreen(allWords),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('전체 다시 풀기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 완료
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil(
                  (route) => route.isFirst || route.settings.name == '/word_list');
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('완료'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 2),
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
