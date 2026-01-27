/// 스트릭 마일스톤 정의
class StreakMilestone {
  final int days;
  final int dalantReward;
  final String badge;
  final String? title;
  final String description;

  const StreakMilestone({
    required this.days,
    required this.dalantReward,
    required this.badge,
    this.title,
    required this.description,
  });

  static const List<StreakMilestone> milestones = [
    StreakMilestone(days: 3, dalantReward: 5, badge: '🔥', description: '첫 불꽃'),
    StreakMilestone(days: 7, dalantReward: 15, badge: '🏅', title: '일주일 전사', description: '7일 연속'),
    StreakMilestone(days: 14, dalantReward: 30, badge: '🥈', title: '2주 챔피언', description: '14일 연속'),
    StreakMilestone(days: 21, dalantReward: 50, badge: '🥇', title: '습관 마스터', description: '21일 습관 형성'),
    StreakMilestone(days: 30, dalantReward: 100, badge: '💎', title: '한 달의 기적', description: '30일 연속'),
    StreakMilestone(days: 100, dalantReward: 500, badge: '👑', title: '백일 성자', description: '100일 연속'),
    StreakMilestone(days: 365, dalantReward: 2000, badge: '🌟', title: '1년 헌신자', description: '365일 연속'),
  ];

  static StreakMilestone? getForDays(int days) {
    return milestones.cast<StreakMilestone?>().firstWhere(
      (m) => m?.days == days,
      orElse: () => null,
    );
  }

  static StreakMilestone? getNextMilestone(int currentStreak) {
    for (final m in milestones) {
      if (m.days > currentStreak) return m;
    }
    return null;
  }
}

/// 사용자 스트릭 모델
class UserStreak {
  final int currentStreak;
  final int longestStreak;
  final String? lastLearnedDate; // YYYY-MM-DD
  final String? streakStartDate;
  final int protectionUsedThisMonth;
  final List<String> protectedDates;
  final List<bool> weeklyHistory; // 최근 7일 [월,화,수,목,금,토,일]
  final Map<String, String> milestones; // {"7": "2026-01-20"}
  final int totalDaysLearned;

  const UserStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLearnedDate,
    this.streakStartDate,
    this.protectionUsedThisMonth = 0,
    this.protectedDates = const [],
    this.weeklyHistory = const [false, false, false, false, false, false, false],
    this.milestones = const {},
    this.totalDaysLearned = 0,
  });

  factory UserStreak.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const UserStreak();

    return UserStreak(
      currentStreak: data['currentStreak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      lastLearnedDate: data['lastLearnedDate'],
      streakStartDate: data['streakStartDate'],
      protectionUsedThisMonth: data['protectionUsedThisMonth'] ?? 0,
      protectedDates: List<String>.from(data['protectedDates'] ?? []),
      weeklyHistory: List<bool>.from(data['weeklyHistory'] ?? [false, false, false, false, false, false, false]),
      milestones: Map<String, String>.from(data['milestones'] ?? {}),
      totalDaysLearned: data['totalDaysLearned'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastLearnedDate': lastLearnedDate,
      'streakStartDate': streakStartDate,
      'protectionUsedThisMonth': protectionUsedThisMonth,
      'protectedDates': protectedDates,
      'weeklyHistory': weeklyHistory,
      'milestones': milestones,
      'totalDaysLearned': totalDaysLearned,
    };
  }

  /// 오늘 학습 여부
  bool get hasLearnedToday {
    if (lastLearnedDate == null) return false;
    final today = _formatDate(DateTime.now());
    return lastLearnedDate == today;
  }

  /// 스트릭이 위험한 상태 (어제 학습 안 함)
  bool get isAtRisk {
    if (lastLearnedDate == null) return currentStreak > 0;
    final yesterday = _formatDate(DateTime.now().subtract(const Duration(days: 1)));
    final today = _formatDate(DateTime.now());
    return lastLearnedDate != today && lastLearnedDate != yesterday && currentStreak > 0;
  }

  /// 스트릭 보호권 사용 가능 여부
  bool get canUseProtection {
    return currentStreak >= 7 && protectionUsedThisMonth < 2;
  }

  /// 21일 목표 진행률
  double get progressTo21Days => (currentStreak / 21).clamp(0.0, 1.0);

  /// 다음 마일스톤
  StreakMilestone? get nextMilestone => StreakMilestone.getNextMilestone(currentStreak);

  /// 다음 마일스톤까지 남은 일수
  int? get daysToNextMilestone {
    final next = nextMilestone;
    if (next == null) return null;
    return next.days - currentStreak;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  UserStreak copyWith({
    int? currentStreak,
    int? longestStreak,
    String? lastLearnedDate,
    String? streakStartDate,
    int? protectionUsedThisMonth,
    List<String>? protectedDates,
    List<bool>? weeklyHistory,
    Map<String, String>? milestones,
    int? totalDaysLearned,
  }) {
    return UserStreak(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastLearnedDate: lastLearnedDate ?? this.lastLearnedDate,
      streakStartDate: streakStartDate ?? this.streakStartDate,
      protectionUsedThisMonth: protectionUsedThisMonth ?? this.protectionUsedThisMonth,
      protectedDates: protectedDates ?? this.protectedDates,
      weeklyHistory: weeklyHistory ?? this.weeklyHistory,
      milestones: milestones ?? this.milestones,
      totalDaysLearned: totalDaysLearned ?? this.totalDaysLearned,
    );
  }
}
