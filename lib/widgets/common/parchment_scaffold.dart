import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/texture_provider.dart';
import '../../styles/parchment_theme.dart';
import 'parchment_texture_overlay.dart';

/// Parchment 배경 그라데이션과 텍스처가 적용된 Scaffold
///
/// 사용 예시:
/// ```dart
/// ParchmentScaffold(
///   appBar: AppBar(title: Text('제목')),
///   body: YourContent(),
/// )
/// ```
class ParchmentScaffold extends ConsumerWidget {
  const ParchmentScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
    this.useGradient = true,
    this.showTexture = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;
  final bool useGradient;
  final bool showTexture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textureSettings = ref.watch(textureSettingsNotifierProvider);
    final shouldShowTexture = showTexture && textureSettings.enabled;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Container(
        decoration: BoxDecoration(
          gradient: useGradient ? ParchmentTheme.backgroundGradient : null,
          color: useGradient ? null : ParchmentTheme.agedParchment,
        ),
        child: Stack(
          children: [
            // 텍스처 오버레이 (배경 위, 콘텐츠 아래)
            if (shouldShowTexture) const ParchmentTextureOverlay(),
            // 메인 콘텐츠
            body,
          ],
        ),
      ),
    );
  }
}

/// Parchment 스타일의 AppBar
class ParchmentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ParchmentAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.showBackButton = true,
    this.elevation = 0,
    this.backgroundColor,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBackButton;
  final double elevation;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: elevation,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: showBackButton,
      leading: leading ??
          (showBackButton && Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  color: ParchmentTheme.ancientInk,
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ParchmentTheme.ancientInk,
                  ),
                )
              : null),
      actions: actions,
    );
  }
}

/// Parchment 배경을 가진 SafeArea
class ParchmentSafeArea extends StatelessWidget {
  const ParchmentSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  });

  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: ParchmentTheme.backgroundGradient,
      ),
      child: SafeArea(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: child,
      ),
    );
  }
}
