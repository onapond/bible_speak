/// 알림 설정 모델
class NotificationSettings {
  final bool enabled;
  final bool morningMannaEnabled;
  final String morningMannaTime; // HH:mm 형식
  final bool streakWarningEnabled;
  final bool nudgeEnabled;
  final bool reactionEnabled;
  final bool weeklySummaryEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const NotificationSettings({
    this.enabled = true,
    this.morningMannaEnabled = true,
    this.morningMannaTime = '06:00',
    this.streakWarningEnabled = true,
    this.nudgeEnabled = true,
    this.reactionEnabled = true,
    this.weeklySummaryEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const NotificationSettings();

    return NotificationSettings(
      enabled: data['enabled'] ?? true,
      morningMannaEnabled: data['morningMannaEnabled'] ?? true,
      morningMannaTime: data['morningMannaTime'] ?? '06:00',
      streakWarningEnabled: data['streakWarningEnabled'] ?? true,
      nudgeEnabled: data['nudgeEnabled'] ?? true,
      reactionEnabled: data['reactionEnabled'] ?? true,
      weeklySummaryEnabled: data['weeklySummaryEnabled'] ?? true,
      soundEnabled: data['soundEnabled'] ?? true,
      vibrationEnabled: data['vibrationEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'morningMannaEnabled': morningMannaEnabled,
      'morningMannaTime': morningMannaTime,
      'streakWarningEnabled': streakWarningEnabled,
      'nudgeEnabled': nudgeEnabled,
      'reactionEnabled': reactionEnabled,
      'weeklySummaryEnabled': weeklySummaryEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? morningMannaEnabled,
    String? morningMannaTime,
    bool? streakWarningEnabled,
    bool? nudgeEnabled,
    bool? reactionEnabled,
    bool? weeklySummaryEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      morningMannaEnabled: morningMannaEnabled ?? this.morningMannaEnabled,
      morningMannaTime: morningMannaTime ?? this.morningMannaTime,
      streakWarningEnabled: streakWarningEnabled ?? this.streakWarningEnabled,
      nudgeEnabled: nudgeEnabled ?? this.nudgeEnabled,
      reactionEnabled: reactionEnabled ?? this.reactionEnabled,
      weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  /// 아침 만나 시간을 TimeOfDay로 변환
  DateTime get morningMannaDateTime {
    final parts = morningMannaTime.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// 아침 만나 시간 (시)
  int get morningMannaHour => int.parse(morningMannaTime.split(':')[0]);

  /// 아침 만나 시간 (분)
  int get morningMannaMinute => int.parse(morningMannaTime.split(':')[1]);
}
