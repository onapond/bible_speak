import 'package:flutter/material.dart';
import '../../models/shop_item.dart';
import '../../services/shop_service.dart';
import '../../services/auth_service.dart';

/// 탈란트 샵 화면
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final ShopService _shopService = ShopService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  List<ShopItem> _items = [];
  List<InventoryItem> _inventory = [];
  int _userTalants = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: ShopCategory.values.length + 1, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _items = await _shopService.getShopItems();
      _inventory = await _shopService.getInventory();
      _userTalants = await _shopService.getUserTalants(); // Firestore 직접 조회
    } catch (e) {
      print('Load shop data error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _purchaseItem(ShopItem item) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _PurchaseConfirmDialog(
        item: item,
        userTalants: _userTalants,
      ),
    );

    if (confirmed != true) return;

    // 구매 진행
    final result = await _shopService.purchaseItem(item.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (result.success) {
      await _loadData();
    }
  }

  bool _hasItem(String itemId) {
    return _inventory.any((inv) => inv.itemId == itemId);
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
          '탈란트 샵',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // 탈란트 잔액
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.toll, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$_userTalants',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: _accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            const Tab(text: '전체'),
            ...ShopCategory.values.map((c) => Tab(text: c.label)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildItemGrid(null),
                ...ShopCategory.values.map((c) => _buildItemGrid(c)),
              ],
            ),
    );
  }

  Widget _buildItemGrid(ShopCategory? category) {
    final filteredItems = category == null
        ? _items
        : _items.where((item) => item.category == category).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              '아이템이 없습니다',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _accentColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filteredItems.length,
        itemBuilder: (context, index) {
          final item = filteredItems[index];
          final owned = _hasItem(item.id);

          return _ShopItemCard(
            item: item,
            owned: owned,
            canAfford: _userTalants >= item.price,
            onTap: owned ? null : () => _purchaseItem(item),
          );
        },
      ),
    );
  }
}

/// 샵 아이템 카드
class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final bool owned;
  final bool canAfford;
  final VoidCallback? onTap;

  const _ShopItemCard({
    required this.item,
    required this.owned,
    required this.canAfford,
    this.onTap,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: owned
                  ? Colors.green.withValues(alpha: 0.3)
                  : _accentColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이모지 + 카테고리
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  if (owned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '보유',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    )
                  else if (item.isLimited)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '한정 ${item.stock ?? 0}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 이름
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // 설명
              Expanded(
                child: Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 가격
              const SizedBox(height: 8),
              if (!owned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: canAfford
                        ? _accentColor.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.toll,
                        size: 16,
                        color: canAfford ? Colors.amber : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.price}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: canAfford ? Colors.white : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 구매 확인 다이얼로그
class _PurchaseConfirmDialog extends StatelessWidget {
  final ShopItem item;
  final int userTalants;

  const _PurchaseConfirmDialog({
    required this.item,
    required this.userTalants,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    final canAfford = userTalants >= item.price;

    return Dialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이템 이모지
            Text(item.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),

            // 아이템 이름
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // 설명
            Text(
              item.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 가격 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '가격',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.toll, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${item.price}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '보유 탈란트',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      Text(
                        '$userTalants',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: canAfford ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (canAfford) ...[
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '구매 후 잔액',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        Text(
                          '${userTalants - item.price}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canAfford ? () => Navigator.pop(context, true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? _accentColor : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      canAfford ? '구매하기' : '탈란트 부족',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
