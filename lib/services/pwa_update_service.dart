import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

// JS interop 함수 정의
@JS('applyAppUpdate')
external void _applyAppUpdate();

@JS('getAppVersion')
external String? _getAppVersion();

@JS('forceAppRefresh')
external void _forceAppRefresh();

// globalThis 접근을 위한 extension
extension GlobalThisExtension on JSObject {
  external JSAny? get pendingUpdateNotification;
  external JSAny? get appUpdateReady;
  external set flutterUpdateCallback(JSFunction? value);
}

@JS('globalThis')
external JSObject get _globalThis;

/// PWA 업데이트 서비스
/// - 새 버전 감지 시 사용자에게 알림
/// - iOS Safari PWA 환경 최적화
class PwaUpdateService {
  static final PwaUpdateService _instance = PwaUpdateService._internal();
  factory PwaUpdateService() => _instance;
  PwaUpdateService._internal();

  // 업데이트 준비 상태
  bool _updateReady = false;
  bool get updateReady => _updateReady;

  // 업데이트 콜백
  final _updateController = StreamController<bool>.broadcast();
  Stream<bool> get onUpdateAvailable => _updateController.stream;

  // 현재 컨텍스트 (다이얼로그 표시용)
  BuildContext? _context;

  /// 초기화 (main.dart에서 호출)
  void initialize() {
    if (!kIsWeb) return;

    debugPrint('[PWA] Initializing update service...');

    // JavaScript에서 Flutter로 업데이트 알림 받기
    _globalThis.flutterUpdateCallback = _onUpdateAvailable.toJS;

    // 이미 대기 중인 업데이트 확인
    final pendingUpdate = _globalThis.pendingUpdateNotification;
    if (pendingUpdate != null && (pendingUpdate as JSBoolean).toDart == true) {
      debugPrint('[PWA] Pending update found');
      _updateReady = true;
      _updateController.add(true);
    }

    // 앱 시작 시 버전 로깅
    try {
      final version = _getAppVersion();
      debugPrint('[PWA] Current app version: $version');
    } catch (e) {
      debugPrint('[PWA] Could not get app version: $e');
    }
  }

  /// JS에서 호출되는 콜백
  void _onUpdateAvailable() {
    debugPrint('[PWA] Update notification received from JS');
    _updateReady = true;
    _updateController.add(true);

    // 컨텍스트가 있으면 즉시 다이얼로그 표시
    if (_context != null) {
      showUpdateDialog(_context!);
    }
  }

  /// 컨텍스트 설정 (메인 화면에서 호출)
  void setContext(BuildContext context) {
    _context = context;

    // 이미 업데이트가 대기 중이면 즉시 표시
    if (_updateReady) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_context != null) {
          showUpdateDialog(_context!);
        }
      });
    }
  }

  /// 업데이트 다이얼로그 표시
  void showUpdateDialog(BuildContext context) {
    if (!_updateReady) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.system_update, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text(
              '업데이트 알림',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '새로운 버전이 준비되었습니다!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '최신 기능과 개선 사항을 사용하려면 앱을 업데이트해주세요.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              applyUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('지금 업데이트'),
          ),
        ],
      ),
    );
  }

  /// SnackBar로 업데이트 알림 (덜 방해되는 방식)
  void showUpdateSnackBar(BuildContext context) {
    if (!_updateReady) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('새 버전이 준비되었습니다'),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                applyUpdate();
              },
              child: const Text(
                '업데이트',
                style: TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// 업데이트 적용 (페이지 새로고침)
  void applyUpdate() {
    debugPrint('[PWA] Applying update...');
    try {
      _applyAppUpdate();
    } catch (e) {
      debugPrint('[PWA] applyAppUpdate failed, forcing reload: $e');
      forceRefresh();
    }
  }

  /// 강제 새로고침 (캐시 삭제 후 새로고침)
  void forceRefresh() {
    debugPrint('[PWA] Force refreshing with cache clear...');
    try {
      _forceAppRefresh();
    } catch (e) {
      debugPrint('[PWA] forceAppRefresh failed, fallback reload: $e');
      web.window.location.reload();
    }
  }

  /// 수동 업데이트 확인 (version.json 직접 체크)
  Future<bool> checkForUpdate() async {
    if (!kIsWeb) return false;

    debugPrint('[PWA] Manual update check triggered');

    try {
      // 현재 버전 가져오기
      final currentVersion = _getAppVersion() ?? 'unknown';

      // version.json fetch (캐시 우회)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await web.window
          .fetch('/version.json?t=$timestamp'.toJS)
          .toDart;

      if (!response.ok) {
        debugPrint('[PWA] version.json fetch failed: ${response.status}');
        return false;
      }

      final jsText = await response.text().toDart;
      final text = jsText.toDart; // JSString -> String
      final serverData = jsonDecode(text) as Map<String, dynamic>;
      final serverVersion = serverData['version'] as String?;

      debugPrint('[PWA] Version check - Current: $currentVersion, Server: $serverVersion');

      if (currentVersion != 'unknown' &&
          currentVersion != 'BUILD_TIMESTAMP' &&
          serverVersion != null &&
          currentVersion != serverVersion) {
        debugPrint('[PWA] New version detected!');
        _updateReady = true;
        _updateController.add(true);
        return true;
      }

      // JS 측 상태도 확인
      final jsUpdateReady = _globalThis.appUpdateReady;
      if (jsUpdateReady != null && (jsUpdateReady as JSBoolean).toDart == true) {
        debugPrint('[PWA] JS reports update ready');
        _updateReady = true;
        _updateController.add(true);
        return true;
      }

      debugPrint('[PWA] No update available');
      return false;
    } catch (e) {
      debugPrint('[PWA] Update check error: $e');
      return false;
    }
  }

  /// 현재 앱 버전
  String get currentVersion {
    try {
      return _getAppVersion() ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  void dispose() {
    _updateController.close();
  }
}
