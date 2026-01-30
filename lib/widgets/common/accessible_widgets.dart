import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../services/accessibility_service.dart';

/// 접근성 강화 버튼
/// - 최소 터치 영역 보장
/// - 시맨틱 레이블 지원
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;
  final String? semanticHint;
  final bool excludeFromSemantics;
  final double? minSize;

  const AccessibleButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.semanticHint,
    this.excludeFromSemantics = false,
    this.minSize,
  });

  @override
  Widget build(BuildContext context) {
    final a11y = AccessibilityService();
    final targetSize = minSize ?? a11y.minTapTargetSize;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      hint: semanticHint,
      excludeSemantics: excludeFromSemantics,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(targetSize / 2),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: targetSize,
            minHeight: targetSize,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// 접근성 강화 아이콘 버튼
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final Color? color;
  final double? size;
  final Color? backgroundColor;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.color,
    this.size,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final a11y = AccessibilityService();
    final targetSize = a11y.minTapTargetSize;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(targetSize / 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(targetSize / 2),
          child: SizedBox(
            width: targetSize,
            height: targetSize,
            child: Icon(
              icon,
              color: color,
              size: size ?? 24,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      ),
    );
  }
}

/// 접근성 강화 카드
/// - 터치 가능 시 시맨틱 레이블 포함
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? semanticHint;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BorderRadius? borderRadius;

  const AccessibleCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.padding,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF1E1E2E),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );

    if (onTap == null) {
      return semanticLabel != null
          ? Semantics(label: semanticLabel, child: card)
          : card;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      hint: semanticHint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: card,
        ),
      ),
    );
  }
}

/// 접근성 강화 이모지 인디케이터
/// - 이모지에 시맨틱 레이블 추가
class AccessibleEmoji extends StatelessWidget {
  final String emoji;
  final String semanticLabel;
  final double fontSize;
  final VoidCallback? onTap;

  const AccessibleEmoji({
    super.key,
    required this.emoji,
    required this.semanticLabel,
    this.fontSize = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final emojiWidget = Text(
      emoji,
      style: TextStyle(fontSize: fontSize),
    );

    if (onTap != null) {
      final a11y = AccessibilityService();
      return Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(a11y.minTapTargetSize / 2),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: a11y.minTapTargetSize,
              minHeight: a11y.minTapTargetSize,
            ),
            child: Center(child: emojiWidget),
          ),
        ),
      );
    }

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: emojiWidget,
    );
  }
}

/// 접근성 강화 진행 바
class AccessibleProgressBar extends StatelessWidget {
  final double progress;
  final String semanticLabel;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;

  const AccessibleProgressBar({
    super.key,
    required this.progress,
    required this.semanticLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();

    return Semantics(
      value: '$percentage%',
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: height,
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: foregroundColor ?? const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 접근성 텍스트 스타일 확장
extension AccessibleTextStyle on TextStyle {
  /// 시스템 텍스트 크기 설정 적용
  TextStyle withAccessibility(BuildContext context) {
    final a11y = AccessibilityService();
    final scaledSize = (fontSize ?? 14) * a11y.textScaleFactor;
    return copyWith(fontSize: scaledSize);
  }
}

/// 스크린 리더 전용 텍스트 (시각적으로 숨김)
class ScreenReaderText extends StatelessWidget {
  final String text;

  const ScreenReaderText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: const SizedBox.shrink(),
    );
  }
}

/// 접근성 헤더 (스크린 리더가 헤더로 인식)
class AccessibleHeader extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int headingLevel;

  const AccessibleHeader({
    super.key,
    required this.text,
    this.style,
    this.headingLevel = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: style ?? Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
