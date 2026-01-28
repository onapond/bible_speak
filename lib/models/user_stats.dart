import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 통계 모델
class UserStats {
  final String userId;
  final int totalVersesLearned;
  final int totalVersesMastered;
  final int totalStudyMinutes;
  final int totalQuizzesTaken;
  final int perfectQuizCount;
  final int currentStreak;
  final int longestStreak;
  final int totalTalants;
  final int totalReactionsReceived;
  final int totalNudgesSent;
  final int totalNudgesReceived;
  final DateTime? lastActiveDate;
  final Map<String, int> dailyActivity; // YYYY-MM-DD -> minutes
  final Map<String, int> weeklyActivity; // YYYY-WW -> minutes
  final Map<String, int> monthlyActivity; // YYYY-MM -> minutes

  const UserStats({
    required this.userId,
    this.totalVersesLearned = 0,
    this.totalVersesMastered = 0,
    this.totalStudyMinutes = 0,
    this.totalQuizzesTaken = 0,
    this.perfectQuizCount = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalTalants = 0,
    this.totalReactionsReceived = 0,
    this.totalNudgesSent = 0,
    this.totalNudgesReceived = 0,
    this.lastActiveDate,
    this.dailyActivity = const {},
    this.weeklyActivity = const {},
    this.monthlyActivity = const {},
  });

  factory UserStats.fromFirestore(String odId, Map<String, dynamic> data) {
    return UserStats(
      userId: odId,
      totalVersesLearned: data['totalVersesLearned'] ?? 0,
      totalVersesMastered: data['totalVersesMastered'] ?? 0,
      totalStudyMinutes: data['totalStudyMinutes'] ?? 0,
      totalQuizzesTaken: data['totalQuizzesTaken'] ?? 0,
      perfectQuizCount: data['perfectQuizCount'] ?? 0,
      currentStreak: data['currentStreak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      totalTalants: data['totalTalants'] ?? 0,
      totalReactionsReceived: data['totalReactionsReceived'] ?? 0,
      totalNudgesSent: data['totalNudgesSent'] ?? 0,
      totalNudgesReceived: data['totalNudgesReceived'] ?? 0,
      lastActiveDate: (data['lastActiveDate'] as Timestamp?)?.toDate(),
      dailyActivity: Map<String, int>.from(data['dailyActivity'] ?? {}),
      weeklyActivity: Map<String, int>.from(data['weeklyActivity'] ?? {}),
      monthlyActivity: Map<String, int>.from(data['monthlyActivity'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'totalVersesLearned': totalVersesLearned,
        'totalVersesMastered': totalVersesMastered,
        'totalStudyMinutes': totalStudyMinutes,
        'totalQuizzesTaken': totalQuizzesTaken,
        'perfectQuizCount': perfectQuizCount,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalTalants': totalTalants,
        'totalReactionsReceived': totalReactionsReceived,
        'totalNudgesSent': totalNudgesSent,
        'totalNudgesReceived': totalNudgesReceived,
        'lastActiveDate':
            lastActiveDate != null ? Timestamp.fromDate(lastActiveDate!) : null,
        'dailyActivity': dailyActivity,
        'weeklyActivity': weeklyActivity,
        'monthlyActivity': monthlyActivity,
      };

  /// 마스터 비율 (0.0 ~ 1.0)
  double get masteryRate {
    if (totalVersesLearned == 0) return 0.0;
    return totalVersesMastered / totalVersesLearned;
  }

  /// 퀴즈 만점 비율 (0.0 ~ 1.0)
  double get perfectQuizRate {
    if (totalQuizzesTaken == 0) return 0.0;
    return perfectQuizCount / totalQuizzesTaken;
  }

  /// 학습 시간을 포맷팅
  String get formattedStudyTime {
    final hours = totalStudyMinutes ~/ 60;
    final minutes = totalStudyMinutes % 60;
    if (hours > 0) {
      return '${hours}시간 ${minutes}분';
    }
    return '$minutes분';
  }

  /// 최근 7일 활동 데이터
  List<DailyActivityData> get recentWeekActivity {
    final result = <DailyActivityData>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      result.add(DailyActivityData(
        date: date,
        minutes: dailyActivity[key] ?? 0,
      ));
    }

    return result;
  }

  /// 최근 4주 활동 데이터
  List<WeeklyActivityData> get recentMonthActivity {
    final result = <WeeklyActivityData>[];
    final now = DateTime.now();

    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
      final weekNumber = _getWeekNumber(weekStart);
      final key = '${weekStart.year}-$weekNumber';
      result.add(WeeklyActivityData(
        weekStart: weekStart,
        weekNumber: weekNumber,
        minutes: weeklyActivity[key] ?? 0,
      ));
    }

    return result;
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) ~/ 7) + 1;
  }
}

/// 일별 활동 데이터
class DailyActivityData {
  final DateTime date;
  final int minutes;

  const DailyActivityData({
    required this.date,
    required this.minutes,
  });

  String get dayLabel {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[date.weekday - 1];
  }
}

/// 주별 활동 데이터
class WeeklyActivityData {
  final DateTime weekStart;
  final int weekNumber;
  final int minutes;

  const WeeklyActivityData({
    required this.weekStart,
    required this.weekNumber,
    required this.minutes,
  });

  String get weekLabel => '${weekNumber}주';
}

/// 학습 진도 데이터
class StudyProgress {
  final String bookName;
  final int totalVerses;
  final int learnedVerses;
  final int masteredVerses;

  const StudyProgress({
    required this.bookName,
    required this.totalVerses,
    required this.learnedVerses,
    required this.masteredVerses,
  });

  double get learnedRate {
    if (totalVerses == 0) return 0.0;
    return learnedVerses / totalVerses;
  }

  double get masteredRate {
    if (totalVerses == 0) return 0.0;
    return masteredVerses / totalVerses;
  }
}
