import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'connectivity_service.dart';

/// 동기화 작업 유형
enum SyncActionType {
  updateStreak,
  submitQuiz,
  updateProgress,
  sendReaction,
  sendNudge,
  claimReward,
}

/// 동기화 대기 작업
class SyncAction {
  final String id;
  final SyncActionType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  SyncAction({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'data': data,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'retryCount': retryCount,
      };

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
        id: json['id'],
        type: SyncActionType.values[json['type']],
        data: Map<String, dynamic>.from(json['data']),
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
        retryCount: json['retryCount'] ?? 0,
      );
}

/// 동기화 큐 서비스
class SyncQueueService {
  static const String _boxName = 'sync_queue';
  static const int _maxRetries = 3;

  Box? _box;
  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _syncTimer;

  final ConnectivityService _connectivityService;
  final Map<SyncActionType, Future<bool> Function(Map<String, dynamic>)>
      _handlers = {};

  SyncQueueService(this._connectivityService);

  /// 핸들러 등록
  void registerHandler(
    SyncActionType type,
    Future<bool> Function(Map<String, dynamic>) handler,
  ) {
    _handlers[type] = handler;
  }

  /// 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;

      // 연결 상태 변경 리스닝
      _connectivityService.addListener(_onConnectivityChanged);

      // 초기 동기화 시도
      if (_connectivityService.isOnline) {
        _startSync();
      }

      print('SyncQueueService initialized with ${_box!.length} pending actions');
    } catch (e) {
      print('SyncQueueService initialization error: $e');
      _isInitialized = true;
    }
  }

  void _onConnectivityChanged() {
    if (_connectivityService.isOnline) {
      _startSync();
    }
  }

  /// 작업 추가
  Future<void> enqueue(SyncActionType type, Map<String, dynamic> data) async {
    if (_box == null) return;

    final action = SyncAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    await _box!.put(action.id, action.toJson());
    print('Enqueued sync action: ${type.name}');

    // 온라인이면 즉시 동기화 시도
    if (_connectivityService.isOnline) {
      _startSync();
    }
  }

  /// 대기 중인 작업 수
  int get pendingCount => _box?.length ?? 0;

  /// 대기 중인 작업 목록
  List<SyncAction> get pendingActions {
    if (_box == null) return [];

    return _box!.values
        .map((e) => SyncAction.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 동기화 시작
  void _startSync() {
    if (_isSyncing || _box == null || _box!.isEmpty) return;

    // 디바운싱
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 1), () {
      _processQueue();
    });
  }

  /// 큐 처리
  Future<void> _processQueue() async {
    if (_isSyncing || _box == null) return;
    _isSyncing = true;

    try {
      final actions = pendingActions;
      print('Processing ${actions.length} sync actions');

      for (final action in actions) {
        if (!_connectivityService.isOnline) {
          print('Went offline, stopping sync');
          break;
        }

        final handler = _handlers[action.type];
        if (handler == null) {
          print('No handler for ${action.type.name}, removing');
          await _box!.delete(action.id);
          continue;
        }

        try {
          final success = await handler(action.data);

          if (success) {
            await _box!.delete(action.id);
            print('Synced action: ${action.type.name}');
          } else {
            action.retryCount++;
            if (action.retryCount >= _maxRetries) {
              print('Max retries reached for ${action.type.name}, removing');
              await _box!.delete(action.id);
            } else {
              await _box!.put(action.id, action.toJson());
            }
          }
        } catch (e) {
          print('Sync error for ${action.type.name}: $e');
          action.retryCount++;
          if (action.retryCount >= _maxRetries) {
            await _box!.delete(action.id);
          } else {
            await _box!.put(action.id, action.toJson());
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// 강제 동기화
  Future<void> forceSync() async {
    if (!_connectivityService.isOnline) return;
    await _processQueue();
  }

  /// 큐 비우기
  Future<void> clear() async {
    await _box?.clear();
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivityService.removeListener(_onConnectivityChanged);
  }
}

/// 싱글톤 인스턴스
late final SyncQueueService syncQueueService;
