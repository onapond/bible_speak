import 'package:flutter/material.dart';
import '../../../models/group_model.dart';
import '../../../styles/parchment_theme.dart';

/// 리더보드 카드
class LeaderboardCard extends StatelessWidget {
  final List<MemberInfo> members;
  final String? currentUserId;

  const LeaderboardCard({
    super.key,
    required this.members,
    this.currentUserId,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.emoji_events, size: 48, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                '아직 멤버가 없습니다',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // 상위 3명 (포디움)
          if (members.length >= 3) _buildPodium(),
          if (members.length >= 3)
            const Divider(color: Colors.white12, height: 1),

          // 전체 순위
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.leaderboard, color: _accentColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '전체 순위',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  members.length,
                  (index) => _buildRankItem(index, members[index]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2등
          if (members.length > 1)
            _buildPodiumItem(
              rank: 2,
              member: members[1],
              height: 80,
              color: Colors.grey.shade400,
            ),
          // 1등
          _buildPodiumItem(
            rank: 1,
            member: members[0],
            height: 100,
            color: ParchmentTheme.manuscriptGold,
          ),
          // 3등
          if (members.length > 2)
            _buildPodiumItem(
              rank: 3,
              member: members[2],
              height: 60,
              color: ParchmentTheme.warning,
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required int rank,
    required MemberInfo member,
    required double height,
    required Color color,
  }) {
    final isMe = member.id == currentUserId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 메달
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Text(
            _getRankEmoji(rank),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        const SizedBox(height: 8),

        // 이름
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: isMe
              ? BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Text(
            member.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              color: isMe ? _accentColor : Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 탈란트
        Text(
          '${member.talants}T',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),

        // 받침대
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem(int index, MemberInfo member) {
    final rank = index + 1;
    final isMe = member.id == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? _accentColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: isMe ? Border.all(color: _accentColor.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          // 순위
          SizedBox(
            width: 36,
            child: rank <= 3
                ? Text(
                    _getRankEmoji(rank),
                    style: const TextStyle(fontSize: 20),
                  )
                : Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // 프로필
          CircleAvatar(
            radius: 18,
            backgroundColor: _accentColor.withValues(alpha: 0.2),
            child: Text(
              member.name.isNotEmpty ? member.name[0] : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 이름
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: TextStyle(
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                          color: isMe ? _accentColor : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '나',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 탈란트
          Row(
            children: [
              const Icon(Icons.toll, size: 16, color: ParchmentTheme.manuscriptGold),
              const SizedBox(width: 4),
              Text(
                '${member.talants}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }
}
