import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/texture_provider.dart';
import '../../styles/parchment_theme.dart';
import '../../widgets/common/parchment_texture_overlay.dart';

/// 텍스처 설정 화면
class TextureSettingsScreen extends ConsumerWidget {
  const TextureSettingsScreen({super.key});

  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(textureSettingsNotifierProvider);
    final notifier = ref.read(textureSettingsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ParchmentTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      color: ParchmentTheme.ancientInk,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        '텍스처 설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 미리보기
                    _buildSectionTitle('미리보기'),
                    const SizedBox(height: 12),
                    _buildPreviewCard(settings),
                    const SizedBox(height: 24),

                    // 텍스처 켜기/끄기
                    _buildSectionTitle('텍스처'),
                    const SizedBox(height: 12),
                    _buildToggleCard(settings, notifier),
                    const SizedBox(height: 24),

                    // 강도 조절
                    _buildSectionTitle('강도 조절'),
                    const SizedBox(height: 12),
                    _buildSliderCard(settings, notifier),
                    const SizedBox(height: 24),

                    // 초기화
                    _buildResetButton(context, notifier),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: ParchmentTheme.fadedScript,
        ),
      ),
    );
  }

  Widget _buildPreviewCard(TextureSettings settings) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: ParchmentTheme.backgroundGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 텍스처 오버레이
          if (settings.enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: settings.coarseOpacity,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PerlinNoisePainter(),
                      isComplex: true,
                      willChange: false,
                    ),
                  ),
                ),
              ),
            ),
          if (settings.enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: settings.fineOpacity,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: GrainNoisePainter(),
                      isComplex: true,
                      willChange: false,
                    ),
                  ),
                ),
              ),
            ),
          // 중앙 텍스트
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  settings.enabled ? '양피지 텍스처 적용 중' : '텍스처 꺼짐',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  settings.enabled
                      ? '거친 질감 ${(settings.coarseOpacity * 100).round()}% · 미세 질감 ${(settings.fineOpacity * 100).round()}%'
                      : '아래에서 텍스처를 켜보세요',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ParchmentTheme.fadedScript,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard(
      TextureSettings settings, TextureSettingsNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SwitchListTile(
          title: const Text(
            '양피지 텍스처',
            style: TextStyle(
              color: ParchmentTheme.ancientInk,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: const Text(
            '배경에 양피지 질감 효과를 적용합니다',
            style: TextStyle(
              color: ParchmentTheme.fadedScript,
              fontSize: 12,
            ),
          ),
          value: settings.enabled,
          onChanged: (value) => notifier.setEnabled(value),
          activeColor: _accentColor,
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.brown.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.layers, color: Colors.brown, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderCard(
      TextureSettings settings, TextureSettingsNotifier notifier) {
    return AnimatedOpacity(
      opacity: settings.enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
          boxShadow: ParchmentTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 거친 질감 (Perlin 노이즈)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.grain, color: Colors.orange, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '거친 질감',
                    style: TextStyle(
                      color: ParchmentTheme.ancientInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${(settings.coarseOpacity * 100).round()}%',
                  style: const TextStyle(
                    color: ParchmentTheme.fadedScript,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Slider(
              value: settings.coarseOpacity,
              min: 0.0,
              max: 0.3,
              divisions: 30,
              activeColor: _accentColor,
              inactiveColor: ParchmentTheme.warmVellum,
              onChanged: settings.enabled
                  ? (value) => notifier.setCoarseOpacity(value)
                  : null,
            ),
            const SizedBox(height: 8),
            const Divider(color: ParchmentTheme.warmVellum),
            const SizedBox(height: 8),

            // 미세 질감 (그레인 노이즈)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.blur_on,
                      color: Colors.amber, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '미세 질감',
                    style: TextStyle(
                      color: ParchmentTheme.ancientInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${(settings.fineOpacity * 100).round()}%',
                  style: const TextStyle(
                    color: ParchmentTheme.fadedScript,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Slider(
              value: settings.fineOpacity,
              min: 0.0,
              max: 0.2,
              divisions: 20,
              activeColor: _accentColor,
              inactiveColor: ParchmentTheme.warmVellum,
              onChanged: settings.enabled
                  ? (value) => notifier.setFineOpacity(value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(
      BuildContext context, TextureSettingsNotifier notifier) {
    return Semantics(
      button: true,
      label: '텍스처 설정 초기화',
      child: TextButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: _cardColor,
              title: const Text(
                '설정 초기화',
                style: TextStyle(color: ParchmentTheme.ancientInk),
              ),
              content: const Text(
                '텍스처 설정을 기본값으로 되돌리시겠습니까?',
                style: TextStyle(color: ParchmentTheme.fadedScript),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: ParchmentTheme.softPapyrus,
                  ),
                  child: const Text('초기화'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            notifier.reset();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('텍스처 설정이 초기화되었습니다'),
                  backgroundColor: ParchmentTheme.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        },
        icon: const Icon(
          Icons.refresh,
          color: ParchmentTheme.fadedScript,
          size: 18,
        ),
        label: const Text(
          '기본 설정으로 되돌리기',
          style: TextStyle(
            color: ParchmentTheme.fadedScript,
          ),
        ),
      ),
    );
  }
}
