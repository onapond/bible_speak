import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기능 투어 단계 정의
class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final TooltipPosition position;
  final IconData? icon;

  const TourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.position = TooltipPosition.bottom,
    this.icon,
  });
}

/// 툴팁 위치
enum TooltipPosition {
  top,
  bottom,
  left,
  right,
}

/// 기능 투어 컨트롤러
class FeatureTourController extends ChangeNotifier {
  static const String _prefKey = 'feature_tour_completed';

  List<TourStep> _steps = [];
  int _currentStep = 0;
  bool _isActive = false;
  bool _isCompleted = false;

  List<TourStep> get steps => _steps;
  int get currentStep => _currentStep;
  bool get isActive => _isActive;
  bool get isCompleted => _isCompleted;
  TourStep? get currentTourStep =>
      _isActive && _currentStep < _steps.length ? _steps[_currentStep] : null;

  /// 투어 초기화
  Future<void> initialize(List<TourStep> steps) async {
    _steps = steps;
    final prefs = await SharedPreferences.getInstance();
    _isCompleted = prefs.getBool(_prefKey) ?? false;
    notifyListeners();
  }

  /// 투어 시작
  void start() {
    if (_isCompleted || _steps.isEmpty) return;
    _isActive = true;
    _currentStep = 0;
    notifyListeners();
  }

  /// 다음 단계
  void next() {
    if (_currentStep < _steps.length - 1) {
      _currentStep++;
      notifyListeners();
    } else {
      complete();
    }
  }

  /// 이전 단계
  void previous() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  /// 투어 완료
  Future<void> complete() async {
    _isActive = false;
    _isCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    notifyListeners();
  }

  /// 투어 건너뛰기
  Future<void> skip() async {
    await complete();
  }

  /// 투어 초기화 (테스트용)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    _isCompleted = false;
    _isActive = false;
    _currentStep = 0;
    notifyListeners();
  }
}

/// 기능 투어 오버레이
class FeatureTourOverlay extends StatefulWidget {
  final FeatureTourController controller;
  final Widget child;
  final Color spotlightColor;
  final Color overlayColor;

  const FeatureTourOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.spotlightColor = Colors.white,
    this.overlayColor = const Color(0xCC000000),
  });

  @override
  State<FeatureTourOverlay> createState() => _FeatureTourOverlayState();
}

class _FeatureTourOverlayState extends State<FeatureTourOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (widget.controller.isActive) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.controller.isActive)
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildOverlay(context),
          ),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final step = widget.controller.currentTourStep;
    if (step == null) return const SizedBox.shrink();

    final targetContext = step.targetKey.currentContext;
    if (targetContext == null) return const SizedBox.shrink();

    final RenderBox renderBox = targetContext.findRenderObject() as RenderBox;
    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;

    // 타겟 중심점
    final targetCenter = Offset(
      targetPosition.dx + targetSize.width / 2,
      targetPosition.dy + targetSize.height / 2,
    );

    // 스포트라이트 반지름 (패딩 포함)
    final spotlightRadius = (targetSize.width > targetSize.height
            ? targetSize.width
            : targetSize.height) /
        2 +
        16;

    return GestureDetector(
      onTap: () {}, // 터치 차단
      child: Stack(
        children: [
          // 오버레이 배경 (스포트라이트 구멍)
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _SpotlightPainter(
              center: targetCenter,
              radius: spotlightRadius,
              overlayColor: widget.overlayColor,
            ),
          ),

          // 스포트라이트 테두리 애니메이션
          Positioned(
            left: targetCenter.dx - spotlightRadius - 4,
            top: targetCenter.dy - spotlightRadius - 4,
            child: _PulsingCircle(
              radius: spotlightRadius + 4,
              color: widget.spotlightColor,
            ),
          ),

          // 툴팁
          _buildTooltip(context, step, targetPosition, targetSize),
        ],
      ),
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    TourStep step,
    Offset targetPosition,
    Size targetSize,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // 툴팁 위치 계산
    double left = 24;
    double top = targetPosition.dy + targetSize.height + 24;
    double? right;

    // 화면 하단에 가까우면 위로
    if (top + 150 > screenSize.height - padding.bottom - 100) {
      top = targetPosition.dy - 180;
    }

    // 좌우 여백 조정
    if (targetPosition.dx > screenSize.width / 2) {
      right = 24;
      left = 24;
    }

    return Positioned(
      left: left,
      right: right ?? 24,
      top: top,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  children: [
                    if (step.icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          step.icon,
                          color: const Color(0xFF6C63FF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        step.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 닫기 버튼
                    GestureDetector(
                      onTap: widget.controller.skip,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 설명
                Text(
                  step.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // 진행 표시 및 버튼
                Row(
                  children: [
                    // 진행 인디케이터
                    Text(
                      '${widget.controller.currentStep + 1}/${widget.controller.steps.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),

                    // 이전 버튼
                    if (widget.controller.currentStep > 0)
                      TextButton(
                        onPressed: widget.controller.previous,
                        child: const Text(
                          '이전',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),

                    const SizedBox(width: 8),

                    // 다음/완료 버튼
                    ElevatedButton(
                      onPressed: widget.controller.next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        widget.controller.currentStep ==
                                widget.controller.steps.length - 1
                            ? '완료'
                            : '다음',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 스포트라이트 페인터
class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color overlayColor;

  _SpotlightPainter({
    required this.center,
    required this.radius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    // 전체 오버레이
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // 스포트라이트 구멍 (clear blend mode)
    final spotlightPaint = Paint()
      ..blendMode = BlendMode.clear
      ..color = Colors.transparent;

    canvas.drawCircle(center, radius, spotlightPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

/// 펄스 원형 애니메이션
class _PulsingCircle extends StatefulWidget {
  final double radius;
  final Color color;

  const _PulsingCircle({
    required this.radius,
    required this.color,
  });

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
          width: widget.radius * 2,
          height: widget.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 1 - _animation.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

/// 기능 투어 시작 버튼 (마이페이지 등에서 사용)
class StartTourButton extends StatelessWidget {
  final FeatureTourController controller;
  final String label;

  const StartTourButton({
    super.key,
    required this.controller,
    this.label = '앱 둘러보기',
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (controller.isActive) return const SizedBox.shrink();

        return TextButton.icon(
          onPressed: () async {
            await controller.reset();
            controller.start();
          },
          icon: const Icon(Icons.help_outline, size: 18),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
          ),
        );
      },
    );
  }
}
