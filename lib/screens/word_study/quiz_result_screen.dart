import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../models/quiz_type.dart';
import '../../styles/parchment_theme.dart';
import 'quiz_screen.dart';
import 'fill_blank_quiz_screen.dart';
import 'listening_quiz_screen.dart';

/// 퀴즈 결과 화면
class QuizResultScreen extends StatelessWidget {
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

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
    if (scorePercent >= 90) return ParchmentTheme.manuscriptGold;
    if (scorePercent >= 70) return ParchmentTheme.success;
    if (scorePercent >= 50) return ParchmentTheme.warning;
    return ParchmentTheme.error;
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        '퀴즈 결과',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
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
        boxShadow: ParchmentTheme.cardShadow,
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
              color: gradeColor.withValues(alpha: 0.15),
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
              _buildStatColumn('정답', correctCount, ParchmentTheme.success),
              Container(
                width: 1,
                height: 40,
                color: ParchmentTheme.warmVellum,
              ),
              _buildStatColumn('오답', wrongWords.length, ParchmentTheme.error),
              Container(
                width: 1,
                height: 40,
                color: ParchmentTheme.warmVellum,
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
                color: _accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: ParchmentTheme.manuscriptGold, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '+$earnedTalants 달란트 획득!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ParchmentTheme.manuscriptGold,
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
          style: const TextStyle(
            fontSize: 12,
            color: ParchmentTheme.fadedScript,
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
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: ParchmentTheme.error),
              const SizedBox(width: 8),
              const Text(
                '틀린 단어',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ParchmentTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${wrongWords.length}개',
                  style: const TextStyle(
                    color: ParchmentTheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: ParchmentTheme.warmVellum.withValues(alpha: 0.5)),
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
                              color: ParchmentTheme.ancientInk,
                            ),
                          ),
                          Text(
                            word.allMeanings,
                            style: const TextStyle(
                              color: ParchmentTheme.fadedScript,
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
                        color: _accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        word.partOfSpeechKo,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ParchmentTheme.manuscriptGold,
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
    switch (quizType) {
      case QuizType.fillInBlank:
        return FillBlankQuizScreen(
          words: words,
          bookName: bookName,
          chapter: chapter,
        );
      case QuizType.listening:
        return ListeningQuizScreen(
          words: words,
          bookName: bookName,
          chapter: chapter,
        );
      default:
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
                backgroundColor: ParchmentTheme.warning.withValues(alpha: 0.15),
                foregroundColor: ParchmentTheme.warning,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: ParchmentTheme.warning.withValues(alpha: 0.5)),
                ),
                elevation: 0,
              ),
            ),
          ),
        const SizedBox(height: 12),

        // 전체 다시 풀기
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: ParchmentTheme.goldButtonGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ParchmentTheme.buttonShadow,
          ),
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
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: ParchmentTheme.softPapyrus,
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
              foregroundColor: ParchmentTheme.ancientInk,
              side: BorderSide(color: _accentColor.withValues(alpha: 0.5), width: 2),
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
