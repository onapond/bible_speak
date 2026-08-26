import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';
import 'cache_service.dart';
import 'sync_queue_service.dart';

/// 오프라인 기능 통합 관리자
class OfflineManager extends ChangeNotifier {
  final ConnectivityService connectivity;
  final CacheService cache;
  final SyncQueueService syncQueue;

  bool _isInitialized = false;

  OfflineManager({
    required this.connectivity,
    required this.cache,
    required this.syncQueue,
  });

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 온라인 상태
  bool get isOnline => connectivity.isOnline;

  /// 오프라인 상태
  bool get isOffline => connectivity.isOffline;

  /// 대기 중인 동기화 작업 수
  int get pendingSyncCount => syncQueue.pendingCount;

  /// 초기화 (병렬 처리로 성능 최적화)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Future<void> initializeSafely(Future<void> operation) async {
        try {
          await operation.timeout(const Duration(seconds: 2));
        } catch (error) {
          print('⚠️ 일부 오프라인 서비스 초기화 실패: $error');
        }
      }

      // 연결 상태와 캐시를 먼저 준비한 뒤 연결 상태에 의존하는 큐를 연다.
      await Future.wait<void>([
        initializeSafely(connectivity.initialize()),
        initializeSafely(cache.initialize()),
      ]);
      await initializeSafely(syncQueue.initialize());

      // 연결 상태 변경 리스닝
      connectivity.addListener(_onConnectivityChanged);

      _isInitialized = true;
      print('✅ OfflineManager initialized');
    } catch (e) {
      print('⚠️ OfflineManager initialization error: $e');
      _isInitialized = true;
    }
  }

  void _onConnectivityChanged() {
    notifyListeners();

    if (connectivity.isOnline) {
      // 온라인 복귀 시 만료된 캐시 정리
      cache.cleanExpired();
    }
  }

  /// 데이터 캐싱 (TTL 포함)
  Future<void> cacheData<T>(
    String key,
    T data, {
    Duration ttl = const Duration(hours: 1),
    dynamic Function(T)? encoder,
  }) async {
    await cache.put(key, data, ttl: ttl, encoder: encoder);
  }

  /// 캐시된 데이터 조회
  T? getCached<T>(
    String key, {
    T Function(dynamic)? decoder,
  }) {
    return cache.get<T>(key, decoder: decoder);
  }

  /// 오프라인 작업 큐에 추가
  Future<void> queueAction(
    SyncActionType type,
    Map<String, dynamic> data,
  ) async {
    await syncQueue.enqueue(type, data);
    notifyListeners();
  }

  /// 강제 동기화
  Future<void> forceSync() async {
    if (connectivity.isOnline) {
      await syncQueue.forceSync();
      notifyListeners();
    }
  }

  /// 캐시 삭제
  Future<void> clearCache() async {
    await cache.clear();
  }

  @override
  void dispose() {
    connectivity.removeListener(_onConnectivityChanged);
    syncQueue.dispose();
    super.dispose();
  }
}

/// 싱글톤 인스턴스
late final OfflineManager offlineManager;

/// 앱 시작 경로와 테스트가 함께 사용하는 오프라인 관리자 생성 함수.
Future<OfflineManager> createAndInitializeOfflineManager({
  ConnectivityService? connectivity,
  CacheService? cache,
  SyncQueueService Function(ConnectivityService)? createSyncQueue,
}) async {
  final resolvedConnectivity = connectivity ?? ConnectivityService();
  final resolvedCache = cache ?? CacheService();
  final resolvedSyncQueue = createSyncQueue?.call(resolvedConnectivity) ??
      SyncQueueService(resolvedConnectivity);

  final manager = OfflineManager(
    connectivity: resolvedConnectivity,
    cache: resolvedCache,
    syncQueue: resolvedSyncQueue,
  );
  await manager.initialize();
  return manager;
}

/// 오프라인 매니저 초기화
Future<void> initializeOfflineManager() async {
  offlineManager = await createAndInitializeOfflineManager();
}
