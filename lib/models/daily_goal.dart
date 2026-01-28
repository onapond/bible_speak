/// 일일 학습 목표 모델
class DailyGoal {
  final DateTime date;
  final int targetWords;      // 목표 단어 수
  final int studiedWords;     // 학습한 단어 수
  final int targetQuizzes;    // 목표 퀴즈 수
  final int completedQuizzes; // 완료한 퀴즈 수
  final int targetFlashcards; // 목표 플래시카드 세트 수
  final int completedFlashcards; // 완료한 플래시카드 세트 수
  final bool goalAchieved;    // 목표 달성 여부
  final bool bonusClaimed;    // 보너스 달란트 수령 여부

  const DailyGoal({
    required this.date,
    this.targetWords = 10,
    this.studiedWords = 0,
    this.targetQuizzes = 1,
    this.completedQuizzes = 0,
    this.targetFlashcards = 1,
    this.completedFlashcards = 0,
    this.goalAchieved = false,
    this.bonusClaimed = false,
  });

  /// 단어 학습 진행률 (0.0 ~ 1.0)
  double get wordsProgress => targetWords > 0
      ? (studiedWords / targetWords).clamp(0.0, 1.0)
      : 0.0;

  /// 퀴즈 진행률 (0.0 ~ 1.0)
  double get quizzesProgress => targetQuizzes > 0
      ? (completedQuizzes / targetQuizzes).clamp(0.0, 1.0)
      : 0.0;

  /// 플래시카드 진행률 (0.0 ~ 1.0)
  double get flashcardsProgress => targetFlashcards > 0
      ? (completedFlashcards / targetFlashcards).clamp(0.0, 1.0)
      : 0.0;

  /// 전체 진행률 (0.0 ~ 1.0)
  double get overallProgress {
    final total = wordsProgress + quizzesProgress + flashcardsProgress;
    return total / 3.0;
  }

  /// 목표 달성 여부 체크
  bool get isGoalMet =>
      studiedWords >= targetWords &&
      completedQuizzes >= targetQuizzes &&
      completedFlashcards >= targetFlashcards;

  /// 오늘 날짜인지 확인
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  DailyGoal copyWith({
    DateTime? date,
    int? targetWords,
    int? studiedWords,
    int? targetQuizzes,
    int? completedQuizzes,
    int? targetFlashcards,
    int? completedFlashcards,
    bool? goalAchieved,
    bool? bonusClaimed,
  }) {
    return DailyGoal(
      date: date ?? this.date,
      targetWords: targetWords ?? this.targetWords,
      studiedWords: studiedWords ?? this.studiedWords,
      targetQuizzes: targetQuizzes ?? this.targetQuizzes,
      completedQuizzes: completedQuizzes ?? this.completedQuizzes,
      targetFlashcards: targetFlashcards ?? this.targetFlashcards,
      completedFlashcards: completedFlashcards ?? this.completedFlashcards,
      goalAchieved: goalAchieved ?? this.goalAchieved,
      bonusClaimed: bonusClaimed ?? this.bonusClaimed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'targetWords': targetWords,
      'studiedWords': studiedWords,
      'targetQuizzes': targetQuizzes,
      'completedQuizzes': completedQuizzes,
      'targetFlashcards': targetFlashcards,
      'completedFlashcards': completedFlashcards,
      'goalAchieved': goalAchieved,
      'bonusClaimed': bonusClaimed,
    };
  }

  factory DailyGoal.fromJson(Map<String, dynamic> json) {
    return DailyGoal(
      date: DateTime.parse(json['date'] as String),
      targetWords: json['targetWords'] as int? ?? 10,
      studiedWords: json['studiedWords'] as int? ?? 0,
      targetQuizzes: json['targetQuizzes'] as int? ?? 1,
      completedQuizzes: json['completedQuizzes'] as int? ?? 0,
      targetFlashcards: json['targetFlashcards'] as int? ?? 1,
      completedFlashcards: json['completedFlashcards'] as int? ?? 0,
      goalAchieved: json['goalAchieved'] as bool? ?? false,
      bonusClaimed: json['bonusClaimed'] as bool? ?? false,
    );
  }

  /// 오늘의 새 목표 생성
  factory DailyGoal.today({
    int targetWords = 10,
    int targetQuizzes = 1,
    int targetFlashcards = 1,
  }) {
    final now = DateTime.now();
    return DailyGoal(
      date: DateTime(now.year, now.month, now.day),
      targetWords: targetWords,
      targetQuizzes: targetQuizzes,
      targetFlashcards: targetFlashcards,
    );
  }
}

/// 일일 목표 난이도 프리셋
enum DailyGoalPreset {
  easy,    // 쉬움: 5단어, 1퀴즈, 1플래시카드
  normal,  // 보통: 10단어, 1퀴즈, 1플래시카드
  hard,    // 어려움: 20단어, 2퀴즈, 2플래시카드
  custom,  // 사용자 정의
}

extension DailyGoalPresetExtension on DailyGoalPreset {
  String get displayName {
    switch (this) {
      case DailyGoalPreset.easy:
        return '쉬움';
      case DailyGoalPreset.normal:
        return '보통';
      case DailyGoalPreset.hard:
        return '어려움';
      case DailyGoalPreset.custom:
        return '사용자 정의';
    }
  }

  String get description {
    switch (this) {
      case DailyGoalPreset.easy:
        return '5단어 · 1퀴즈 · 1플래시카드';
      case DailyGoalPreset.normal:
        return '10단어 · 1퀴즈 · 1플래시카드';
      case DailyGoalPreset.hard:
        return '20단어 · 2퀴즈 · 2플래시카드';
      case DailyGoalPreset.custom:
        return '직접 설정';
    }
  }

  int get targetWords {
    switch (this) {
      case DailyGoalPreset.easy:
        return 5;
      case DailyGoalPreset.normal:
        return 10;
      case DailyGoalPreset.hard:
        return 20;
      case DailyGoalPreset.custom:
        return 10;
    }
  }

  int get targetQuizzes {
    switch (this) {
      case DailyGoalPreset.easy:
      case DailyGoalPreset.normal:
      case DailyGoalPreset.custom:
        return 1;
      case DailyGoalPreset.hard:
        return 2;
    }
  }

  int get targetFlashcards {
    switch (this) {
      case DailyGoalPreset.easy:
      case DailyGoalPreset.normal:
      case DailyGoalPreset.custom:
        return 1;
      case DailyGoalPreset.hard:
        return 2;
    }
  }
}
