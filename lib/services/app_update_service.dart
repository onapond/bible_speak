import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// 조건부 import: 웹에서만 실제 구현 사용
// dart.library.js_interop은 웹 환경에서만 true
import 'pwa_update_service_stub.dart'
    if (dart.library.js_interop) 'pwa_update_service.dart';

/// 앱 업데이트 서비스 (플랫폼 독립적 인터페이스)
///
/// 사용법:
/// 1. main.dart에서 AppUpdateService().initialize() 호출
/// 2. 메인 화면에서 AppUpdateService().setContext(context) 호출
/// 3. 업데이트 감지 시 자동으로 다이얼로그 표시
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final _pwaService = PwaUpdateService();

  /// 업데이트 준비 상태
  bool get updateReady => kIsWeb ? _pwaService.updateReady : false;

  /// 업데이트 가능 알림 스트림
  Stream<bool> get onUpdateAvailable =>
      kIsWeb ? _pwaService.onUpdateAvailable : Stream.value(false);

  /// 초기화 (앱 시작 시)
  void initialize() {
    if (kIsWeb) {
      _pwaService.initialize();
      debugPrint('[AppUpdate] Service initialized for web');
    }
  }

  /// 컨텍스트 설정 (메인 화면 진입 시)
  void setContext(BuildContext context) {
    if (kIsWeb) {
      _pwaService.setContext(context);
    }
  }

  /// 업데이트 다이얼로그 표시
  void showUpdateDialog(BuildContext context) {
    if (kIsWeb) {
      _pwaService.showUpdateDialog(context);
    }
  }

  /// 업데이트 SnackBar 표시
  void showUpdateSnackBar(BuildContext context) {
    if (kIsWeb) {
      _pwaService.showUpdateSnackBar(context);
    }
  }

  /// 업데이트 적용
  void applyUpdate() {
    if (kIsWeb) {
      _pwaService.applyUpdate();
    }
  }

  /// 수동 업데이트 확인
  Future<bool> checkForUpdate() async {
    if (kIsWeb) {
      return await _pwaService.checkForUpdate();
    }
    return false;
  }

  /// 강제 새로고침 (캐시 삭제)
  void forceRefresh() {
    if (kIsWeb) {
      _pwaService.forceRefresh();
    }
  }

  /// 현재 앱 버전
  String get currentVersion =>
      kIsWeb ? _pwaService.currentVersion : 'native';
}
