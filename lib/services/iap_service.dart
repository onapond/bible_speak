import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/subscription.dart';
import 'api/authenticated_api_client.dart';

/// 인앱 결제 서비스
/// - iOS/Android 구독 관리
/// - Firestore 구독 상태 동기화
/// - 로컬 캐시로 오프라인 지원
class IAPService {
  static final IAPService _instance = IAPService._internal();

  factory IAPService() => _instance;

  IAPService._internal();

  static const String _localSubscriptionKey = 'bible_speak_subscription';
  static const String _dailyCountKey = 'bible_speak_daily_count';
  static const String _dailyDateKey = 'bible_speak_daily_date';

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SharedPreferences? _prefs;
  Future<void>? _initialization;
  bool _isInitialized = false;
  String? _loadedUserId;

  // 상품 정보 캐시
  final Map<String, ProductDetails> _products = {};

  // 현재 구독 상태
  UserSubscription _currentSubscription = UserSubscription.free();
  UserSubscription get currentSubscription => _currentSubscription;

  // 구독 상태 스트림
  final _subscriptionController =
      StreamController<UserSubscription>.broadcast();
  Stream<UserSubscription> get subscriptionStream =>
      _subscriptionController.stream;

  // 구매 진행 중 여부
  bool _isPurchasing = false;
  bool get isPurchasing => _isPurchasing;

  // 오류 메시지
  String? _lastError;
  String? get lastError => _lastError;

  /// 초기화
  Future<void> init() async {
    final userId = _auth.currentUser?.uid;
    if (_isInitialized) {
      if (_loadedUserId != userId) {
        await _loadSubscriptionStatus();
      }
      return;
    }

    if (_initialization != null) {
      await _initialization;
      return;
    }

    _initialization = _initialize();
    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();

    // 스토어를 사용할 수 없는 플랫폼에서도 서버 구독 상태는 반영한다.
    await _loadSubscriptionStatus();

    // 스토어 가용성 확인
    final available = await _iap.isAvailable();
    if (!available) {
      _lastError = '인앱 결제를 사용할 수 없습니다.';
      _isInitialized = true;
      return;
    }

    // 구매 이벤트 리스닝
    _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        _lastError = '결제 오류: $error';
      },
    );

    // 상품 정보 로드
    await _loadProducts();

    _isInitialized = true;
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
    _currentSubscription = UserSubscription.free();

    // Firestore에서 로드 시도
    final userId = _auth.currentUser?.uid;
    _loadedUserId = userId;
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

    final json = _prefs!.getString(_scopedKey(_localSubscriptionKey));
    if (json != null) {
      try {
        // 간단한 파싱 (실제로는 JSON 사용 권장)
        final parts = json.split('|');
        if (parts.length >= 3) {
          final plan =
              SubscriptionPlan.fromProductId(parts[0]) ?? SubscriptionPlan.free;
          final expiryDate = DateTime.tryParse(parts[1]);
          final isActive = parts[2] == 'true';

          _currentSubscription = UserSubscription(
            plan: plan,
            expiryDate: expiryDate,
            isActive:
                isActive && (expiryDate?.isAfter(DateTime.now()) ?? false),
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

    await _prefs!.setString(_scopedKey(_localSubscriptionKey), json);
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
    if (_auth.currentUser == null) {
      _lastError = '결제하려면 먼저 로그인해주세요.';
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
      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: _accountToken(_auth.currentUser!.uid),
      );

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

  /// 구매 복원 (사용자 요청)
  Future<bool> restorePurchases() async {
    _lastError = null;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _lastError = '구매를 복원하려면 먼저 로그인해주세요.';
        return false;
      }
      await _iap.restorePurchases(
        applicationUserName: _accountToken(user.uid),
      );
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
    var shouldCompletePurchase = false;
    switch (purchase.status) {
      case PurchaseStatus.pending:
        // 결제 대기 중
        break;

      case PurchaseStatus.purchased:
        shouldCompletePurchase = await _verifyAndActivate(purchase);
        break;

      case PurchaseStatus.restored:
        shouldCompletePurchase = await _verifyAndActivate(purchase);
        break;

      case PurchaseStatus.error:
        _isPurchasing = false;
        _lastError = purchase.error?.message ?? '결제 오류가 발생했습니다.';
        shouldCompletePurchase = true;
        break;

      case PurchaseStatus.canceled:
        _isPurchasing = false;
        _lastError = '결제가 취소되었습니다.';
        shouldCompletePurchase = true;
        break;
    }

    // 서버 검증이 실패한 구매는 완료 처리하지 않는다. 네트워크나 스토어
    // 장애가 해소되면 purchaseStream으로 다시 전달되어 검증할 수 있다.
    if (shouldCompletePurchase && purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  /// 서버에서 스토어 원본 데이터를 검증한 뒤에만 구독을 활성화한다.
  Future<bool> _verifyAndActivate(PurchaseDetails purchase) async {
    final plan = SubscriptionPlan.fromProductId(purchase.productID);
    if (plan == null || plan == SubscriptionPlan.free) {
      _isPurchasing = false;
      _lastError = '알 수 없는 상품입니다.';
      return false;
    }

    try {
      final verificationData = purchase.verificationData.serverVerificationData;
      if (verificationData.isEmpty) {
        _lastError = '스토어 검증 정보를 찾을 수 없습니다.';
        return false;
      }

      final response = await AuthenticatedApiClient.postJson(
        Uri.parse(AppConfig.verifySubscriptionPurchaseUrl),
        {
          'source': purchase.verificationData.source,
          'productId': purchase.productID,
          'verificationData': verificationData,
          'purchaseId': purchase.purchaseID,
        },
      );
      final payload = jsonDecode(response.body);
      if (response.statusCode != 200 || payload is! Map<String, dynamic>) {
        _lastError = response.statusCode == 409
            ? '이 구매는 다른 계정에 연결되어 있습니다.'
            : '스토어 구매 검증에 실패했습니다. 잠시 후 다시 시도해주세요.';
        return false;
      }

      final subscriptionMap = payload['subscription'];
      if (subscriptionMap is! Map<String, dynamic>) {
        _lastError = '서버의 구독 응답이 올바르지 않습니다.';
        return false;
      }

      final verifiedSubscription = UserSubscription.fromMap(subscriptionMap);
      if (!verifiedSubscription.isPremium ||
          verifiedSubscription.plan != plan) {
        _lastError = '검증된 활성 구독을 찾지 못했습니다.';
        return false;
      }

      _currentSubscription = verifiedSubscription;
      _subscriptionController.add(_currentSubscription);
      await _saveToLocal(_currentSubscription);
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = '구매 검증 중 연결 오류가 발생했습니다.';
      return false;
    } finally {
      _isPurchasing = false;
    }
  }

  /// 프리미엄 여부 확인
  bool get isPremium => _currentSubscription.isPremium;

  /// 오늘 학습한 구절 수 확인
  Future<int> getTodayLearnedCount() async {
    if (_prefs == null) await init();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = _prefs!.getString(_scopedKey(_dailyDateKey));

    if (savedDate != today) {
      // 날짜가 다르면 카운트 리셋
      await _prefs!.setString(_scopedKey(_dailyDateKey), today);
      await _prefs!.setInt(_scopedKey(_dailyCountKey), 0);
      return 0;
    }

    return _prefs!.getInt(_scopedKey(_dailyCountKey)) ?? 0;
  }

  /// 오늘 학습 카운트 증가
  Future<int> incrementTodayCount() async {
    if (_prefs == null) await init();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = _prefs!.getString(_scopedKey(_dailyDateKey));

    int count;
    if (savedDate != today) {
      await _prefs!.setString(_scopedKey(_dailyDateKey), today);
      count = 1;
    } else {
      count = (_prefs!.getInt(_scopedKey(_dailyCountKey)) ?? 0) + 1;
    }

    await _prefs!.setInt(_scopedKey(_dailyCountKey), count);
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
    return (FreeTierLimits.dailyVerseLimit - count)
        .clamp(0, FreeTierLimits.dailyVerseLimit);
  }

  String _scopedKey(String key) {
    return '${key}_${_auth.currentUser?.uid ?? 'guest'}';
  }

  /// 스토어에는 Firebase UID 원문 대신 결정적 UUID를 전달한다. 서버도 같은
  /// 값을 계산해 영수증이 현재 앱 계정에서 생성됐는지 확인한다.
  String _accountToken(String userId) {
    final bytes = sha256.convert(utf8.encode('bible-speak:iap:$userId')).bytes;
    final uuidBytes = bytes.take(16).toList();
    uuidBytes[6] = (uuidBytes[6] & 0x0f) | 0x50;
    uuidBytes[8] = (uuidBytes[8] & 0x3f) | 0x80;
    final hex =
        uuidBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// 리소스 해제
  void dispose() {
    // 앱 전역 싱글턴이므로 개별 화면에서는 해제하지 않는다.
  }
}
