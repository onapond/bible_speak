import 'package:hive_flutter/hive_flutter.dart';

/// 캐시 키 정의
class CacheKeys {
  static const String verses = 'verses';
  static const String userProfile = 'user_profile';
  static const String streak = 'streak';
  static const String achievements = 'achievements';
  static const String dailyQuiz = 'daily_quiz';
  static const String groupData = 'group_data';
  static const String pendingActions = 'pending_actions';
  static const String lastSyncTime = 'last_sync_time';
}

/// 캐시 항목 래퍼
class CacheItem<T> {
  final T data;
  final DateTime cachedAt;
  final Duration? ttl;

  CacheItem({
    required this.data,
    required this.cachedAt,
    this.ttl,
  });

  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().difference(cachedAt) > ttl!;
  }

  Map<String, dynamic> toJson(dynamic Function(T) dataEncoder) {
    return {
      'data': dataEncoder(data),
      'cachedAt': cachedAt.millisecondsSinceEpoch,
      'ttlMillis': ttl?.inMilliseconds,
    };
  }

  factory CacheItem.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) dataDecoder,
  ) {
    return CacheItem<T>(
      data: dataDecoder(json['data']),
      cachedAt: DateTime.fromMillisecondsSinceEpoch(json['cachedAt']),
      ttl: json['ttlMillis'] != null
          ? Duration(milliseconds: json['ttlMillis'])
          : null,
    );
  }
}

/// 로컬 캐시 서비스
class CacheService {
  static const String _boxName = 'bible_speak_cache';
  Box? _box;
  bool _isInitialized = false;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
      print('CacheService initialized');
    } catch (e) {
      print('CacheService initialization error: $e');
      _isInitialized = true; // 오류 시에도 계속 진행
    }
  }

  /// 데이터 저장
  Future<void> put<T>(
    String key,
    T data, {
    Duration? ttl,
    dynamic Function(T)? encoder,
  }) async {
    if (_box == null) return;

    try {
      final item = CacheItem<T>(
        data: data,
        cachedAt: DateTime.now(),
        ttl: ttl,
      );

      if (encoder != null) {
        await _box!.put(key, item.toJson(encoder));
      } else {
        // 기본 타입은 직접 저장
        await _box!.put(key, {
          'data': data,
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
          'ttlMillis': ttl?.inMilliseconds,
        });
      }
    } catch (e) {
      print('Cache put error for $key: $e');
    }
  }

  /// 데이터 조회
  T? get<T>(
    String key, {
    T Function(dynamic)? decoder,
    bool ignoreExpiry = false,
  }) {
    if (_box == null) return null;

    try {
      final raw = _box!.get(key);
      if (raw == null) return null;

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(raw['cachedAt']);
      final ttlMillis = raw['ttlMillis'];

      if (!ignoreExpiry && ttlMillis != null) {
        final ttl = Duration(milliseconds: ttlMillis);
        if (DateTime.now().difference(cachedAt) > ttl) {
          // 만료됨
          _box!.delete(key);
          return null;
        }
      }

      final data = raw['data'];
      if (decoder != null) {
        return decoder(data);
      }
      return data as T?;
    } catch (e) {
      print('Cache get error for $key: $e');
      return null;
    }
  }

  /// 데이터 삭제
  Future<void> delete(String key) async {
    if (_box == null) return;
    await _box!.delete(key);
  }

  /// 모든 캐시 삭제
  Future<void> clear() async {
    if (_box == null) return;
    await _box!.clear();
  }

  /// 만료된 항목 정리
  Future<void> cleanExpired() async {
    if (_box == null) return;

    try {
      final keysToDelete = <String>[];

      for (final key in _box!.keys) {
        final raw = _box!.get(key);
        if (raw == null) continue;

        final cachedAt = DateTime.fromMillisecondsSinceEpoch(raw['cachedAt']);
        final ttlMillis = raw['ttlMillis'];

        if (ttlMillis != null) {
          final ttl = Duration(milliseconds: ttlMillis);
          if (DateTime.now().difference(cachedAt) > ttl) {
            keysToDelete.add(key as String);
          }
        }
      }

      for (final key in keysToDelete) {
        await _box!.delete(key);
      }

      if (keysToDelete.isNotEmpty) {
        print('Cleaned ${keysToDelete.length} expired cache items');
      }
    } catch (e) {
      print('Cache cleanup error: $e');
    }
  }

  /// 캐시된 시간 확인
  DateTime? getCachedTime(String key) {
    if (_box == null) return null;

    try {
      final raw = _box!.get(key);
      if (raw == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw['cachedAt']);
    } catch (e) {
      return null;
    }
  }

  /// 키 존재 여부 확인
  bool containsKey(String key) {
    return _box?.containsKey(key) ?? false;
  }
}

/// 싱글톤 인스턴스
final cacheService = CacheService();
