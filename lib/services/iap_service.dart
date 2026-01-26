import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';

/// 인앱 결제 서비스
/// - iOS/Android 구독 관리
/// - Firestore 구독 상태 동기화
/// - 로컬 캐시로 오프라인 지원
class IAPService {
  static const String _localSubscriptionKey = 'bible_speak_subscription';
  static const String _dailyCountKey = 'bible_speak_daily_count';
  static const String _dailyDateKey = 'bible_speak_daily_date';

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SharedPreferences? _prefs;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // 상품 정보 캐시
  final Map<String, ProductDetails> _products = {};

  // 현재 구독 상태
  UserSubscription _currentSubscription = UserSubscription.free();
  UserSubscription get currentSubscription => _currentSubscription;

  // 구독 상태 스트림
  final _subscriptionController = StreamController<UserSubscription>.broadcast();
  Stream<UserSubscription> get subscriptionStream => _subscriptionController.stream;

  // 구매 진행 중 여부
  bool _isPurchasing = false;
  bool get isPurchasing => _isPurchasing;

  // 오류 메시지
  String? _lastError;
  String? get lastError => _lastError;

  /// 초기화
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // 스토어 가용성 확인
    final available = await _iap.isAvailable();
    if (!available) {
      _lastError = '인앱 결제를 사용할 수 없습니다.';
      return;
    }

    // 구매 이벤트 리스닝
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        _lastError = '결제 오류: $error';
      },
    );

    // 상품 정보 로드
    await _loadProducts();

    // 현재 구독 상태 로드
    await _loadSubscriptionStatus();

    // 보류 중인 구매 확인
    await _restorePurchases();
  }

  /// 상품 정보 로드
  Future<void> _loadProducts() async {
    final productIds = <String>{
      SubscriptionPlan.monthly.productId,
      SubscriptionPlan.yearly.productId,
    };

    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      _lastError = '상품 정보 로드 실패: ${response.error!.message}';
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      // 개발 환경에서는 정상적일 수 있음
    }

    for (final product in response.productDetails) {
      _products[product.id] = product;
    }
  }

  /// 구독 상태 로드
  Future<void> _loadSubscriptionStatus() async {
    // Firestore에서 로드 시도
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('subscription')
            .doc('current')
            .get();

        if (doc.exists && doc.data() != null) {
          _currentSubscription = UserSubscription.fromMap(doc.data()!);
          _subscriptionController.add(_currentSubscription);
          await _saveToLocal(_currentSubscription);
          return;
        }
      } catch (e) {
        // Firestore 오류 시 로컬에서 로드
      }
    }

    // 로컬에서 로드
    await _loadFromLocal();
  }

  /// 로컬에서 구독 상태 로드
  Future<void> _loadFromLocal() async {
    if (_prefs == null) return;

    final json = _prefs!.getString(_localSubscriptionKey);
    if (json != null) {
      try {
        // 간단한 파싱 (실제로는 JSON 사용 권장)
        final parts = json.split('|');
        if (parts.length >= 3) {
          final plan = SubscriptionPlan.fromProductId(parts[0]) ?? SubscriptionPlan.free;
          final expiryDate = DateTime.tryParse(parts[1]);
          final isActive = parts[2] == 'true';

          _currentSubscription = UserSubscription(
            plan: plan,
            expiryDate: expiryDate,
            isActive: isActive && (expiryDate?.isAfter(DateTime.now()) ?? false),
          );
          _subscriptionController.add(_currentSubscription);
        }
      } catch (e) {
        // 파싱 오류 시 무료 플랜으로
      }
    }
  }

  /// 로컬에 구독 상태 저장
  Future<void> _saveToLocal(UserSubscription subscription) async {
    if (_prefs == null) return;

    final json = '${subscription.plan.productId}|'
        '${subscription.expiryDate?.toIso8601String() ?? ''}|'
        '${subscription.isActive}';

    await _prefs!.setString(_localSubscriptionKey, json);
  }

  /// 상품 정보 가져오기
  ProductDetails? getProduct(SubscriptionPlan plan) {
    return _products[plan.productId];
  }

  /// 모든 상품 목록
  List<ProductDetails> get allProducts => _products.values.toList();

  /// 구매 시작
  Future<bool> purchase(SubscriptionPlan plan) async {
    if (_isPurchasing) {
      _lastError = '이미 결제가 진행 중입니다.';
      return false;
    }

    final product = _products[plan.productId];
    if (product == null) {
      _lastError = '상품 정보를 찾을 수 없습니다.';
      return false;
    }

    _isPurchasing = true;
    _lastError = null;

    try {
      final purchaseParam = PurchaseParam(productDetails: product);

      // 구독 상품 구매
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        _isPurchasing = false;
        _lastError = '결제를 시작할 수 없습니다.';
        return false;
      }

      return true;
    } catch (e) {
      _isPurchasing = false;
      _lastError = '결제 오류: $e';
      return false;
    }
  }

  /// 구매 복원
  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _lastError = '구매 복원 실패: $e';
    }
  }

  /// 구매 복원 (사용자 요청)
  Future<bool> restorePurchases() async {
    _lastError = null;

    try {
      await _iap.restorePurchases();
      return true;
    } catch (e) {
      _lastError = '구매 복원 실패: $e';
      return false;
    }
  }

  /// 구매 이벤트 처리
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
  }

  /// 개별 구매 처리
  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        // 결제 대기 중
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // 결제 완료 또는 복원
        await _verifyAndActivate(purchase);
        break;

      case PurchaseStatus.error:
        _isPurchasing = false;
        _lastError = purchase.error?.message ?? '결제 오류가 발생했습니다.';
        break;

      case PurchaseStatus.canceled:
        _isPurchasing = false;
        _lastError = '결제가 취소되었습니다.';
        break;
    }

    // 구매 완료 처리
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  /// 구매 검증 및 활성화
  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    _isPurchasing = false;

    // 상품 ID에서 플랜 확인
    final plan = SubscriptionPlan.fromProductId(purchase.productID);
    if (plan == null || plan == SubscriptionPlan.free) {
      _lastError = '알 수 없는 상품입니다.';
      return;
    }

    // 만료일 계산
    final now = DateTime.now();
    final expiryDate = plan == SubscriptionPlan.yearly
        ? now.add(const Duration(days: 365))
        : now.add(const Duration(days: 30));

    // 구독 상태 업데이트
    _currentSubscription = UserSubscription(
      plan: plan,
      expiryDate: expiryDate,
      originalTransactionId: _getTransactionId(purchase),
      isActive: true,
    );

    _subscriptionController.add(_currentSubscription);

    // Firestore에 저장
    await _saveToFirestore(_currentSubscription);

    // 로컬에 저장
    await _saveToLocal(_currentSubscription);
  }

  /// 트랜잭션 ID 추출
  String? _getTransactionId(PurchaseDetails purchase) {
    if (Platform.isIOS) {
      return purchase.purchaseID;
    } else if (Platform.isAndroid) {
      return purchase.purchaseID;
    }
    return null;
  }

  /// Firestore에 저장
  Future<void> _saveToFirestore(UserSubscription subscription) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc('current')
          .set(subscription.toMap());

      // 사용자 문서에도 프리미엄 상태 저장 (빠른 조회용)
      await _firestore.collection('users').doc(userId).set({
        'isPremium': subscription.isPremium,
        'subscriptionExpiry': subscription.expiryDate?.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Firestore 저장 실패 시 로컬에만 저장됨
    }
  }

  /// 프리미엄 여부 확인
  bool get isPremium => _currentSubscription.isPremium;

  /// 오늘 학습한 구절 수 확인
  Future<int> getTodayLearnedCount() async {
    if (_prefs == null) await init();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = _prefs!.getString(_dailyDateKey);

    if (savedDate != today) {
      // 날짜가 다르면 카운트 리셋
      await _prefs!.setString(_dailyDateKey, today);
      await _prefs!.setInt(_dailyCountKey, 0);
      return 0;
    }

    return _prefs!.getInt(_dailyCountKey) ?? 0;
  }

  /// 오늘 학습 카운트 증가
  Future<int> incrementTodayCount() async {
    if (_prefs == null) await init();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = _prefs!.getString(_dailyDateKey);

    int count;
    if (savedDate != today) {
      await _prefs!.setString(_dailyDateKey, today);
      count = 1;
    } else {
      count = (_prefs!.getInt(_dailyCountKey) ?? 0) + 1;
    }

    await _prefs!.setInt(_dailyCountKey, count);
    return count;
  }

  /// 학습 가능 여부 확인
  Future<bool> canLearnVerse(String bookId, int chapter) async {
    // 프리미엄 사용자는 무제한
    if (isPremium) return true;

    // 무료 콘텐츠 확인
    if (FreeTierLimits.isChapterFree(bookId, chapter)) {
      // 일일 제한 확인
      final count = await getTodayLearnedCount();
      return count < FreeTierLimits.dailyVerseLimit;
    }

    // 유료 콘텐츠는 프리미엄만
    return false;
  }

  /// 남은 무료 학습 횟수
  Future<int> getRemainingFreeCount() async {
    if (isPremium) return -1; // 무제한

    final count = await getTodayLearnedCount();
    return (FreeTierLimits.dailyVerseLimit - count).clamp(0, FreeTierLimits.dailyVerseLimit);
  }

  /// 리소스 해제
  void dispose() {
    _purchaseSubscription?.cancel();
    _subscriptionController.close();
  }
}
