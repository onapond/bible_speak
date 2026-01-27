import 'package:flutter/material.dart';
import '../../models/user_streak.dart';

/// 스트릭 위젯 (홈 화면용)
class StreakWidget extends StatelessWidget {
  final UserStreak streak;
  final VoidCallback? onTapProtection;

  const StreakWidget({
    super.key,
    required this.streak,
    this.onTapProtection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E2E),
            const Color(0xFF2D1B4E).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 스트릭 카운트
            Row(
              children: [
                _buildFireIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streak.currentStreak > 0
                            ? '${streak.currentStreak}일 연속 학습 중!'
                            : '오늘 첫 학습을 시작해보세요!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (streak.nextMilestone != null)
                        Text(
                          '${streak.nextMilestone!.days}일까지 ${streak.daysToNextMilestone}일 남음',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // 스트릭 보호권 버튼
                if (streak.isAtRisk && streak.canUseProtection && onTapProtection != null)
                  _buildProtectionButton(),
              ],
            ),

            const SizedBox(height: 16),

            // 21일 진행 바
            _build21DayProgress(),

            const SizedBox(height: 12),

            // 주간 캘린더
            _buildWeeklyCalendar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFireIcon() {
    final hasStreak = streak.currentStreak > 0;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: hasStreak
            ? const Color(0xFFFF6B35).withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          hasStreak ? '🔥' : '⭕',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildProtectionButton() {
    return GestureDetector(
      onTap: onTapProtection,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35).withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛡️', style: TextStyle(fontSize: 14)),
            SizedBox(width: 4),
            Text(
              '보호',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build21DayProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '21일 습관 형성',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '${streak.currentStreak}/21일',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            // 배경
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // 진행률
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              height: 6,
              width: (streak.progressTo21Days * 300).clamp(0, 300),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFFD700)],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyCalendar() {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final today = (DateTime.now().weekday - 1) % 7;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isCompleted = streak.weeklyHistory.length > index && streak.weeklyHistory[index];
        final isToday = index == today;
        final isProtected = false; // TODO: 보호된 날짜 확인

        return Column(
          children: [
            Text(
              days[index],
              style: TextStyle(
                color: isToday ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFFF6B35).withOpacity(0.2)
                    : (isToday ? Colors.white.withOpacity(0.1) : Colors.transparent),
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: const Color(0xFFFF6B35), width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  isCompleted
                      ? '🔥'
                      : (isProtected ? '🛡️' : (isToday ? '⭕' : '')),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// 스트릭 보호권 다이얼로그
class StreakProtectionDialog extends StatelessWidget {
  final UserStreak streak;
  final int dalantBalance;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const StreakProtectionDialog({
    super.key,
    required this.streak,
    required this.dalantBalance,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = dalantBalance >= 100;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚠️ 스트릭이 끊어질 위험!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '현재 스트릭: 🔥 ${streak.currentStreak}일',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Text(
              '스트릭 보호권을 사용하시겠습니까?',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const Text(
              '(달란트 100개 소모)',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '보유: $dalantBalance개',
                    style: TextStyle(
                      color: canAfford ? Colors.white : Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이번 달 사용: ${streak.protectionUsedThisMonth}/2회',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      '괜찮아요',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canAfford ? onConfirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('보호권 사용'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 마일스톤 달성 축하 다이얼로그
class MilestoneAchievedDialog extends StatelessWidget {
  final StreakMilestone milestone;
  final VoidCallback onDismiss;

  const MilestoneAchievedDialog({
    super.key,
    required this.milestone,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              milestone.badge,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 축하합니다! 🎉',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${milestone.days}일 연속 학습 달성!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            if (milestone.title != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '"${milestone.title}" 칭호 획득!',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    '+${milestone.dalantReward} 달란트',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
