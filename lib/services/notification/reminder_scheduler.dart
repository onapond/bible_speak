import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Importance;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as ln show Importance;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/notification_settings.dart';
import '../daily_goal_service.dart';

/// 로컬 알림 스케줄러
/// - 아침 만나 알림 (설정된 시간에 매일)
/// - 저녁 학습 리마인더 (목표 미달성 시)
/// - 스트릭 경고 알림
class ReminderScheduler {
  static final ReminderScheduler _instance = ReminderScheduler._internal();
  factory ReminderScheduler() => _instance;
  ReminderScheduler._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  tz.Location? _localTimezone;

  // 알림 ID 상수
  static const int _morningMannaId = 1001;
  static const int _eveningReminderId = 1002;
  static const int _streakWarningId = 1003;

  // 캐시 키
  static const String _keyLastScheduled = 'reminder_last_scheduled';

  // 채널 ID
  static const String _highChannelId = 'bible_speak_high';
  static const String _defaultChannelId = 'bible_speak_default';

  /// 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) return; // 웹에서는 스케줄링 미지원

    try {
      // 타임존 초기화
      tz_data.initializeTimeZones();
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      _localTimezone = tz.getLocation(timezoneName);
      tz.setLocalLocation(_localTimezone!);

      _isInitialized = true;
      debugPrint('ReminderScheduler initialized: $timezoneName');
    } catch (e) {
      debugPrint('ReminderScheduler init error: $e');
      // 실패 시 기본 타임존 사용
      _localTimezone = tz.getLocation('Asia/Seoul');
      tz.setLocalLocation(_localTimezone!);
      _isInitialized = true;
    }
  }

  /// 현재 로컬 시간을 TZDateTime으로 변환
  tz.TZDateTime _now() {
    return tz.TZDateTime.now(_localTimezone ?? tz.local);
  }

  /// 특정 시간의 다음 발생 시간 계산
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = _now();
    var scheduledDate = tz.TZDateTime(
      _localTimezone ?? tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 이미 지났으면 다음 날로
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// 모든 예약 알림 스케줄링
  Future<void> scheduleAll(NotificationSettings settings) async {
    if (!_isInitialized || kIsWeb) return;

    // 전체 알림이 꺼져있으면 모두 취소
    if (!settings.enabled) {
      await cancelAll();
      return;
    }

    // 아침 만나 알림
    if (settings.morningMannaEnabled) {
      await scheduleMorningManna(
        settings.morningMannaHour,
        settings.morningMannaMinute,
      );
    } else {
      await cancelMorningManna();
    }

    // 저녁 학습 리마인더
    if (settings.eveningReminderEnabled) {
      await scheduleEveningReminder(
        settings.eveningReminderHour,
        settings.eveningReminderMinute,
      );
    } else {
      await cancelEveningReminder();
    }

    // 스트릭 경고 알림 (기본 21:00)
    if (settings.streakWarningEnabled) {
      await scheduleStreakWarning();
    } else {
      await cancelStreakWarning();
    }

    // 마지막 스케줄링 시간 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastScheduled, DateTime.now().toIso8601String());
  }

  /// 아침 만나 알림 스케줄링
  Future<void> scheduleMorningManna(int hour, int minute) async {
    if (!_isInitialized || kIsWeb) return;

    final scheduledTime = _nextInstanceOfTime(hour, minute);

    final androidDetails = AndroidNotificationDetails(
      _highChannelId,
      '중요 알림',
      channelDescription: '아침 만나, 학습 리마인드 등 중요 알림',
      importance: ln.Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

    await _notifications.zonedSchedule(
      _morningMannaId,
      '오늘의 말씀',
      '좋은 아침이에요! 오늘도 말씀과 함께 시작해볼까요?',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
      payload: 'type=morning_manna',
    );

    debugPrint('Morning manna scheduled: ${scheduledTime.toString()}');
  }

  /// 저녁 학습 리마인더 스케줄링
  Future<void> scheduleEveningReminder(int hour, int minute) async {
    if (!_isInitialized || kIsWeb) return;

    final scheduledTime = _nextInstanceOfTime(hour, minute);

    final androidDetails = AndroidNotificationDetails(
      _highChannelId,
      '중요 알림',
      channelDescription: '아침 만나, 학습 리마인드 등 중요 알림',
      importance: ln.Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

    await _notifications.zonedSchedule(
      _eveningReminderId,
      '오늘의 학습 목표',
      '아직 오늘 목표를 달성하지 못했어요. 잠깐 학습해볼까요?',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
      payload: 'type=evening_reminder',
    );

    debugPrint('Evening reminder scheduled: ${scheduledTime.toString()}');
  }

  /// 스트릭 경고 알림 스케줄링 (21:00 고정)
  Future<void> scheduleStreakWarning() async {
    if (!_isInitialized || kIsWeb) return;

    final scheduledTime = _nextInstanceOfTime(21, 0);

    final androidDetails = AndroidNotificationDetails(
      _highChannelId,
      '중요 알림',
      channelDescription: '아침 만나, 학습 리마인드 등 중요 알림',
      importance: ln.Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

    await _notifications.zonedSchedule(
      _streakWarningId,
      '연속 학습 알림',
      '오늘 아직 학습하지 않았어요. 연속 학습 기록을 유지해보세요!',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
      payload: 'type=streak_warning',
    );

    debugPrint('Streak warning scheduled: ${scheduledTime.toString()}');
  }

  /// 목표 달성 시 저녁 알림 취소 (동적 취소)
  Future<void> cancelEveningReminderIfGoalMet() async {
    if (!_isInitialized || kIsWeb) return;

    try {
      final goalService = DailyGoalService();
      await goalService.init();

      final todayGoal = goalService.todayGoal;
      if (todayGoal.isGoalMet) {
        await cancelEveningReminder();
        debugPrint('Evening reminder cancelled - goal achieved');
      }
    } catch (e) {
      debugPrint('Check goal for evening reminder error: $e');
    }
  }

  /// 아침 만나 알림 취소
  Future<void> cancelMorningManna() async {
    await _notifications.cancel(_morningMannaId);
    debugPrint('Morning manna cancelled');
  }

  /// 저녁 학습 리마인더 취소
  Future<void> cancelEveningReminder() async {
    await _notifications.cancel(_eveningReminderId);
    debugPrint('Evening reminder cancelled');
  }

  /// 스트릭 경고 알림 취소
  Future<void> cancelStreakWarning() async {
    await _notifications.cancel(_streakWarningId);
    debugPrint('Streak warning cancelled');
  }

  /// 모든 예약 알림 취소
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('All reminders cancelled');
  }

  /// 예약된 알림 목록 확인 (디버깅용)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized || kIsWeb) return [];
    return await _notifications.pendingNotificationRequests();
  }

  /// 즉시 테스트 알림 표시
  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized || kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      _defaultChannelId,
      '기본 알림',
      channelDescription: '찌르기, 일반 알림',
      importance: ln.Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
