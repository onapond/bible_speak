import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_settings.dart';

/// 알림 설정 관리 서비스
class NotificationSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// 설정 문서 참조
  DocumentReference<Map<String, dynamic>> _settingsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('settings').doc('notifications');
  }

  /// 현재 알림 설정 가져오기
  Future<NotificationSettings> getSettings() async {
    final uid = currentUserId;
    if (uid == null) return const NotificationSettings();

    try {
      final doc = await _settingsRef(uid).get();
      return NotificationSettings.fromMap(doc.data());
    } catch (e) {
      print('Get notification settings error: $e');
      return const NotificationSettings();
    }
  }

  /// 알림 설정 실시간 스트림
  Stream<NotificationSettings> watchSettings() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const NotificationSettings());

    return _settingsRef(uid).snapshots().map((doc) {
      return NotificationSettings.fromMap(doc.data());
    });
  }

  /// 알림 설정 저장
  Future<void> saveSettings(NotificationSettings settings) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await _settingsRef(uid).set(
        {
          ...settings.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      print('Notification settings saved');
    } catch (e) {
      print('Save notification settings error: $e');
    }
  }

  /// 개별 설정 업데이트
  Future<void> updateSetting(String key, dynamic value) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await _settingsRef(uid).set(
        {
          key: value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Update notification setting error: $e');
    }
  }

  /// 전체 알림 활성화/비활성화
  Future<void> setEnabled(bool enabled) async {
    await updateSetting('enabled', enabled);
  }

  /// 아침 만나 알림 설정
  Future<void> setMorningManna({bool? enabled, String? time}) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (enabled != null) updates['morningMannaEnabled'] = enabled;
      if (time != null) updates['morningMannaTime'] = time;

      await _settingsRef(uid).set(updates, SetOptions(merge: true));
    } catch (e) {
      print('Set morning manna settings error: $e');
    }
  }

  /// 스트릭 경고 알림 설정
  Future<void> setStreakWarning(bool enabled) async {
    await updateSetting('streakWarningEnabled', enabled);
  }

  /// 저녁 학습 리마인더 설정
  Future<void> setEveningReminder({bool? enabled, String? time}) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (enabled != null) updates['eveningReminderEnabled'] = enabled;
      if (time != null) updates['eveningReminderTime'] = time;

      await _settingsRef(uid).set(updates, SetOptions(merge: true));
    } catch (e) {
      print('Set evening reminder settings error: $e');
    }
  }

  /// 찌르기 알림 설정
  Future<void> setNudge(bool enabled) async {
    await updateSetting('nudgeEnabled', enabled);
  }

  /// 반응 알림 설정
  Future<void> setReaction(bool enabled) async {
    await updateSetting('reactionEnabled', enabled);
  }

  /// 주간 리포트 알림 설정
  Future<void> setWeeklySummary(bool enabled) async {
    await updateSetting('weeklySummaryEnabled', enabled);
  }

  /// 소리 설정
  Future<void> setSound(bool enabled) async {
    await updateSetting('soundEnabled', enabled);
  }

  /// 진동 설정
  Future<void> setVibration(bool enabled) async {
    await updateSetting('vibrationEnabled', enabled);
  }
}
