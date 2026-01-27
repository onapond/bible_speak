import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_types.dart';

/// 알림 핸들러
/// 알림 수신 및 탭 이벤트 처리
class NotificationHandler {
  // 알림 탭 이벤트 스트림
  static final StreamController<Map<String, dynamic>> _onNotificationTap =
      StreamController<Map<String, dynamic>>.broadcast();

  // 포그라운드 알림 수신 스트림
  static final StreamController<RemoteMessage> _onForegroundMessage =
      StreamController<RemoteMessage>.broadcast();

  /// 알림 탭 이벤트 스트림
  static Stream<Map<String, dynamic>> get onNotificationTap => _onNotificationTap.stream;

  /// 포그라운드 알림 수신 스트림
  static Stream<RemoteMessage> get onForegroundMessage => _onForegroundMessage.stream;

  /// 포그라운드 메시지 처리
  static void handleForegroundMessage(RemoteMessage message) {
    print('[NotificationHandler] Foreground message: ${message.data}');
    _onForegroundMessage.add(message);
  }

  /// 알림 탭 처리 (FCM 메시지 데이터)
  static void handleNotificationTap(Map<String, dynamic> data) {
    print('[NotificationHandler] Notification tapped: $data');
    _onNotificationTap.add(data);
    _routeToScreen(data);
  }

  /// 알림 탭 처리 (로컬 알림 페이로드)
  static void handleNotificationTapFromPayload(String payload) {
    final data = _decodePayload(payload);
    handleNotificationTap(data);
  }

  /// 페이로드 디코딩
  static Map<String, dynamic> _decodePayload(String payload) {
    final data = <String, dynamic>{};
    for (final pair in payload.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        data[parts[0]] = parts[1];
      }
    }
    return data;
  }

  /// 알림 유형에 따른 화면 라우팅
  static void _routeToScreen(Map<String, dynamic> data) {
    final type = NotificationType.fromString(data['type']);

    switch (type) {
      case NotificationType.morningManna:
        // 아침 만나 화면으로 이동
        _navigateTo('/morning-manna', data);
        break;

      case NotificationType.streakWarning:
        // 스트릭 화면으로 이동
        _navigateTo('/streak', data);
        break;

      case NotificationType.nudgeReceived:
        // 그룹 화면으로 이동
        final groupId = data['groupId'];
        _navigateTo('/group/$groupId', data);
        break;

      case NotificationType.reactionBatch:
        // 활동 피드로 이동
        _navigateTo('/activity', data);
        break;

      case NotificationType.weeklySummary:
        // 통계 화면으로 이동
        _navigateTo('/stats', data);
        break;

      case NotificationType.general:
        // 홈 화면으로 이동
        _navigateTo('/', data);
        break;
    }
  }

  /// 화면 이동 (실제 네비게이션은 UI 레이어에서 처리)
  static void _navigateTo(String route, Map<String, dynamic> data) {
    // NavigatorKey를 통한 네비게이션은 main.dart에서 설정
    // 여기서는 이벤트만 발행하고, UI에서 구독하여 처리
    print('[NotificationHandler] Navigate to: $route with data: $data');
  }

  /// 리소스 정리
  static void dispose() {
    _onNotificationTap.close();
    _onForegroundMessage.close();
  }
}

/// 백그라운드 메시지 핸들러 (top-level 함수)
/// main.dart에서 FirebaseMessaging.onBackgroundMessage에 등록
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[Background] Message received: ${message.messageId}');
  print('[Background] Data: ${message.data}');

  // 백그라운드에서는 알림이 자동으로 표시됨 (notification 필드 있는 경우)
  // data-only 메시지인 경우 여기서 처리 가능
}
