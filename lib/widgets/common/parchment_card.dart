import 'package:flutter/material.dart';
import '../../styles/parchment_theme.dart';

/// Parchment 스타일의 카드 컴포넌트
///
/// 사용 예시:
/// ```dart
/// ParchmentCard(
///   child: Text('내용'),
///   onTap: () => print('탭!'),
/// )
/// ```
class ParchmentCard extends StatelessWidget {
  const ParchmentCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.showBorder = true,
    this.showShadow = true,
    this.backgroundColor,
    this.borderColor,
    this.elevation = 0,
    this.width,
    this.height,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool showBorder;
  final bool showShadow;
  final Color? backgroundColor;
  final Color? borderColor;
  final double elevation;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(ParchmentTheme.radiusLarge);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? ParchmentTheme.softPapyrus,
        borderRadius: radius,
        border: showBorder
            ? Border.all(
                color: borderColor ?? ParchmentTheme.manuscriptGold.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
        boxShadow: showShadow ? ParchmentTheme.cardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: ParchmentTheme.manuscriptGold.withValues(alpha: 0.1),
          highlightColor: ParchmentTheme.manuscriptGold.withValues(alpha: 0.05),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 아이콘이 있는 Parchment 카드 (메뉴 아이템용)
class ParchmentIconCard extends StatelessWidget {
  const ParchmentIconCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.iconBackgroundColor,
    this.showArrow = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return ParchmentCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBackgroundColor ?? ParchmentTheme.warmVellum,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor ?? ParchmentTheme.manuscriptGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ParchmentTheme.weatheredGray,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 트레일링 또는 화살표
          if (trailing != null)
            trailing!
          else if (showArrow)
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: ParchmentTheme.weatheredGray.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }
}

/// 통계/수치를 표시하는 Parchment 카드
class ParchmentStatCard extends StatelessWidget {
  const ParchmentStatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.valueColor,
    this.onTap,
    this.width,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? valueColor;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ParchmentCard(
      onTap: onTap,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: ParchmentTheme.manuscriptGold,
              size: 28,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor ?? ParchmentTheme.manuscriptGold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: ParchmentTheme.weatheredGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 섹션 헤더 카드
class ParchmentSectionHeader extends StatelessWidget {
  const ParchmentSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: ParchmentTheme.manuscriptGold,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ParchmentTheme.weatheredGray,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 강조된 Parchment 카드 (골드 테두리)
class ParchmentHighlightCard extends StatelessWidget {
  const ParchmentHighlightCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.showGlow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ParchmentTheme.radiusLarge),
        boxShadow: showGlow ? ParchmentTheme.goldGlow : null,
      ),
      child: ParchmentCard(
        onTap: onTap,
        padding: padding,
        borderColor: ParchmentTheme.manuscriptGold.withValues(alpha: 0.6),
        child: child,
      ),
    );
  }
}
