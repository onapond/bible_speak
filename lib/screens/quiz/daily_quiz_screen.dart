import 'package:flutter/material.dart';
import '../../models/daily_quiz.dart';
import '../../services/daily_quiz_service.dart';
import '../../widgets/common/animated_counter.dart';

/// 일일 퀴즈 화면
class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final DailyQuizService _quizService = DailyQuizService();

  DailyQuiz? _quiz;
  QuizStreak? _streak;
  DailyQuizResult? _todayResult;
  bool _isLoading = true;
  bool _hasCompleted = false;

  // 퀴즈 진행 상태
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final quiz = await _quizService.getTodayQuiz();
    final streak = await _quizService.getQuizStreak();
    final hasCompleted = await _quizService.hasCompletedToday();

    DailyQuizResult? result;
    if (hasCompleted) {
      result = await _quizService.getTodayResult();
    }

    setState(() {
      _quiz = quiz;
      _streak = streak;
      _hasCompleted = hasCompleted;
      _todayResult = result;
      _isLoading = false;
    });
  }

  void _startQuiz() {
    setState(() {
      _currentIndex = 0;
      _answers.clear();
      _startTime = DateTime.now();
    });
  }

  void _selectAnswer(String answer) {
    if (_quiz == null) return;

    final question = _quiz!.questions[_currentIndex];
    setState(() {
      _answers[question.id] = answer;
    });
  }

  void _nextQuestion() {
    if (_quiz == null) return;

    if (_currentIndex < _quiz!.questionCount - 1) {
      setState(() => _currentIndex++);
    } else {
      _submitQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  Future<void> _submitQuiz() async {
    if (_quiz == null || _startTime == null) return;

    final timeTaken = DateTime.now().difference(_startTime!);

    final answers = _quiz!.questions.map((q) {
      final userAnswer = _answers[q.id] ?? '';
      return QuizAnswer(
        questionId: q.id,
        userAnswer: userAnswer,
        correctAnswer: q.correctAnswer,
        isCorrect: userAnswer == q.correctAnswer,
      );
    }).toList();

    setState(() => _isLoading = true);

    final result = await _quizService.submitQuiz(
      quiz: _quiz!,
      answers: answers,
      timeTaken: timeTaken,
    );

    if (result != null) {
      setState(() {
        _todayResult = result;
        _hasCompleted = true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('제출 중 오류가 발생했습니다'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '오늘의 퀴즈',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_streak != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${_streak!.currentStreak}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : _hasCompleted
              ? _buildResultView()
              : _startTime == null
                  ? _buildStartView()
                  : _buildQuizView(),
    );
  }

  Widget _buildStartView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 스트릭 카드
          if (_streak != null) _buildStreakCard(),
          const SizedBox(height: 20),

          // 퀴즈 정보 카드
          if (_quiz != null) _buildQuizInfoCard(),
          const SizedBox(height: 24),

          // 시작 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text(
                    '퀴즈 시작',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.orange,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '퀴즈 스트릭',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${_streak!.currentStreak}일',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '최고: ${_streak!.longestStreak}일',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '총 ${_streak!.totalQuizzesTaken}회',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '만점 ${_streak!.perfectScores}회',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuizInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.quiz, color: _accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _quiz!.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_quiz!.questionCount}문제',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.toll,
                iconColor: Colors.amber,
                label: '기본 보상',
                value: '${_quiz!.totalPoints}',
              ),
              _buildInfoItem(
                icon: Icons.star,
                iconColor: Colors.purple,
                label: '만점 보너스',
                value: '+${_quiz!.bonusPoints}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuizView() {
    if (_quiz == null) return const SizedBox.shrink();

    final question = _quiz!.questions[_currentIndex];
    final selectedAnswer = _answers[question.id];

    return Column(
      children: [
        // 진행률
        _buildProgressBar(),

        // 문제
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 문제 유형
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.type.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 질문
                Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // 구절 (있는 경우)
                if (question.verseText != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.verseText!,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.5,
                          ),
                        ),
                        if (question.verseReference != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '- ${question.verseReference}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // 선택지
                ...question.options.map((option) {
                  final isSelected = selectedAnswer == option;
                  return GestureDetector(
                    onTap: () => _selectAnswer(option),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _accentColor.withValues(alpha: 0.2)
                            : _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _accentColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? _accentColor : _bgColor,
                              border: Border.all(
                                color: isSelected
                                    ? _accentColor
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // 하단 버튼
        _buildBottomButtons(),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentIndex + 1) / _quiz!.questionCount;

    return Container(
      padding: const EdgeInsets.all(16),
      color: _cardColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '문제 ${_currentIndex + 1}/${_quiz!.questionCount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${(_answers[_quiz!.questions[_currentIndex].id] != null ? _currentIndex + 1 : _currentIndex)}개 완료',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedProgressBar(
            progress: progress,
            height: 6,
            backgroundColor: _bgColor,
            valueColor: _accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final hasAnswer = _answers[_quiz!.questions[_currentIndex].id] != null;
    final isLast = _currentIndex == _quiz!.questionCount - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousQuestion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('이전'),
              ),
            ),
          if (_currentIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: hasAnswer ? _nextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasAnswer ? _accentColor : Colors.grey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isLast ? '제출' : '다음',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    if (_todayResult == null) return const SizedBox.shrink();

    final result = _todayResult!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 결과 헤더
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // 이모지
                Text(
                  result.isPerfect ? '🎉' : result.accuracy >= 0.8 ? '👍' : '💪',
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),

                // 메시지
                Text(
                  result.isPerfect
                      ? '완벽해요!'
                      : result.accuracy >= 0.8
                          ? '잘했어요!'
                          : '수고했어요!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${result.correctCount}/${result.totalQuestions} 정답',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // 점수
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.toll, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    AnimatedCounter(
                      value: result.totalEarned,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                if (result.bonusEarned > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '만점 보너스 +${result.bonusEarned}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 통계
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.timer,
                  label: '소요 시간',
                  value: _formatDuration(result.timeTaken),
                ),
                _buildStatItem(
                  icon: Icons.percent,
                  label: '정답률',
                  value: '${result.accuracyPercent}%',
                ),
                _buildStatItem(
                  icon: Icons.local_fire_department,
                  label: '연속',
                  value: '${_streak?.currentStreak ?? 1}일',
                  valueColor: Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 내일 다시 도전 메시지
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: _accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '내일 새로운 퀴즈가 준비됩니다!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 홈으로 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '홈으로',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}분 ${seconds}초';
  }
}
