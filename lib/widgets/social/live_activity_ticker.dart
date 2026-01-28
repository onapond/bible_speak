import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/group_activity.dart';
import '../../services/social/group_activity_service.dart';

/// Live Activity Ticker - 실시간 그룹 활동 스트림
/// Speak 스타일의 부드러운 스크롤 애니메이션
class LiveActivityTicker extends StatefulWidget {
  final String groupId;
  final double height;
  final VoidCallback? onTap;

  const LiveActivityTicker({
    super.key,
    required this.groupId,
    this.height = 48,
    this.onTap,
  });

  @override
  State<LiveActivityTicker> createState() => _LiveActivityTickerState();
}

class _LiveActivityTickerState extends State<LiveActivityTicker>
    with SingleTickerProviderStateMixin {
  final GroupActivityService _activityService = GroupActivityService();
  final ScrollController _scrollController = ScrollController();

  List<GroupActivity> _activities = [];
  StreamSubscription? _subscription;
  Timer? _scrollTimer;
  bool _isPaused = false;

  // 디자인 상수
  static const _bgColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);
  static const _scrollSpeed = 50.0; // pixels per second

  @override
  void initState() {
    super.initState();
    _subscribeToActivities();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToActivities() {
    _subscription = _activityService
        .watchActivities(widget.groupId)
        .listen((activities) {
      if (mounted) {
        setState(() {
          _activities = activities;
        });
        _startAutoScroll();
      }
    });
  }

  void _startAutoScroll() {
    _scrollTimer?.cancel();

    if (_activities.isEmpty || !_scrollController.hasClients) return;

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isPaused && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;

        if (currentScroll >= maxScroll) {
          // Reset to beginning
          _scrollController.jumpTo(0);
        } else {
          // Smooth scroll
          _scrollController.jumpTo(currentScroll + (_scrollSpeed / 20));
        }
      }
    });
  }

  void _pauseScroll() {
    setState(() => _isPaused = true);
  }

  void _resumeScroll() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isPaused = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activities.isEmpty) {
      return _buildEmptyState();
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pauseScroll(),
      onTapUp: (_) => _resumeScroll(),
      onTapCancel: _resumeScroll,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: _bgColor,
          border: Border(
            top: BorderSide(color: _accentColor.withValues(alpha: 0.3), width: 1),
            bottom: BorderSide(color: _accentColor.withValues(alpha: 0.3), width: 1),
          ),
        ),
        child: Row(
          children: [
            // 라이브 인디케이터
            _buildLiveIndicator(),
            // 스크롤 영역
            Expanded(
              child: ClipRect(
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activities.length * 2, // 무한 스크롤 효과
                  itemBuilder: (context, index) {
                    final activity = _activities[index % _activities.length];
                    return _buildActivityItem(activity);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border(
          top: BorderSide(color: _accentColor.withValues(alpha: 0.3), width: 1),
          bottom: BorderSide(color: _accentColor.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildLiveIndicator(),
          Expanded(
            child: Center(
              child: Text(
                '아직 활동이 없습니다. 첫 번째로 암송을 시작해보세요!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 펄스 애니메이션 점
          _PulsingDot(color: Colors.red),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(GroupActivity activity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 이모지
          Text(
            activity.type.icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          // 메시지
          Text(
            activity.message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          // 시간
          Text(
            activity.timeAgo,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          // 리액션 카운트
          if (activity.totalReactions > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👏', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                  Text(
                    '${activity.totalReactions}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 구분선
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

/// 펄스 애니메이션 점
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// AnimatedBuilder 위젯 (verse_roadmap_screen에서 가져옴)
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder2({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
