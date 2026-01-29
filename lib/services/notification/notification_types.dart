/// 알림 유형 정의
enum NotificationType {
  morningManna('morning_manna', '아침 만나', 'HIGH'),
  streakWarning('streak_warning', '학습 리마인드', 'HIGH'),
  nudgeReceived('nudge_received', '찌르기 알림', 'MEDIUM'),
  reactionBatch('reaction_batch', '반응 알림', 'LOW'),
  weeklySummary('weekly_summary', '주간 리포트', 'LOW'),
  general('general', '일반 알림', 'DEFAULT');

  final String id;
  final String label;
  final String priority;

  const NotificationType(this.id, this.label, this.priority);

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.id == value,
      orElse: () => NotificationType.general,
    );
  }
}

/// Android 알림 채널 정의
class NotificationChannel {
  final String id;
  final String name;
  final String description;
  final Importance importance;
  final bool playSound;
  final bool enableVibration;

  const NotificationChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    this.playSound = true,
    this.enableVibration = true,
  });

  static const List<NotificationChannel> channels = [
    NotificationChannel(
      id: 'bible_speak_high',
      name: '중요 알림',
      description: '아침 만나, 학습 리마인드 등 중요 알림',
      importance: Importance.high,
    ),
    NotificationChannel(
      id: 'bible_speak_default',
      name: '기본 알림',
      description: '찌르기, 일반 알림',
      importance: Importance.defaultImportance,
    ),
    NotificationChannel(
      id: 'bible_speak_low',
      name: '조용한 알림',
      description: '반응 배치, 주간 리포트',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    ),
  ];

  static NotificationChannel getChannelForType(NotificationType type) {
    switch (type.priority) {
      case 'HIGH':
        return channels[0];
      case 'MEDIUM':
      case 'DEFAULT':
        return channels[1];
      case 'LOW':
        return channels[2];
      default:
        return channels[1];
    }
  }
}

/// flutter_local_notifications Importance 매핑용
enum Importance {
  high,
  defaultImportance,
  low,
}
