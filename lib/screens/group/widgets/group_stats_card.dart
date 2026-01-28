import 'package:flutter/material.dart';
import '../../../models/group_model.dart';

/// 그룹 통계 카드
class GroupStatsCard extends StatelessWidget {
  final GroupModel? group;
  final int memberCount;

  const GroupStatsCard({
    super.key,
    required this.group,
    required this.memberCount,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups, color: _accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group?.name ?? '그룹',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '멤버 $memberCount명',
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

          // 통계 그리드
          Row(
            children: [
              _buildStatItem(
                icon: Icons.toll,
                iconColor: Colors.amber,
                label: '총 탈란트',
                value: '${group?.totalTalants ?? 0}',
              ),
              _buildStatItem(
                icon: Icons.emoji_events,
                iconColor: Colors.orange,
                label: '이번 주 순위',
                value: '#1',
              ),
              _buildStatItem(
                icon: Icons.trending_up,
                iconColor: Colors.green,
                label: '활성률',
                value: '${_calculateActiveRate()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateActiveRate() {
    if (memberCount == 0) return 0;
    // 활성률 계산 로직 (실제로는 서버에서 계산)
    return 75; // 임시 값
  }
}
