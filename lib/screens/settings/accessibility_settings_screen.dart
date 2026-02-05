import 'package:flutter/material.dart';
import '../../services/accessibility_service.dart';
import '../../styles/parchment_theme.dart';

/// 접근성 설정 화면
class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  final AccessibilityService _a11y = AccessibilityService();

  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  @override
  void initState() {
    super.initState();
    _a11y.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _a11y.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ParchmentTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
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
                        '접근성',
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
                    // 텍스트 크기 섹션
                    _buildSectionTitle('텍스트 크기'),
                    const SizedBox(height: 12),
                    _buildTextSizeCard(),
                    const SizedBox(height: 24),

                    // 시각 섹션
                    _buildSectionTitle('시각'),
                    const SizedBox(height: 12),
                    _buildVisualOptionsCard(),
                    const SizedBox(height: 24),

                    // 모션 섹션
                    _buildSectionTitle('모션'),
                    const SizedBox(height: 12),
                    _buildMotionOptionsCard(),
                    const SizedBox(height: 24),

                    // 터치 섹션
                    _buildSectionTitle('터치'),
                    const SizedBox(height: 12),
                    _buildTouchOptionsCard(),
                    const SizedBox(height: 24),

                    // 초기화 버튼
                    _buildResetButton(),
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

  Widget _buildTextSizeCard() {
    return Container(
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
          // 미리보기 텍스트
          Semantics(
            label: '텍스트 크기 미리보기',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '미리보기',
                    style: TextStyle(
                      fontSize: 12 * _a11y.textScaleFactor,
                      color: ParchmentTheme.weatheredGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '하나님이 세상을 이처럼 사랑하사',
                    style: TextStyle(
                      fontSize: 16 * _a11y.textScaleFactor,
                      color: ParchmentTheme.ancientInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For God so loved the world',
                    style: TextStyle(
                      fontSize: 14 * _a11y.textScaleFactor,
                      color: ParchmentTheme.fadedScript,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 텍스트 크기 옵션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: AccessibilityService.textScaleOptions.map((option) {
              final isSelected = (_a11y.textScaleFactor - option.value).abs() < 0.01;
              return _buildTextSizeOption(option, isSelected);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSizeOption(TextScaleOption option, bool isSelected) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '텍스트 크기 ${option.label}',
      child: InkWell(
        onTap: () => _a11y.setTextScaleFactor(option.value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? _accentColor.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _accentColor : ParchmentTheme.warmVellum,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: 16 * option.value,
                  color: isSelected ? _accentColor : ParchmentTheme.fadedScript,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? _accentColor : ParchmentTheme.weatheredGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.contrast,
            iconColor: Colors.amber,
            title: '고대비 모드',
            subtitle: '텍스트와 배경의 대비를 높입니다',
            value: _a11y.highContrastMode,
            onChanged: (value) => _a11y.setHighContrastMode(value),
          ),
        ],
      ),
    );
  }

  Widget _buildMotionOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.animation,
            iconColor: Colors.purple,
            title: '애니메이션 감소',
            subtitle: '화면 전환 및 효과 애니메이션을 줄입니다',
            value: _a11y.reduceMotion,
            onChanged: (value) => _a11y.setReduceMotion(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.touch_app,
            iconColor: Colors.teal,
            title: '큰 터치 영역',
            subtitle: '버튼과 터치 영역을 더 크게 만듭니다',
            value: _a11y.largerTapTargets,
            onChanged: (value) => _a11y.setLargerTapTargets(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: ParchmentTheme.ancientInk,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: ParchmentTheme.fadedScript,
            fontSize: 12,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: _accentColor,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return Semantics(
      button: true,
      label: '모든 접근성 설정 초기화',
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
                '모든 접근성 설정을 기본값으로 되돌리시겠습니까?',
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
            await _a11y.resetToDefaults();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('접근성 설정이 초기화되었습니다'),
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
