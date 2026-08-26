import 'package:bible_speak/services/offline/cache_service.dart';
import 'package:bible_speak/services/offline/connectivity_service.dart';
import 'package:bible_speak/services/offline/offline_manager.dart';
import 'package:bible_speak/services/offline/sync_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineManager initialization', () {
    test('initializes each dependency once and remains idempotent', () async {
      final connectivity = _FakeConnectivityService();
      final cache = _FakeCacheService();
      final syncQueue = _FakeSyncQueueService(connectivity);
      final manager = await createAndInitializeOfflineManager(
        connectivity: connectivity,
        cache: cache,
        createSyncQueue: (_) => syncQueue,
      );
      addTearDown(manager.dispose);

      await manager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(connectivity.initializeCalls, 1);
      expect(cache.initializeCalls, 1);
      expect(syncQueue.initializeCalls, 1);
    });

    test('finishes initialization when one optional dependency fails',
        () async {
      final connectivity = _FakeConnectivityService();
      final cache = _FakeCacheService(throwOnInitialize: true);
      final syncQueue = _FakeSyncQueueService(connectivity);
      final manager = await createAndInitializeOfflineManager(
        connectivity: connectivity,
        cache: cache,
        createSyncQueue: (_) => syncQueue,
      );
      addTearDown(manager.dispose);

      expect(manager.isInitialized, isTrue);
      expect(connectivity.initializeCalls, 1);
      expect(cache.initializeCalls, 1);
      expect(syncQueue.initializeCalls, 1);
    });

    test('cleans expired cache when connectivity returns', () async {
      final connectivity = _FakeConnectivityService(isOnline: false);
      final cache = _FakeCacheService();
      final syncQueue = _FakeSyncQueueService(connectivity);
      final manager = await createAndInitializeOfflineManager(
        connectivity: connectivity,
        cache: cache,
        createSyncQueue: (_) => syncQueue,
      );
      addTearDown(manager.dispose);
      connectivity.setOnline(true);
      await Future<void>.delayed(Duration.zero);

      expect(manager.isOnline, isTrue);
      expect(cache.cleanExpiredCalls, 1);
    });
  });
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({bool isOnline = true}) : _isOnline = isOnline;

  bool _isOnline;
  int initializeCalls = 0;

  @override
  bool get isOnline => _isOnline;

  @override
  bool get isOffline => !_isOnline;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
  }
}

class _FakeCacheService extends CacheService {
  _FakeCacheService({this.throwOnInitialize = false});

  final bool throwOnInitialize;
  int initializeCalls = 0;
  int cleanExpiredCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (throwOnInitialize) throw StateError('cache unavailable');
  }

  @override
  Future<void> cleanExpired() async {
    cleanExpiredCalls++;
  }
}

class _FakeSyncQueueService extends SyncQueueService {
  _FakeSyncQueueService(super.connectivityService);

  int initializeCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  void dispose() {}
}
