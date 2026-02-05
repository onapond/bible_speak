import 'package:flutter/material.dart';
import '../../styles/parchment_theme.dart';

/// Parchment 스타일의 Primary 버튼 (골드)
///
/// 사용 예시:
/// ```dart
/// ParchmentButton(
///   onPressed: () => print('탭!'),
///   label: '시작하기',
/// )
/// ```
class ParchmentButton extends StatelessWidget {
  const ParchmentButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height,
    this.padding,
    this.fontSize,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = isEnabled && !isLoading && onPressed != null;

    return SizedBox(
      width: width,
      height: height ?? 52,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ParchmentTheme.radiusMedium),
          boxShadow: enabled ? ParchmentTheme.buttonShadow : null,
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled
                ? ParchmentTheme.manuscriptGold
                : ParchmentTheme.goldMuted.withValues(alpha: 0.5),
            foregroundColor: ParchmentTheme.softPapyrus,
            disabledBackgroundColor: ParchmentTheme.warmVellum,
            disabledForegroundColor: ParchmentTheme.weatheredGray,
            elevation: 0,
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ParchmentTheme.radiusMedium),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ParchmentTheme.softPapyrus.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: fontSize ?? 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Parchment 스타일의 Secondary 버튼 (아웃라인)
class ParchmentOutlineButton extends StatelessWidget {
  const ParchmentOutlineButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height,
    this.borderColor,
    this.textColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double? height;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final enabled = isEnabled && !isLoading && onPressed != null;

    return SizedBox(
      width: width,
      height: height ?? 52,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? ParchmentTheme.ancientInk,
          side: BorderSide(
            color: enabled
                ? (borderColor ?? ParchmentTheme.manuscriptGold)
                : ParchmentTheme.warmVellum,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ParchmentTheme.radiusMedium),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ParchmentTheme.manuscriptGold,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Parchment 스타일의 Text 버튼
class ParchmentTextButton extends StatelessWidget {
  const ParchmentTextButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.color,
    this.fontSize,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? ParchmentTheme.manuscriptGold;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize ?? 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Parchment 스타일의 아이콘 버튼
class ParchmentIconButton extends StatelessWidget {
  const ParchmentIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
    this.backgroundColor,
    this.iconColor,
    this.showBorder = false,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool showBorder;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? ParchmentTheme.warmVellum.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(size / 2),
        border: showBorder
            ? Border.all(
                color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.5),
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: ParchmentTheme.manuscriptGold.withValues(alpha: 0.2),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? ParchmentTheme.ancientInk,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    return button;
  }
}

/// 큰 액션 버튼 (Full width)
class ParchmentActionButton extends StatelessWidget {
  const ParchmentActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.subtitle,
    this.isLoading = false,
    this.isEnabled = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final String? subtitle;
  final bool isLoading;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final enabled = isEnabled && !isLoading && onPressed != null;

    return Container(
      width: double.infinity,
      height: subtitle != null ? 72 : 56,
      decoration: BoxDecoration(
        gradient: enabled ? ParchmentTheme.goldButtonGradient : null,
        color: enabled ? null : ParchmentTheme.warmVellum,
        borderRadius: BorderRadius.circular(ParchmentTheme.radiusMedium),
        boxShadow: enabled ? ParchmentTheme.buttonShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ParchmentTheme.radiusMedium),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(ParchmentTheme.radiusMedium),
          splashColor: Colors.white.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        enabled
                            ? ParchmentTheme.softPapyrus
                            : ParchmentTheme.weatheredGray,
                      ),
                    ),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 24,
                      color: enabled
                          ? ParchmentTheme.softPapyrus
                          : ParchmentTheme.weatheredGray,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? ParchmentTheme.softPapyrus
                              : ParchmentTheme.weatheredGray,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: enabled
                                ? ParchmentTheme.softPapyrus.withValues(alpha: 0.8)
                                : ParchmentTheme.weatheredGray.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip 스타일 버튼
class ParchmentChip extends StatelessWidget {
  const ParchmentChip({
    super.key,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? ParchmentTheme.manuscriptGold : ParchmentTheme.warmVellum,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? null
                : Border.all(
                    color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3),
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? ParchmentTheme.softPapyrus
                      : ParchmentTheme.ancientInk,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? ParchmentTheme.softPapyrus
                      : ParchmentTheme.ancientInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
