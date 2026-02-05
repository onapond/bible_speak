import 'package:flutter/material.dart';
import '../../models/shop_item.dart';
import '../../services/shop_service.dart';
import '../../styles/parchment_theme.dart';

/// 인벤토리 화면
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final ShopService _shopService = ShopService();

  List<InventoryItem> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    _inventory = await _shopService.getInventory();
    setState(() => _isLoading = false);
  }

  Future<void> _activateItem(InventoryItem item) async {
    final success = await _shopService.activateItem(item.itemId, item.category);
    if (success) {
      await _loadInventory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.itemName}이(가) 활성화되었습니다'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _useItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${item.emoji} ${item.itemName}',
          style: const TextStyle(color: ParchmentTheme.ancientInk),
        ),
        content: const Text(
          '이 아이템을 사용하시겠습니까?',
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
            child: const Text('사용'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _shopService.useItem(item.itemId);
      if (success) {
        await _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.itemName}을(를) 사용했습니다'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
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
                        '내 아이템',
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _accentColor))
                    : _inventory.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadInventory,
                            color: _accentColor,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                // 카테고리별로 그룹화
                                for (final category in ShopCategory.values) ...[
                                  _buildCategorySection(category),
                                ],
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: ParchmentTheme.warmVellum,
          ),
          const SizedBox(height: 16),
          const Text(
            '보유한 아이템이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: ParchmentTheme.fadedScript,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '샵에서 아이템을 구매해보세요!',
            style: TextStyle(
              fontSize: 14,
              color: ParchmentTheme.weatheredGray,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: ParchmentTheme.buttonShadow,
            ),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_bag),
              label: const Text('샵으로 이동'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: ParchmentTheme.softPapyrus,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(ShopCategory category) {
    final categoryItems = _inventory.where((i) => i.category == category).toList();
    if (categoryItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                category.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${categoryItems.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...categoryItems.map((item) => _buildInventoryItem(item, category)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInventoryItem(InventoryItem item, ShopCategory category) {
    final isConsumable = category == ShopCategory.booster || category == ShopCategory.protection;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isActive
              ? _accentColor.withValues(alpha: 0.5)
              : _accentColor.withValues(alpha: 0.2),
          width: item.isActive ? 2 : 1,
        ),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          // 이모지
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                item.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.itemName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                    ),
                    if (item.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '사용 중',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ParchmentTheme.softPapyrus,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (isConsumable)
                  Text(
                    '수량: ${item.quantity}개',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ParchmentTheme.fadedScript,
                    ),
                  )
                else
                  Text(
                    category.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ParchmentTheme.fadedScript,
                    ),
                  ),
              ],
            ),
          ),

          // 액션 버튼
          if (!item.isActive)
            TextButton(
              onPressed: isConsumable ? () => _useItem(item) : () => _activateItem(item),
              style: TextButton.styleFrom(
                backgroundColor: _accentColor.withValues(alpha: 0.15),
                foregroundColor: _accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isConsumable ? '사용' : '적용',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
