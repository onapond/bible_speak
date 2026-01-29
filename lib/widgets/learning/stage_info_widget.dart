import 'package:flutter/material.dart';

/// 학습 단계 정보 위젯
/// 3단계 학습 시스템의 목표와 통과 기준을 설명
class StageInfoWidget extends StatelessWidget {
  final int currentStage;
  final double? currentScore;
  final double? bestScore;

  const StageInfoWidget({
    super.key,
    required this.currentStage,
    this.currentScore,
    this.bestScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 단계 표시
          Row(
            children: [
              _buildStageIndicator(1, '듣고 따라하기', 70),
              _buildStageDivider(),
              _buildStageIndicator(2, '핵심 표현', 75),
              _buildStageDivider(),
              _buildStageIndicator(3, '실전 암송', 80),
            ],
          ),

          // 현재 단계 설명
          const SizedBox(height: 16),
          _buildCurrentStageInfo(),

          // 점수 비교 (있는 경우)
          if (bestScore != null && currentScore != null) ...[
            const SizedBox(height: 12),
            _buildScoreComparison(),
          ],
        ],
      ),
    );
  }

  Widget _buildStageIndicator(int stage, String label, int threshold) {
    final isActive = stage == currentStage;
    final isCompleted = stage < currentStage;
    final color = isCompleted
        ? const Color(0xFF4CAF50)
        : isActive
            ? const Color(0xFF6C63FF)
            : Colors.grey;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted
                  ? color
                  : color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '$stage',
                      style: TextStyle(
                        color: isActive ? color : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$threshold%',
            style: TextStyle(
              fontSize: 10,
              color: isActive ? color : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageDivider() {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 30),
      color: Colors.grey[700],
    );
  }

  Widget _buildCurrentStageInfo() {
    final stageInfo = _getStageInfo(currentStage);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF6C63FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              stageInfo.icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stageInfo.name} (${stageInfo.threshold}% 이상)',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stageInfo.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreComparison() {
    final improved = currentScore! > bestScore!;
    final diff = (currentScore! - bestScore!).abs();

    return Row(
      children: [
        Text(
          '최고 기록: ${bestScore!.toInt()}%',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[400],
          ),
        ),
        if (improved) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.trending_up,
                  color: Color(0xFF4CAF50),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '+${diff.toInt()}% 향상!',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  _StageInfo _getStageInfo(int stage) {
    switch (stage) {
      case 1:
        return _StageInfo(
          name: '듣고 따라하기',
          description: '오디오를 들으며 전체 자막을 보고 따라 읽어요',
          threshold: 70,
          icon: Icons.headphones,
        );
      case 2:
        return _StageInfo(
          name: '핵심 표현',
          description: '일부 단어가 빈칸으로 표시돼요. 기억해서 읽어보세요',
          threshold: 75,
          icon: Icons.edit_note,
        );
      case 3:
        return _StageInfo(
          name: '실전 암송',
          description: '자막 없이 암송해요. 성공하면 완전히 외운 거예요!',
          threshold: 80,
          icon: Icons.mic,
        );
      default:
        return _StageInfo(
          name: '학습',
          description: '',
          threshold: 70,
          icon: Icons.school,
        );
    }
  }
}

class _StageInfo {
  final String name;
  final String description;
  final int threshold;
  final IconData icon;

  _StageInfo({
    required this.name,
    required this.description,
    required this.threshold,
    required this.icon,
  });
}

/// 단계 완료 축하 다이얼로그
class StageCompleteDialog extends StatelessWidget {
  final int completedStage;
  final double score;
  final VoidCallback onNextStage;
  final VoidCallback onNextVerse;

  const StageCompleteDialog({
    super.key,
    required this.completedStage,
    required this.score,
    required this.onNextStage,
    required this.onNextVerse,
  });

  @override
  Widget build(BuildContext context) {
    final isFullyComplete = completedStage == 3;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFullyComplete ? '🎉' : '✨',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              isFullyComplete ? '암송 완료!' : '단계 통과!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFullyComplete
                  ? '이 구절을 완전히 암송했어요!'
                  : 'Stage $completedStage를 ${score.toInt()}%로 통과했어요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),

            if (isFullyComplete)
              // 완전 암송 시: 다음 구절로
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNextVerse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '다음 구절 학습하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              // 중간 단계 완료 시: 다음 단계 or 다음 구절
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onNextStage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Stage ${completedStage + 1} 도전하기',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onNextVerse,
                    child: Text(
                      '다음 구절로 넘어가기',
                      style: TextStyle(
                        color: Colors.grey[400],
                      ),
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

/// 첫 학습 가이드 오버레이
class FirstLearningGuideOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const FirstLearningGuideOverlay({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '3단계 학습 시스템',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              _buildGuideItem(
                number: '1',
                title: '듣고 따라하기',
                description: '네이티브 오디오를 들으며\n전체 자막을 보고 따라 읽어요',
                icon: Icons.headphones,
                threshold: '70% 이상',
              ),
              const SizedBox(height: 20),

              _buildGuideItem(
                number: '2',
                title: '핵심 표현',
                description: '일부 단어가 빈칸이 돼요\n기억을 되살려 읽어보세요',
                icon: Icons.edit_note,
                threshold: '75% 이상',
              ),
              const SizedBox(height: 20),

              _buildGuideItem(
                number: '3',
                title: '실전 암송',
                description: '자막 없이 완전히 암송해요\n통과하면 외운 거예요!',
                icon: Icons.mic,
                threshold: '80% 이상',
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '이해했어요, 시작할게요!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideItem({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required String threshold,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              threshold,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
