import 'package:flutter/material.dart';
import '../../models/shop_item.dart';
import '../../services/shop_service.dart';
import '../../services/theme_service.dart';

/// 테마 설정 화면
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final ShopService _shopService = ShopService();
  final ThemeService _themeService = ThemeService();

  List<InventoryItem> _ownedThemes = [];
  AppTheme _currentTheme = AppTheme.defaultTheme;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _themeService.loadActiveTheme();
    final inventory = await _shopService.getInventoryByCategory(ShopCategory.theme);

    setState(() {
      _ownedThemes = inventory;
      _currentTheme = _themeService.currentTheme;
      _isLoading = false;
    });
  }

  Future<void> _applyTheme(String themeId) async {
    final success = await _themeService.applyTheme(themeId);

    if (success && mounted) {
      setState(() => _currentTheme = _themeService.currentTheme);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('테마가 적용되었습니다'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    final success = await _themeService.resetToDefault();

    if (success && mounted) {
      setState(() => _currentTheme = AppTheme.defaultTheme);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('기본 테마로 변경되었습니다'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '테마 설정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _accentColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 현재 테마
                  _buildCurrentThemeCard(),
                  const SizedBox(height: 24),

                  // 보유 테마 목록
                  _buildSectionTitle('보유한 테마'),
                  const SizedBox(height: 12),

                  // 기본 테마
                  _buildThemeCard(
                    theme: AppTheme.defaultTheme,
                    isOwned: true,
                    isActive: _currentTheme.id == 'default',
                    onTap: () => _resetToDefault(),
                  ),
                  const SizedBox(height: 12),

                  // 구매한 테마
                  if (_ownedThemes.isEmpty)
                    _buildEmptyState()
                  else
                    ..._ownedThemes.map((item) {
                      final theme = ThemeService.availableThemes.firstWhere(
                        (t) => t.id == item.itemId,
                        orElse: () => AppTheme(
                          id: item.itemId,
                          name: item.itemName,
                          emoji: item.emoji,
                          primaryColor: _accentColor,
                          accentColor: _accentColor,
                          bgColor: _bgColor,
                          cardColor: _cardColor,
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildThemeCard(
                          theme: theme,
                          isOwned: true,
                          isActive: _currentTheme.id == item.itemId,
                          onTap: () => _applyTheme(item.itemId),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // 미보유 테마 목록 (샵 유도)
                  _buildSectionTitle('미보유 테마'),
                  const SizedBox(height: 12),

                  ...ThemeService.availableThemes
                      .where((t) =>
                          t.id != 'default' &&
                          !_ownedThemes.any((o) => o.itemId == t.id))
                      .map((theme) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildThemeCard(
                              theme: theme,
                              isOwned: false,
                              isActive: false,
                              onTap: () => _showPurchaseHint(theme),
                            ),
                          )),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentThemeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _currentTheme.primaryColor.withValues(alpha: 0.3),
            _currentTheme.accentColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _currentTheme.primaryColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _currentTheme.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '현재 테마',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      _currentTheme.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                '색상 미리보기',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 12),
              _buildColorPreview(_currentTheme.primaryColor),
              const SizedBox(width: 8),
              _buildColorPreview(_currentTheme.accentColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPreview(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildThemeCard({
    required AppTheme theme,
    required bool isOwned,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? theme.primaryColor
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // 이모지
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  theme.emoji,
                  style: TextStyle(
                    fontSize: 24,
                    color: isOwned ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOwned ? Colors.white : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildColorPreview(theme.primaryColor),
                      const SizedBox(width: 4),
                      _buildColorPreview(theme.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        isOwned ? (isActive ? '사용 중' : '탭하여 적용') : '미보유',
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive
                              ? theme.primaryColor
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 상태 표시
            if (isActive)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              )
            else if (!isOwned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '구매',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.palette_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '구매한 테마가 없습니다',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '샵에서 테마를 구매해보세요!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseHint(AppTheme theme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${theme.name}은(는) 샵에서 구매할 수 있습니다'),
        backgroundColor: Colors.amber.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: '샵으로',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pop(context); // 현재 화면 닫기
            // 샵으로 이동하는 로직은 부모에서 처리
          },
        ),
      ),
    );
  }
}
