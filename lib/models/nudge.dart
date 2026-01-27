/// 찌르기(Nudge) 모델
class Nudge {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final String message;
  final String? templateId;
  final String groupId;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? respondedAt;

  const Nudge({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.message,
    this.templateId,
    required this.groupId,
    required this.createdAt,
    this.readAt,
    this.respondedAt,
  });

  factory Nudge.fromMap(String id, Map<String, dynamic> data) {
    return Nudge(
      id: id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserName: data['toUserName'] ?? '',
      message: data['message'] ?? '',
      templateId: data['templateId'],
      groupId: data['groupId'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      readAt: data['readAt']?.toDate(),
      respondedAt: data['respondedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'message': message,
      'templateId': templateId,
      'groupId': groupId,
      'createdAt': createdAt,
      'readAt': readAt,
      'respondedAt': respondedAt,
    };
  }

  bool get isRead => readAt != null;
  bool get isResponded => respondedAt != null;
}

/// 찌르기 메시지 템플릿
class NudgeTemplate {
  final String id;
  final String emoji;
  final String message;
  final String shortLabel;

  const NudgeTemplate({
    required this.id,
    required this.emoji,
    required this.message,
    required this.shortLabel,
  });

  static const List<NudgeTemplate> templates = [
    NudgeTemplate(
      id: 'pray',
      emoji: '🙏',
      message: '함께 암송해요! 잠깐이라도 들러주세요~',
      shortLabel: '기도',
    ),
    NudgeTemplate(
      id: 'miss',
      emoji: '💕',
      message: '보고 싶어요! 오늘 말라기 1절 어때요?',
      shortLabel: '그리움',
    ),
    NudgeTemplate(
      id: 'fighting',
      emoji: '💪',
      message: '우리 그룹이 기다려요! 화이팅!',
      shortLabel: '응원',
    ),
    NudgeTemplate(
      id: 'gentle',
      emoji: '🌸',
      message: '천천히, 한 절만이라도 함께해요~',
      shortLabel: '부드럽게',
    ),
  ];

  static NudgeTemplate? getById(String id) {
    return templates.cast<NudgeTemplate?>().firstWhere(
      (t) => t?.id == id,
      orElse: () => null,
    );
  }
}

/// 비활성 멤버 정보
class InactiveMember {
  final String odId;
  final String name;
  final int daysSinceActive;
  final String? lastActiveDate;

  const InactiveMember({
    required this.odId,
    required this.name,
    required this.daysSinceActive,
    this.lastActiveDate,
  });

  factory InactiveMember.fromMap(Map<String, dynamic> data) {
    return InactiveMember(
      odId: data['uid'] ?? '',
      name: data['name'] ?? '',
      daysSinceActive: data['daysSinceActive'] ?? 0,
      lastActiveDate: data['lastActiveDate'],
    );
  }

  /// 비활성 상태 아이콘
  String get statusEmoji {
    if (daysSinceActive >= 14) return '💤';
    if (daysSinceActive >= 7) return '😴😴';
    return '😴';
  }

  /// 비활성 상태 메시지
  String get statusMessage {
    if (daysSinceActive >= 14) return '$daysSinceActive일 이상 미접속';
    if (daysSinceActive >= 7) return '$daysSinceActive일 미접속';
    return '$daysSinceActive일 미접속';
  }

  /// 강조 표시 여부
  bool get isHighlighted => daysSinceActive >= 7;
}

/// 찌르기 일일 통계
class NudgeDailyStats {
  final int nudgesSent;
  final Map<String, DateTime> nudgesTo;
  final int dailyLimit;

  const NudgeDailyStats({
    required this.nudgesSent,
    required this.nudgesTo,
    required this.dailyLimit,
  });

  factory NudgeDailyStats.fromMap(Map<String, dynamic>? data, {bool isLeader = false}) {
    final nudgesTo = <String, DateTime>{};
    if (data?['nudgesTo'] != null) {
      (data!['nudgesTo'] as Map<String, dynamic>).forEach((key, value) {
        nudgesTo[key] = value.toDate();
      });
    }

    return NudgeDailyStats(
      nudgesSent: data?['nudgesSent'] ?? 0,
      nudgesTo: nudgesTo,
      dailyLimit: isLeader ? 10 : 3,
    );
  }

  /// 오늘 남은 찌르기 횟수
  int get remainingNudges => (dailyLimit - nudgesSent).clamp(0, dailyLimit);

  /// 찌르기 가능 여부
  bool get canSendNudge => remainingNudges > 0;

  /// 특정 대상에게 찌르기 가능 여부 (24시간 내 1회 제한)
  bool canNudgeUser(String userId) {
    if (!canSendNudge) return false;
    final lastNudge = nudgesTo[userId];
    if (lastNudge == null) return true;
    return DateTime.now().difference(lastNudge).inHours >= 24;
  }
}
