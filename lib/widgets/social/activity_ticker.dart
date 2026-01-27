import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/group_activity.dart';
import '../../services/social/group_activity_service.dart';

/// Activity Ticker Widget for Home Screen
class ActivityTicker extends StatefulWidget {
  final String groupId;
  final String groupName;
  final VoidCallback? onTapMore;

  const ActivityTicker({
    super.key,
    required this.groupId,
    required this.groupName,
    this.onTapMore,
  });

  @override
  State<ActivityTicker> createState() => _ActivityTickerState();
}

class _ActivityTickerState extends State<ActivityTicker> {
  final _activityService = GroupActivityService();
  List<GroupActivity> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final activities = await _activityService.getRecentActivities(widget.groupId);
    if (mounted) {
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Text('👥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.groupName} 소식',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onTapMore,
                  child: const Text(
                    '더보기',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Activity List
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_activities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '아직 활동이 없어요\n첫 번째로 암송을 완료해보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _activities.length.clamp(0, 5),
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                return _ActivityItem(
                  activity: _activities[index],
                  groupId: widget.groupId,
                  onReactionChanged: (updated) {
                    setState(() {
                      _activities[index] = updated;
                    });
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Single Activity Item with Reactions
class _ActivityItem extends StatelessWidget {
  final GroupActivity activity;
  final String groupId;
  final ValueChanged<GroupActivity> onReactionChanged;

  const _ActivityItem({
    required this.activity,
    required this.groupId,
    required this.onReactionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.type.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.timeAgo,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Reactions
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 8),
            child: _ReactionBar(
              activity: activity,
              groupId: groupId,
              onReactionChanged: onReactionChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reaction Bar with Optimistic UI
class _ReactionBar extends StatefulWidget {
  final GroupActivity activity;
  final String groupId;
  final ValueChanged<GroupActivity> onReactionChanged;

  const _ReactionBar({
    required this.activity,
    required this.groupId,
    required this.onReactionChanged,
  });

  @override
  State<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<_ReactionBar> {
  final _activityService = GroupActivityService();
  late GroupActivity _localActivity;
  final Map<ReactionType, bool> _pending = {};

  @override
  void initState() {
    super.initState();
    _localActivity = widget.activity;
  }

  @override
  void didUpdateWidget(covariant _ReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != widget.activity.id) {
      _localActivity = widget.activity;
    }
  }

  Future<void> _handleReaction(ReactionType type) async {
    if (_pending[type] == true) return;

    final userId = _activityService.currentUserId;
    if (userId == null) return;

    final hasReacted = _localActivity.hasReacted(userId, type);

    // Optimistic UI update
    setState(() {
      _pending[type] = true;
      _localActivity = _localActivity.copyWithReaction(
        userId: userId,
        type: type,
        add: !hasReacted,
      );
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Notify parent
    widget.onReactionChanged(_localActivity);

    // Server update
    final success = hasReacted
        ? await _activityService.removeReaction(
            groupId: widget.groupId,
            activityId: widget.activity.id,
            type: type,
          )
        : await _activityService.addReaction(
            groupId: widget.groupId,
            activityId: widget.activity.id,
            type: type,
          );

    // Rollback on failure
    if (!success && mounted) {
      setState(() {
        _localActivity = _localActivity.copyWithReaction(
          userId: userId,
          type: type,
          add: hasReacted, // Revert
        );
      });
      widget.onReactionChanged(_localActivity);
    }

    if (mounted) {
      setState(() {
        _pending[type] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _activityService.currentUserId;

    return Row(
      children: ReactionType.values.map((type) {
        final count = _localActivity.reactionCounts[type] ?? 0;
        final hasReacted = userId != null && _localActivity.hasReacted(userId, type);

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _ReactionButton(
            type: type,
            count: count,
            isActive: hasReacted,
            isPending: _pending[type] == true,
            onTap: () => _handleReaction(type),
          ),
        );
      }).toList(),
    );
  }
}

/// Single Reaction Button
class _ReactionButton extends StatefulWidget {
  final ReactionType type;
  final int count;
  final bool isActive;
  final bool isPending;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.type,
    required this.count,
    required this.isActive,
    required this.isPending,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isPending ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isActive
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isActive ? Colors.white24 : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Text(
                widget.type.emoji,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isActive ? null : Colors.white54,
                ),
              ),
            ),
            if (widget.count > 0) ...[
              const SizedBox(width: 4),
              Text(
                widget.count.toString(),
                style: TextStyle(
                  color: widget.isActive ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
