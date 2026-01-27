import 'package:flutter/material.dart';
import '../../models/daily_verse.dart';

/// 아침 만나 카드 위젯
class MorningMannaWidget extends StatelessWidget {
  final DailyVerse? dailyVerse;
  final EarlyBirdBonus earlyBirdBonus;
  final bool hasClaimedBonus;
  final VoidCallback onTapStudy;
  final bool isLoading;

  const MorningMannaWidget({
    super.key,
    required this.dailyVerse,
    required this.earlyBirdBonus,
    required this.hasClaimedBonus,
    required this.onTapStudy,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (dailyVerse == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E2E),
            _getGradientColor(),
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
            // 헤더
            _buildHeader(),
            const SizedBox(height: 16),

            // 구절 텍스트
            _buildVerseText(),
            const SizedBox(height: 12),

            // 구절 참조
            _buildReference(),

            // Early Bird 보너스 (해당 시)
            if (earlyBirdBonus.isEligible && !hasClaimedBonus) ...[
              const SizedBox(height: 16),
              _buildEarlyBirdBonus(),
            ],

            const SizedBox(height: 16),

            // 암송하기 버튼
            _buildStudyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      ),
    );
  }

  Color _getGradientColor() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 7) {
      return const Color(0xFF4A3B6B).withValues(alpha: 0.6); // 새벽/아침
    } else if (hour >= 7 && hour < 12) {
      return const Color(0xFF3B5A6B).withValues(alpha: 0.6); // 오전
    } else if (hour >= 12 && hour < 18) {
      return const Color(0xFF6B5A3B).withValues(alpha: 0.6); // 오후
    } else {
      return const Color(0xFF2D1B4E).withValues(alpha: 0.6); // 저녁/밤
    }
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final dateString = '${now.month}월 ${now.day}일';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            _getTimeEmoji(),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오늘의 만나',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                dateString,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // 소스 표시
        if (dailyVerse!.source == 'seasonal')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '시즌',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  String _getTimeEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 7) return '🌅';
    if (hour >= 7 && hour < 12) return '☀️';
    if (hour >= 12 && hour < 18) return '🌤️';
    if (hour >= 18 && hour < 21) return '🌆';
    return '🌙';
  }

  Widget _buildVerseText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '"${dailyVerse!.textKo}"',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildReference() {
    return Row(
      children: [
        const Text(
          '- ',
          style: TextStyle(color: Colors.white54),
        ),
        Text(
          dailyVerse!.reference,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEarlyBirdBonus() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.2),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            earlyBirdBonus.emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Early Bird 보너스!',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  earlyBirdBonus.message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💰', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '+${earlyBirdBonus.bonusAmount}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTapStudy,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 20),
            const SizedBox(width: 8),
            const Text(
              '오늘의 구절 암송하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (earlyBirdBonus.isEligible && !hasClaimedBonus) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${earlyBirdBonus.bonusAmount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Early Bird 보너스 획득 다이얼로그
class EarlyBirdBonusDialog extends StatelessWidget {
  final int bonusAmount;
  final String message;
  final String emoji;
  final VoidCallback onDismiss;

  const EarlyBirdBonusDialog({
    super.key,
    required this.bonusAmount,
    required this.message,
    required this.emoji,
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
            // 이모지
            Text(
              emoji,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),

            // 타이틀
            const Text(
              'Early Bird 보너스!',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 메시지
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // 보너스 표시
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.3),
                    Colors.orange.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Text(
                    '+$bonusAmount 달란트',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '아침 일찍 학습해서 보너스를 획득했어요!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),

            // 확인 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
