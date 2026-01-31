import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shop_item.dart';

/// 탈란트 샵 서비스
class ShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 사용자 달란트 조회
  // ============================================================

  /// 사용자 달란트 가져오기 (Firestore 직접 조회)
  Future<int> getUserTalants() async {
    final userId = currentUserId;
    if (userId == null) return 0;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['talants'] ?? 0;
    } catch (e) {
      print('Get user talants error: $e');
      return 0;
    }
  }

  // ============================================================
  // 샵 아이템 조회
  // ============================================================

  /// 모든 샵 아이템 가져오기
  Future<List<ShopItem>> getShopItems() async {
    try {
      final snapshot = await _firestore
          .collection('shopItems')
          .where('isActive', isEqualTo: true)
          .orderBy('category')
          .orderBy('price')
          .get();

      if (snapshot.docs.isEmpty) {
        // 기본 아이템 반환
        return ShopItem.defaultItems;
      }

      return snapshot.docs
          .map((doc) => ShopItem.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Get shop items error: $e');
      // Firestore 쿼리 실패 시 기본 아이템 반환
      return ShopItem.defaultItems;
    }
  }

  /// 카테고리별 아이템 가져오기
  Future<List<ShopItem>> getItemsByCategory(ShopCategory category) async {
    final items = await getShopItems();
    return items.where((item) => item.category == category).toList();
  }

  /// 특정 아이템 가져오기
  Future<ShopItem?> getItem(String itemId) async {
    try {
      final doc = await _firestore.collection('shopItems').doc(itemId).get();
      if (doc.exists) {
        return ShopItem.fromFirestore(doc.id, doc.data()!);
      }
      // 기본 아이템에서 찾기
      return ShopItem.defaultItems.cast<ShopItem?>().firstWhere(
        (item) => item?.id == itemId,
        orElse: () => null,
      );
    } catch (e) {
      print('Get item error: $e');
      return null;
    }
  }

  // ============================================================
  // 구매
  // ============================================================

  /// 아이템 구매
  Future<PurchaseResult> purchaseItem(String itemId) async {
    final userId = currentUserId;
    if (userId == null) {
      return PurchaseResult(success: false, message: '로그인이 필요합니다');
    }

    try {
      // 아이템 정보 가져오기
      final item = await getItem(itemId);
      if (item == null) {
        return PurchaseResult(success: false, message: '아이템을 찾을 수 없습니다');
      }

      if (!item.canPurchase) {
        return PurchaseResult(success: false, message: '구매할 수 없는 아이템입니다');
      }

      // 이미 보유 중인지 확인 (테마, 뱃지)
      if (item.category == ShopCategory.theme || item.category == ShopCategory.badge) {
        final hasItem = await hasInventoryItem(itemId);
        if (hasItem) {
          return PurchaseResult(success: false, message: '이미 보유한 아이템입니다');
        }
      }

      // 트랜잭션으로 구매 처리
      return await _firestore.runTransaction<PurchaseResult>((transaction) async {
        // 사용자 탈란트 확인
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          return PurchaseResult(success: false, message: '사용자 정보를 찾을 수 없습니다');
        }

        final currentTalants = userDoc.data()?['talants'] ?? 0;
        if (currentTalants < item.price) {
          return PurchaseResult(
            success: false,
            message: '탈란트가 부족합니다 (보유: $currentTalants, 필요: ${item.price})',
          );
        }

        // 탈란트 차감 (set + merge로 필드 없어도 안전)
        transaction.set(userRef, {
          'talants': FieldValue.increment(-item.price),
        }, SetOptions(merge: true));

        // 인벤토리에 추가
        final inventoryRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('inventory')
            .doc(itemId);

        final inventoryDoc = await transaction.get(inventoryRef);

        if (inventoryDoc.exists) {
          // 소모품의 경우 수량 증가 (set + merge로 안전)
          transaction.set(inventoryRef, {
            'quantity': FieldValue.increment(1),
            'lastPurchasedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          // 새 아이템 추가
          transaction.set(inventoryRef, {
            'itemId': item.id,
            'itemName': item.name,
            'emoji': item.emoji,
            'category': item.category.id,
            'purchasedAt': FieldValue.serverTimestamp(),
            'isActive': false,
            'quantity': 1,
          });
        }

        // 재고 감소 (한정 아이템의 경우, set + merge로 안전)
        if (item.isLimited && item.stock != null) {
          final itemRef = _firestore.collection('shopItems').doc(itemId);
          transaction.set(itemRef, {
            'stock': FieldValue.increment(-1),
          }, SetOptions(merge: true));
        }

        // 구매 기록 저장
        final purchaseRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('purchases')
            .doc();

        transaction.set(purchaseRef, {
          'itemId': item.id,
          'itemName': item.name,
          'price': item.price,
          'purchasedAt': FieldValue.serverTimestamp(),
        });

        return PurchaseResult(
          success: true,
          message: '${item.name}을(를) 구매했습니다!',
          item: item,
        );
      });
    } catch (e) {
      print('Purchase error: $e');
      return PurchaseResult(success: false, message: '구매 중 오류가 발생했습니다');
    }
  }

  // ============================================================
  // 인벤토리
  // ============================================================

  /// 인벤토리 가져오기
  Future<List<InventoryItem>> getInventory() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .orderBy('purchasedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => InventoryItem.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Get inventory error: $e');
      return [];
    }
  }

  /// 카테고리별 인벤토리
  Future<List<InventoryItem>> getInventoryByCategory(ShopCategory category) async {
    final inventory = await getInventory();
    return inventory.where((item) => item.category == category).toList();
  }

  /// 아이템 보유 여부 확인
  Future<bool> hasInventoryItem(String itemId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(itemId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// 아이템 활성화 (테마, 뱃지)
  Future<bool> activateItem(String itemId, ShopCategory category) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      // 같은 카테고리의 다른 아이템 비활성화
      final inventorySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .where('category', isEqualTo: category.id)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final doc in inventorySnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // 선택한 아이템 활성화
      final itemRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(itemId);

      batch.update(itemRef, {'isActive': true});

      await batch.commit();
      return true;
    } catch (e) {
      print('Activate item error: $e');
      return false;
    }
  }

  /// 소모품 아이템 사용
  Future<bool> useItem(String itemId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final itemRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(itemId);

      final doc = await itemRef.get();
      if (!doc.exists) return false;

      final quantity = doc.data()?['quantity'] ?? 0;
      if (quantity <= 0) return false;

      if (quantity == 1) {
        // 마지막 하나면 삭제
        await itemRef.delete();
      } else {
        // 수량 감소
        await itemRef.update({
          'quantity': FieldValue.increment(-1),
          'usedAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      print('Use item error: $e');
      return false;
    }
  }

  /// 활성화된 테마 가져오기
  Future<InventoryItem?> getActiveTheme() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .where('category', isEqualTo: 'theme')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return InventoryItem.fromFirestore(snapshot.docs.first.data());
    } catch (e) {
      print('Get active theme error: $e');
      return null;
    }
  }

  /// 활성화된 뱃지 목록 가져오기
  Future<List<InventoryItem>> getActiveBadges() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .where('category', isEqualTo: 'badge')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => InventoryItem.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Get active badges error: $e');
      return [];
    }
  }
}

/// 구매 결과
class PurchaseResult {
  final bool success;
  final String message;
  final ShopItem? item;

  const PurchaseResult({
    required this.success,
    required this.message,
    this.item,
  });
}
