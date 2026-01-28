import 'package:flutter/material.dart';

/// 숫자가 부드럽게 변하는 애니메이션 카운터
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String? prefix;
  final String? suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '${prefix ?? ''}$animatedValue${suffix ?? ''}',
          style: style,
        );
      },
    );
  }
}

/// 스트로크 진행바 애니메이션
class AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Color? backgroundColor;
  final Color? valueColor;
  final double height;
  final Duration duration;
  final BorderRadius? borderRadius;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.backgroundColor,
    this.valueColor,
    this.height = 8,
    this.duration = const Duration(milliseconds: 800),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white.withValues(alpha: 0.1);
    final valColor = valueColor ?? const Color(0xFF6C63FF);
    final radius = borderRadius ?? BorderRadius.circular(height / 2);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: radius,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: animatedProgress,
            child: Container(
              decoration: BoxDecoration(
                color: valColor,
                borderRadius: radius,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 원형 진행률 애니메이션
class AnimatedCircularProgress extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? backgroundColor;
  final Color? valueColor;
  final Duration duration;
  final Widget? child;

  const AnimatedCircularProgress({
    super.key,
    required this.progress,
    this.size = 60,
    this.strokeWidth = 6,
    this.backgroundColor,
    this.valueColor,
    this.duration = const Duration(milliseconds: 1000),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white.withValues(alpha: 0.1);
    final valColor = valueColor ?? const Color(0xFF6C63FF);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // 배경 원
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: strokeWidth,
                  valueColor: AlwaysStoppedAnimation(bgColor),
                ),
              ),
              // 진행률 원
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: animatedProgress,
                  strokeWidth: strokeWidth,
                  valueColor: AlwaysStoppedAnimation(valColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // 중앙 위젯
              if (child != null) Center(child: child),
            ],
          ),
        );
      },
    );
  }
}

/// 탈란트 카운터 (코인 아이콘 포함)
class TalantCounter extends StatelessWidget {
  final int value;
  final double iconSize;
  final TextStyle? style;
  final bool animate;

  const TalantCounter({
    super.key,
    required this.value,
    this.iconSize = 18,
    this.style,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? const TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.amber,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.toll, color: Colors.amber, size: iconSize),
        const SizedBox(width: 4),
        if (animate)
          AnimatedCounter(value: value, style: textStyle)
        else
          Text('$value', style: textStyle),
      ],
    );
  }
}

/// 스트릭 카운터 (불 아이콘 포함)
class StreakCounter extends StatelessWidget {
  final int days;
  final double iconSize;
  final TextStyle? style;
  final bool animate;

  const StreakCounter({
    super.key,
    required this.days,
    this.iconSize = 18,
    this.style,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? const TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.orange,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department, color: Colors.orange, size: iconSize),
        const SizedBox(width: 4),
        if (animate)
          AnimatedCounter(value: days, style: textStyle, suffix: '일')
        else
          Text('$days일', style: textStyle),
      ],
    );
  }
}
