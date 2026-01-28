/// 샵 아이템 카테고리
enum ShopCategory {
  theme('theme', '테마', '앱 테마를 변경합니다'),
  badge('badge', '뱃지', '프로필에 표시되는 뱃지'),
  booster('booster', '부스터', '학습 효과를 높입니다'),
  protection('protection', '보호', '스트릭을 보호합니다');

  final String id;
  final String label;
  final String description;

  const ShopCategory(this.id, this.label, this.description);

  static ShopCategory fromId(String id) {
    return ShopCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => ShopCategory.theme,
    );
  }
}

/// 샵 아이템 모델
class ShopItem {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final ShopCategory category;
  final int price;
  final bool isLimited;
  final int? stock;
  final bool isActive;
  final Map<String, dynamic>? properties;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.price,
    this.isLimited = false,
    this.stock,
    this.isActive = true,
    this.properties,
  });

  factory ShopItem.fromFirestore(String id, Map<String, dynamic> data) {
    return ShopItem(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      emoji: data['emoji'] ?? '🎁',
      category: ShopCategory.fromId(data['category'] ?? 'theme'),
      price: data['price'] ?? 0,
      isLimited: data['isLimited'] ?? false,
      stock: data['stock'],
      isActive: data['isActive'] ?? true,
      properties: data['properties'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'emoji': emoji,
      'category': category.id,
      'price': price,
      'isLimited': isLimited,
      'stock': stock,
      'isActive': isActive,
      'properties': properties,
    };
  }

  /// 구매 가능 여부
  bool get canPurchase => isActive && (stock == null || stock! > 0);

  /// 기본 아이템 목록 (초기 데이터)
  static const List<ShopItem> defaultItems = [
    // 테마
    ShopItem(
      id: 'theme_ocean',
      name: '오션 테마',
      description: '시원한 바다색 테마',
      emoji: '🌊',
      category: ShopCategory.theme,
      price: 50,
      properties: {'primaryColor': 0xFF0077B6, 'accentColor': 0xFF00B4D8},
    ),
    ShopItem(
      id: 'theme_sunset',
      name: '선셋 테마',
      description: '따뜻한 노을빛 테마',
      emoji: '🌅',
      category: ShopCategory.theme,
      price: 50,
      properties: {'primaryColor': 0xFFFF6B35, 'accentColor': 0xFFFFA500},
    ),
    ShopItem(
      id: 'theme_forest',
      name: '포레스트 테마',
      description: '평화로운 숲 테마',
      emoji: '🌲',
      category: ShopCategory.theme,
      price: 50,
      properties: {'primaryColor': 0xFF2D6A4F, 'accentColor': 0xFF52B788},
    ),
    ShopItem(
      id: 'theme_gold',
      name: '골드 테마',
      description: '고급스러운 금색 테마',
      emoji: '✨',
      category: ShopCategory.theme,
      price: 100,
      properties: {'primaryColor': 0xFFD4AF37, 'accentColor': 0xFFFFD700},
    ),

    // 뱃지
    ShopItem(
      id: 'badge_early_bird',
      name: '얼리버드',
      description: '아침 6시 전에 학습 완료',
      emoji: '🐦',
      category: ShopCategory.badge,
      price: 30,
    ),
    ShopItem(
      id: 'badge_night_owl',
      name: '올빼미',
      description: '자정 후에 학습',
      emoji: '🦉',
      category: ShopCategory.badge,
      price: 30,
    ),
    ShopItem(
      id: 'badge_perfectionist',
      name: '완벽주의자',
      description: '퀴즈 만점 10회 달성',
      emoji: '💯',
      category: ShopCategory.badge,
      price: 50,
    ),
    ShopItem(
      id: 'badge_helper',
      name: '도우미',
      description: '10명에게 격려 보내기',
      emoji: '🤝',
      category: ShopCategory.badge,
      price: 40,
    ),

    // 부스터
    ShopItem(
      id: 'booster_double_xp',
      name: '더블 탈란트',
      description: '24시간 동안 탈란트 2배',
      emoji: '⚡',
      category: ShopCategory.booster,
      price: 30,
      properties: {'duration': 24, 'multiplier': 2},
    ),
    ShopItem(
      id: 'booster_hint',
      name: '힌트 패키지',
      description: '퀴즈 힌트 5회',
      emoji: '💡',
      category: ShopCategory.booster,
      price: 20,
      properties: {'hints': 5},
    ),

    // 스트릭 보호
    ShopItem(
      id: 'protection_freeze',
      name: '스트릭 프리즈',
      description: '하루 학습 면제 (스트릭 유지)',
      emoji: '🧊',
      category: ShopCategory.protection,
      price: 50,
    ),
    ShopItem(
      id: 'protection_restore',
      name: '스트릭 복구',
      description: '끊어진 스트릭 복구',
      emoji: '🔄',
      category: ShopCategory.protection,
      price: 100,
      isLimited: true,
      stock: 1,
    ),
  ];
}

/// 사용자 인벤토리 아이템
class InventoryItem {
  final String itemId;
  final String itemName;
  final String emoji;
  final ShopCategory category;
  final DateTime purchasedAt;
  final DateTime? usedAt;
  final bool isActive;
  final int quantity;

  const InventoryItem({
    required this.itemId,
    required this.itemName,
    required this.emoji,
    required this.category,
    required this.purchasedAt,
    this.usedAt,
    this.isActive = false,
    this.quantity = 1,
  });

  factory InventoryItem.fromFirestore(Map<String, dynamic> data) {
    return InventoryItem(
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      emoji: data['emoji'] ?? '🎁',
      category: ShopCategory.fromId(data['category'] ?? 'theme'),
      purchasedAt: data['purchasedAt']?.toDate() ?? DateTime.now(),
      usedAt: data['usedAt']?.toDate(),
      isActive: data['isActive'] ?? false,
      quantity: data['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'emoji': emoji,
      'category': category.id,
      'purchasedAt': purchasedAt,
      'usedAt': usedAt,
      'isActive': isActive,
      'quantity': quantity,
    };
  }

  bool get isUsed => usedAt != null;
}
