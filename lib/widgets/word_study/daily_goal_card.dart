import 'package:flutter/material.dart';
import '../../models/daily_goal.dart';
import '../../services/daily_goal_service.dart';

/// 일일 학습 목표 카드 위젯
class DailyGoalCard extends StatefulWidget {
  final VoidCallback? onGoalAchieved;
  final VoidCallback? onSettingsTap;

  const DailyGoalCard({
    super.key,
    this.onGoalAchieved,
    this.onSettingsTap,
  });

  @override
  State<DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<DailyGoalCard> {
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);
  static const _successColor = Color(0xFF4CAF50);

  final DailyGoalService _goalService = DailyGoalService();
  DailyGoal? _goal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    await _goalService.init();
    if (mounted) {
      setState(() {
        _goal = _goalService.todayGoal;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final goal = _goal!;
    final isAchieved = goal.isGoalMet;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isAchieved
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _successColor.withValues(alpha: 0.3),
                  _successColor.withValues(alpha: 0.1),
                ],
              )
            : null,
        color: isAchieved ? null : _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isAchieved
            ? Border.all(color: _successColor.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAchieved
                      ? _successColor.withValues(alpha: 0.3)
                      : _accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAchieved ? Icons.emoji_events : Icons.flag,
                  color: isAchieved ? _successColor : _accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAchieved ? '오늘의 목표 달성!' : '오늘의 학습 목표',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isAchieved ? _successColor : Colors.white,
                      ),
                    ),
                    if (isAchieved && goal.bonusClaimed)
                      Text(
                        '+3 달란트 획득!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.withValues(alpha: 0.9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              // 설정 버튼
              IconButton(
                onPressed: widget.onSettingsTap,
                icon: Icon(
                  Icons.tune,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                tooltip: '목표 설정',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 전체 진행률
          _buildOverallProgress(goal),
          const SizedBox(height: 16),

          // 개별 목표
          _buildGoalItem(
            icon: Icons.abc,
            label: '단어 학습',
            current: goal.studiedWords,
            target: goal.targetWords,
            progress: goal.wordsProgress,
          ),
          const SizedBox(height: 8),
          _buildGoalItem(
            icon: Icons.quiz,
            label: '퀴즈 완료',
            current: goal.completedQuizzes,
            target: goal.targetQuizzes,
            progress: goal.quizzesProgress,
          ),
          const SizedBox(height: 8),
          _buildGoalItem(
            icon: Icons.style,
            label: '플래시카드',
            current: goal.completedFlashcards,
            target: goal.targetFlashcards,
            progress: goal.flashcardsProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgress(DailyGoal goal) {
    final progress = goal.overallProgress;
    final isAchieved = goal.isGoalMet;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '전체 진행률',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isAchieved ? _successColor : _accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isAchieved ? _successColor : _accentColor,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalItem({
    required IconData icon,
    required String label,
    required int current,
    required int target,
    required double progress,
  }) {
    final isComplete = current >= target;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isComplete
                ? _successColor.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isComplete ? Icons.check : icon,
            size: 14,
            color: isComplete ? _successColor : Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '$current / $target',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? _successColor : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? _successColor : _accentColor.withValues(alpha: 0.7),
                  ),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
