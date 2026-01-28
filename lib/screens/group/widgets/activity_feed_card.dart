import 'package:flutter/material.dart';
import '../../../models/group_activity.dart';
import '../../../services/social/group_activity_service.dart';

/// 활동 피드 카드
class ActivityFeedCard extends StatelessWidget {
  final String groupId;
  final GroupActivityService activityService;

  const ActivityFeedCard({
    super.key,
    required this.groupId,
    required this.activityService,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.dynamic_feed, color: _accentColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '최근 활동',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '7일간',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 활동 스트림
          StreamBuilder<List<GroupActivity>>(
            stream: activityService.watchActivities(groupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: _accentColor),
                  ),
                );
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.celebration,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '아직 활동이 없습니다',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '첫 번째 활동을 시작해보세요!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (_, __) => const Divider(
                  color: Colors.white12,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  return _ActivityItem(
                    activity: activities[index],
                    activityService: activityService,
                    groupId: groupId,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatefulWidget {
  final GroupActivity activity;
  final GroupActivityService activityService;
  final String groupId;

  const _ActivityItem({
    required this.activity,
    required this.activityService,
    required this.groupId,
  });

  @override
  State<_ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<_ActivityItem> {
  static const _accentColor = Color(0xFF6C63FF);
  late GroupActivity _activity;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
  }

  @override
  void didUpdateWidget(covariant _ActivityItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != widget.activity.id) {
      _activity = widget.activity;
    }
  }

  Future<void> _toggleReaction(ReactionType type) async {
    final userId = widget.activityService.currentUserId;
    if (userId == null) return;

    final hasReacted = _activity.hasReacted(userId, type);

    // Optimistic UI update
    setState(() {
      _activity = _activity.copyWithReaction(
        userId: userId,
        type: type,
        add: !hasReacted,
      );
    });

    // Server update
    final result = await widget.activityService.toggleReaction(
      groupId: widget.groupId,
      activityId: _activity.id,
      type: type,
    );

    // Revert if failed
    if (result == null) {
      setState(() {
        _activity = _activity.copyWithReaction(
          userId: userId,
          type: type,
          add: hasReacted,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.activityService.currentUserId;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 유저 정보 + 시간
          Row(
            children: [
              // 타입 아이콘
              Text(
                _activity.type.icon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),

              // 메시지
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activity.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activity.timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 리액션 버튼
          const SizedBox(height: 12),
          Row(
            children: [
              ...ReactionType.values.map((type) {
                final hasReacted = userId != null && _activity.hasReacted(userId, type);
                final count = _activity.reactionCounts[type] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _toggleReaction(type),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasReacted
                            ? _accentColor.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: hasReacted
                            ? Border.all(color: _accentColor.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(type.emoji, style: const TextStyle(fontSize: 14)),
                          if (count > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasReacted ? _accentColor : Colors.white70,
                                fontWeight: hasReacted ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
