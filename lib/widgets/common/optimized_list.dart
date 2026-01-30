import 'package:flutter/material.dart';

/// 최적화된 리스트 아이템 래퍼
/// - RepaintBoundary로 리페인트 범위 제한
/// - AutomaticKeepAlive로 스크롤 시 상태 유지
class OptimizedListItem extends StatefulWidget {
  final Widget child;
  final bool keepAlive;
  final bool useRepaintBoundary;

  const OptimizedListItem({
    super.key,
    required this.child,
    this.keepAlive = false,
    this.useRepaintBoundary = true,
  });

  @override
  State<OptimizedListItem> createState() => _OptimizedListItemState();
}

class _OptimizedListItemState extends State<OptimizedListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Widget child = widget.child;

    if (widget.useRepaintBoundary) {
      child = RepaintBoundary(child: child);
    }

    return child;
  }
}

/// 최적화된 ListView.builder 래퍼
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool reverse;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool addRepaintBoundaries;
  final bool addAutomaticKeepAlives;
  final double? cacheExtent;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.reverse = false,
    this.physics,
    this.shrinkWrap = false,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.cacheExtent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      reverse: reverse,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      addRepaintBoundaries: addRepaintBoundaries,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      cacheExtent: cacheExtent ?? 500.0, // 기본 캐시 확장
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// 최적화된 GridView.builder 래퍼
class OptimizedGridView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double? cacheExtent;

  const OptimizedGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.cacheExtent,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      cacheExtent: cacheExtent ?? 500.0,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// 지연 로딩 리스트 (무한 스크롤)
class LazyLoadListView extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final EdgeInsetsGeometry? padding;
  final Widget? loadingWidget;
  final double loadMoreThreshold;

  const LazyLoadListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onLoadMore,
    this.hasMore = false,
    this.padding,
    this.loadingWidget,
    this.loadMoreThreshold = 200.0,
  });

  @override
  State<LazyLoadListView> createState() => _LazyLoadListViewState();
}

class _LazyLoadListViewState extends State<LazyLoadListView> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !widget.hasMore || widget.onLoadMore == null) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= widget.loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await widget.onLoadMore?.call();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: widget.itemCount + (widget.hasMore ? 1 : 0),
      addRepaintBoundaries: true,
      cacheExtent: 500.0,
      itemBuilder: (context, index) {
        if (index == widget.itemCount) {
          return widget.loadingWidget ??
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        }

        return RepaintBoundary(
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

/// 슬라이버용 최적화된 리스트
class OptimizedSliverList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final bool addRepaintBoundaries;

  const OptimizedSliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.addRepaintBoundaries = true,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final child = itemBuilder(context, index);
          return addRepaintBoundaries ? RepaintBoundary(child: child) : child;
        },
        childCount: itemCount,
        addRepaintBoundaries: addRepaintBoundaries,
        addAutomaticKeepAlives: true,
      ),
    );
  }
}

/// const 최적화된 공통 위젯들
class OptimizedWidgets {
  OptimizedWidgets._();

  /// 공통 간격 위젯 (const 최적화)
  static const sizedBox4 = SizedBox(height: 4);
  static const sizedBox6 = SizedBox(height: 6);
  static const sizedBox8 = SizedBox(height: 8);
  static const sizedBox10 = SizedBox(height: 10);
  static const sizedBox12 = SizedBox(height: 12);
  static const sizedBox16 = SizedBox(height: 16);
  static const sizedBox20 = SizedBox(height: 20);
  static const sizedBox24 = SizedBox(height: 24);
  static const sizedBox32 = SizedBox(height: 32);

  static const sizedBoxW4 = SizedBox(width: 4);
  static const sizedBoxW6 = SizedBox(width: 6);
  static const sizedBoxW8 = SizedBox(width: 8);
  static const sizedBoxW10 = SizedBox(width: 10);
  static const sizedBoxW12 = SizedBox(width: 12);
  static const sizedBoxW16 = SizedBox(width: 16);

  /// 공통 패딩
  static const padding8 = EdgeInsets.all(8);
  static const padding12 = EdgeInsets.all(12);
  static const padding16 = EdgeInsets.all(16);
  static const paddingH16 = EdgeInsets.symmetric(horizontal: 16);
  static const paddingV8 = EdgeInsets.symmetric(vertical: 8);
  static const paddingV16 = EdgeInsets.symmetric(vertical: 16);

  /// 공통 원형 보더
  static final borderRadius8 = BorderRadius.circular(8);
  static final borderRadius12 = BorderRadius.circular(12);
  static final borderRadius16 = BorderRadius.circular(16);
  static final borderRadius20 = BorderRadius.circular(20);

  /// 공통 로딩 인디케이터
  static const loadingIndicator = Center(
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  /// 공통 에러 아이콘
  static const errorIcon = Icon(
    Icons.error_outline,
    color: Colors.red,
    size: 48,
  );
}

/// 위젯 최적화 확장
extension WidgetOptimization on Widget {
  /// RepaintBoundary로 감싸기
  Widget withRepaintBoundary() => RepaintBoundary(child: this);

  /// 키 추가
  Widget withKey(Key key) => KeyedSubtree(key: key, child: this);
}
