import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Importance;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as importance_pkg show Importance;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_types.dart';
import 'notification_handler.dart';
import 'notification_settings_service.dart';
import 'reminder_scheduler.dart';

/// FCM 알림 서비스
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReminderScheduler _reminderScheduler = ReminderScheduler();
  final NotificationSettingsService _settingsService = NotificationSettingsService();

  bool _isInitialized = false;
  String? _fcmToken;
  StreamSubscription? _settingsSubscription;

  String? get fcmToken => _fcmToken;
  String? get currentUserId => _auth.currentUser?.uid;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 로컬 알림 초기화 (웹 제외)
      if (!kIsWeb) {
        await _initializeLocalNotifications();

        // 리마인더 스케줄러 초기화
        await _reminderScheduler.initialize();
      }

      // FCM 초기화
      await _initializeFCM();

      _isInitialized = true;
      print('NotificationService initialized');

      // 설정 변경 감지 및 스케줄러 업데이트
      _watchSettingsChanges();
    } catch (e) {
      print('NotificationService init error: $e');
    }
  }

  /// 설정 변경 감지 및 스케줄러 업데이트
  void _watchSettingsChanges() {
    _settingsSubscription?.cancel();
    _settingsSubscription = _settingsService.watchSettings().listen(
      (settings) async {
        await _reminderScheduler.scheduleAll(settings);
      },
      onError: (e) => print('Watch settings error: $e'),
    );
  }

  /// 리마인더 스케줄링 (설정 기반)
  Future<void> scheduleReminders() async {
    if (kIsWeb) return;
    final settings = await _settingsService.getSettings();
    await _reminderScheduler.scheduleAll(settings);
  }

  /// 목표 달성 시 저녁 알림 취소
  Future<void> cancelEveningReminderIfGoalMet() async {
    await _reminderScheduler.cancelEveningReminderIfGoalMet();
  }

  /// 테스트 알림 표시
  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    await _reminderScheduler.showTestNotification(title: title, body: body);
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 알림 채널 생성
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      for (final channel in NotificationChannel.channels) {
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            channel.name,
            description: channel.description,
            importance: _mapImportance(channel.importance),
            playSound: channel.playSound,
            enableVibration: channel.enableVibration,
          ),
        );
      }
    }
  }

  /// FCM 초기화
  Future<void> _initializeFCM() async {
    // 메시지 핸들러 설정
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 앱이 종료된 상태에서 알림으로 열린 경우
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // 토큰 가져오기 및 저장
    await _getAndSaveToken();

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveTokenToFirestore(newToken);
    });
  }

  /// FCM 토큰 가져오기 및 저장
  Future<void> _getAndSaveToken() async {
    try {
      if (kIsWeb) {
        // 웹에서는 VAPID 키 필요
        _fcmToken = await _messaging.getToken(
          vapidKey: 'BCS9On6lgZ79otYyGDWNKgWy-5qiZ3Ag0_UqFZaPDWtcwZMwD7FK5khQdKYOeuV2fuzl96dcx1gpk1tQ7h5LlYA',
        );
      } else {
        _fcmToken = await _messaging.getToken();
      }

      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
        print('FCM Token: $_fcmToken');
      }
    } catch (e) {
      print('Get FCM token error: $e');
    }
  }

  /// Firestore에 토큰 저장
  Future<void> _saveTokenToFirestore(String token) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final tokenData = {
        'token': token,
        'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // 플랫폼별로 토큰 저장 (기기별 토큰 관리)
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token.hashCode.toString())
          .set(tokenData, SetOptions(merge: true));

      print('FCM token saved to Firestore');
    } catch (e) {
      print('Save FCM token error: $e');
    }
  }

  /// 알림 권한 요청
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        await _getAndSaveToken();
      }

      return granted;
    } catch (e) {
      print('Request permission error: $e');
      return false;
    }
  }

  /// 현재 권한 상태 확인
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// 포그라운드 메시지 핸들러
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message received: ${message.messageId}');

    // 로컬 알림으로 표시 (웹 제외)
    if (!kIsWeb) {
      _showLocalNotification(message);
    }

    // 커스텀 핸들러 호출
    NotificationHandler.handleForegroundMessage(message);
  }

  /// 알림 탭으로 앱 열림 핸들러
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.messageId}');
    NotificationHandler.handleNotificationTap(message.data);
  }

  /// 로컬 알림 탭 핸들러
  void _onNotificationTapped(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      NotificationHandler.handleNotificationTapFromPayload(response.payload!);
    }
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = NotificationType.fromString(message.data['type']);
    final channel = NotificationChannel.getChannelForType(type);

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: _mapImportance(channel.importance),
      priority: channel.importance == Importance.high ? Priority.high : Priority.defaultPriority,
      playSound: channel.playSound,
      enableVibration: channel.enableVibration,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: _encodePayload(message.data),
    );
  }

  /// Importance 매핑 (flutter_local_notifications 패키지의 Importance)
  static importance_pkg.Importance _mapImportance(Importance importance) {
    switch (importance) {
      case Importance.high:
        return importance_pkg.Importance.high;
      case Importance.defaultImportance:
        return importance_pkg.Importance.defaultImportance;
      case Importance.low:
        return importance_pkg.Importance.low;
    }
  }

  /// 페이로드 인코딩
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// 토큰 삭제 (로그아웃 시)
  Future<void> deleteToken() async {
    final uid = currentUserId;
    if (uid == null || _fcmToken == null) return;

    try {
      // Firestore에서 토큰 삭제
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(_fcmToken.hashCode.toString())
          .delete();

      // FCM 토큰 삭제
      await _messaging.deleteToken();
      _fcmToken = null;

      // 예약된 알림 취소
      await _reminderScheduler.cancelAll();

      print('FCM token deleted');
    } catch (e) {
      print('Delete FCM token error: $e');
    }
  }

  /// 서비스 정리
  void dispose() {
    _settingsSubscription?.cancel();
  }

  /// 토픽 구독 (그룹 알림용)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Subscribe to topic error: $e');
    }
  }

  /// 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Unsubscribe from topic error: $e');
    }
  }
}
