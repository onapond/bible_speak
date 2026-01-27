import 'package:flutter/material.dart';

/// Weekly Group Challenge Model
class WeeklyChallenge {
  final String id;
  final String theme;
  final int targetValue;
  final int currentValue;
  final DateTime weekEnd;
  final Map<String, int> contributors;

  const WeeklyChallenge({
    required this.id,
    required this.theme,
    required this.targetValue,
    required this.currentValue,
    required this.weekEnd,
    this.contributors = const {},
  });

  double get progress => (currentValue / targetValue).clamp(0.0, 1.0);
  int get percentage => (progress * 100).round();
  bool get isCompleted => currentValue >= targetValue;

  String get remainingTime {
    final diff = weekEnd.difference(DateTime.now());
    if (diff.isNegative) return '종료됨';
    if (diff.inDays > 0) return '${diff.inDays}일 ${diff.inHours % 24}시간';
    if (diff.inHours > 0) return '${diff.inHours}시간 ${diff.inMinutes % 60}분';
    return '${diff.inMinutes}분';
  }

  factory WeeklyChallenge.fromFirestore(String id, Map<String, dynamic> data) {
    final contributorsData = data['contributors'] as Map<String, dynamic>? ?? {};
    final contributors = contributorsData.map((k, v) => MapEntry(k, (v as num).toInt()));

    return WeeklyChallenge(
      id: id,
      theme: data['theme'] ?? 'temple',
      targetValue: data['targetValue'] ?? 40,
      currentValue: data['currentValue'] ?? 0,
      weekEnd: (data['weekEnd'] as dynamic)?.toDate() ?? DateTime.now(),
      contributors: contributors,
    );
  }
}

/// Group Goal Widget with Temple Building Theme
class GroupGoalWidget extends StatelessWidget {
  final WeeklyChallenge challenge;
  final int? myContribution;
  final VoidCallback? onTapContribute;

  const GroupGoalWidget({
    super.key,
    required this.challenge,
    this.myContribution,
    this.onTapContribute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D1B4E),
            const Color(0xFF1A1A2E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Text('🏛️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이번 주 그룹 챌린지',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '"함께 성전을 쌓아요!"',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    challenge.remainingTime,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Temple Visualization
          SizedBox(
            height: 100,
            child: _TempleVisualization(progress: challenge.progress),
          ),

          const SizedBox(height: 12),

          // Progress Bar & Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Progress bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      height: 8,
                      width: MediaQuery.of(context).size.width *
                          0.85 *
                          challenge.progress,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${challenge.percentage}% 달성!',
                      style: TextStyle(
                        color: challenge.isCompleted
                            ? const Color(0xFFFFD700)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${challenge.currentValue}/${challenge.targetValue}절',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // My Contribution & CTA
          if (myContribution != null || onTapContribute != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  if (myContribution != null) ...[
                    const Icon(Icons.person, color: Colors.white38, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '내 기여: $myContribution절',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (onTapContribute != null && !challenge.isCompleted)
                    TextButton(
                      onPressed: onTapContribute,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700).withOpacity(0.15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        '암송하러 가기',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Temple Building Visualization
class _TempleVisualization extends StatelessWidget {
  final double progress;

  const _TempleVisualization({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TemplePainter(progress: progress),
      size: Size.infinite,
    );
  }
}

class _TemplePainter extends CustomPainter {
  final double progress;

  _TemplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height - 10;

    // Colors based on progress
    final stoneColor = Color.lerp(
      const Color(0xFF4A4A5A),
      const Color(0xFFFFD700),
      progress,
    )!;
    final shadowColor = Colors.black26;

    // Foundation
    final foundationPaint = Paint()
      ..color = stoneColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final foundationPath = Path()
      ..moveTo(centerX - 60, baseY)
      ..lineTo(centerX + 60, baseY)
      ..lineTo(centerX + 50, baseY - 8)
      ..lineTo(centerX - 50, baseY - 8)
      ..close();
    canvas.drawPath(foundationPath, foundationPaint);

    // Build progress determines how many layers to show
    final layers = (progress * 5).ceil().clamp(0, 5);

    // Temple body (layers)
    for (int i = 0; i < layers; i++) {
      final layerProgress = ((progress * 5) - i).clamp(0.0, 1.0);
      final yOffset = baseY - 12 - (i * 14);
      final widthFactor = 1.0 - (i * 0.08);

      final layerPaint = Paint()
        ..color = stoneColor.withOpacity(0.6 + (i * 0.08) * layerProgress)
        ..style = PaintingStyle.fill;

      final layerPath = Path()
        ..moveTo(centerX - 45 * widthFactor, yOffset)
        ..lineTo(centerX + 45 * widthFactor, yOffset)
        ..lineTo(centerX + 40 * widthFactor, yOffset - 12)
        ..lineTo(centerX - 40 * widthFactor, yOffset - 12)
        ..close();

      canvas.drawPath(layerPath, layerPaint);

      // Pillar details
      if (layerProgress > 0.5) {
        final pillarPaint = Paint()
          ..color = stoneColor.withOpacity(0.3)
          ..style = PaintingStyle.fill;

        // Left pillar
        canvas.drawRect(
          Rect.fromLTWH(centerX - 35 * widthFactor, yOffset - 10, 6, 10),
          pillarPaint,
        );
        // Right pillar
        canvas.drawRect(
          Rect.fromLTWH(centerX + 29 * widthFactor, yOffset - 10, 6, 10),
          pillarPaint,
        );
      }
    }

    // Roof (only when progress > 80%)
    if (progress > 0.8) {
      final roofProgress = ((progress - 0.8) / 0.2).clamp(0.0, 1.0);
      final roofY = baseY - 82;

      final roofPaint = Paint()
        ..color = stoneColor.withOpacity(roofProgress)
        ..style = PaintingStyle.fill;

      final roofPath = Path()
        ..moveTo(centerX - 50, roofY + 10)
        ..lineTo(centerX, roofY - 15)
        ..lineTo(centerX + 50, roofY + 10)
        ..close();

      canvas.drawPath(roofPath, roofPaint);

      // Cross on top (100% complete)
      if (progress >= 1.0) {
        final crossPaint = Paint()
          ..color = const Color(0xFFFFD700)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Vertical
        canvas.drawLine(
          Offset(centerX, roofY - 25),
          Offset(centerX, roofY - 8),
          crossPaint,
        );
        // Horizontal
        canvas.drawLine(
          Offset(centerX - 8, roofY - 18),
          Offset(centerX + 8, roofY - 18),
          crossPaint,
        );
      }
    }

    // Glow effect when completed
    if (progress >= 1.0) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      canvas.drawCircle(Offset(centerX, baseY - 50), 40, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TemplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Celebration overlay when goal is completed
class GoalCelebrationOverlay extends StatelessWidget {
  final WeeklyChallenge challenge;
  final int rewardDalants;
  final VoidCallback onDismiss;

  const GoalCelebrationOverlay({
    super.key,
    required this.challenge,
    required this.rewardDalants,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2D1B4E), Color(0xFF1A1A2E)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎊 축하합니다! 🎊',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '우리 그룹이 이번 주 목표를\n함께 달성했어요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '⛪ 성전 완성! ⛪',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${challenge.targetValue}절 / ${challenge.targetValue}절 (100%)',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      '📦 보상 지급 완료!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '💰 $rewardDalants 달란트',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
