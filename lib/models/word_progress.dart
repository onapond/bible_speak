/// 단어 학습 진행 상태 (SRS 기반)
enum WordStatus {
  notStarted, // 미학습 - 한 번도 학습 안함
  learning,   // 학습중 - 간격 < 1일
  reviewing,  // 복습중 - 간격 >= 1일
  mastered,   // 마스터 - 간격 >= 21일
}

/// SRS 품질 등급 (SM-2 알고리즘)
enum ReviewQuality {
  blackout,    // 0: 완전 모름
  incorrect,   // 1: 틀림
  difficult,   // 2: 어렵게 맞춤
  correct,     // 3: 맞춤 (약간 어려움)
  easy,        // 4: 쉽게 맞춤
  perfect,     // 5: 완벽
}

/// 단어 학습 진행 모델 (SRS 포함)
class WordProgress {
  final String wordId;
  final int correctCount;
  final int totalAttempts;
  final DateTime? lastStudied;
  final WordStatus status;
  final int streak;

  // SRS 필드
  final double ease;          // 난이도 계수 (2.5 기본, 1.3 최소)
  final int interval;         // 복습 간격 (일)
  final int repetitions;      // SRS 연속 정답 횟수
  final DateTime? nextReview; // 다음 복습 날짜

  const WordProgress({
    required this.wordId,
    this.correctCount = 0,
    this.totalAttempts = 0,
    this.lastStudied,
    this.status = WordStatus.notStarted,
    this.streak = 0,
    // SRS 기본값
    this.ease = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.nextReview,
  });

  /// 정답률 (0.0 ~ 1.0)
  double get accuracy =>
      totalAttempts > 0 ? correctCount / totalAttempts : 0.0;

  /// 정답률 퍼센트
  int get accuracyPercent => (accuracy * 100).round();

  /// 암기 완료 여부
  bool get isMastered => status == WordStatus.mastered;

  /// 복습이 필요한지 여부
  bool get needsReview {
    if (nextReview == null) return status != WordStatus.notStarted;
    return DateTime.now().isAfter(nextReview!);
  }

  /// 복습까지 남은 시간 (음수면 이미 지남)
  Duration? get timeUntilReview {
    if (nextReview == null) return null;
    return nextReview!.difference(DateTime.now());
  }

  /// 복습 상태 텍스트
  String get reviewStatusText {
    if (status == WordStatus.notStarted) return '미학습';
    if (nextReview == null) return '학습 필요';

    final diff = timeUntilReview!;
    if (diff.isNegative) {
      final overdue = diff.abs();
      if (overdue.inDays > 0) return '${overdue.inDays}일 지남';
      if (overdue.inHours > 0) return '${overdue.inHours}시간 지남';
      return '복습 필요';
    }

    if (diff.inDays > 0) return '${diff.inDays}일 후';
    if (diff.inHours > 0) return '${diff.inHours}시간 후';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 후';
    return '곧 복습';
  }

  /// JSON 변환 (저장용)
  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'correctCount': correctCount,
        'totalAttempts': totalAttempts,
        'lastStudied': lastStudied?.toIso8601String(),
        'status': status.index,
        'streak': streak,
        // SRS
        'ease': ease,
        'interval': interval,
        'repetitions': repetitions,
        'nextReview': nextReview?.toIso8601String(),
      };

  /// JSON에서 생성
  factory WordProgress.fromJson(Map<String, dynamic> json) {
    return WordProgress(
      wordId: json['wordId'] as String,
      correctCount: json['correctCount'] as int? ?? 0,
      totalAttempts: json['totalAttempts'] as int? ?? 0,
      lastStudied: json['lastStudied'] != null
          ? DateTime.parse(json['lastStudied'] as String)
          : null,
      status: WordStatus.values[json['status'] as int? ?? 0],
      streak: json['streak'] as int? ?? 0,
      // SRS
      ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
      interval: json['interval'] as int? ?? 0,
      repetitions: json['repetitions'] as int? ?? 0,
      nextReview: json['nextReview'] != null
          ? DateTime.parse(json['nextReview'] as String)
          : null,
    );
  }

  /// 복사본 생성
  WordProgress copyWith({
    int? correctCount,
    int? totalAttempts,
    DateTime? lastStudied,
    WordStatus? status,
    int? streak,
    double? ease,
    int? interval,
    int? repetitions,
    DateTime? nextReview,
  }) {
    return WordProgress(
      wordId: wordId,
      correctCount: correctCount ?? this.correctCount,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      lastStudied: lastStudied ?? this.lastStudied,
      status: status ?? this.status,
      streak: streak ?? this.streak,
      ease: ease ?? this.ease,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReview: nextReview ?? this.nextReview,
    );
  }
}

/// SM-2 SRS 알고리즘 계산기
class SRSCalculator {
  /// SM-2 알고리즘으로 다음 복습 정보 계산
  /// quality: 0 (완전 모름) ~ 5 (완벽)
  static WordProgress calculate(WordProgress progress, int quality) {
    final now = DateTime.now();

    // 품질이 3 미만이면 틀린 것으로 처리 (처음부터 다시)
    if (quality < 3) {
      return progress.copyWith(
        repetitions: 0,
        interval: 0,
        // 10분 후 다시 복습
        nextReview: now.add(const Duration(minutes: 10)),
        lastStudied: now,
        totalAttempts: progress.totalAttempts + 1,
        streak: 0,
        status: WordStatus.learning,
      );
    }

    // 정답 처리
    int newRepetitions = progress.repetitions + 1;
    int newInterval;

    if (newRepetitions == 1) {
      // 첫 번째 정답: 1일 후
      newInterval = 1;
    } else if (newRepetitions == 2) {
      // 두 번째 정답: 6일 후
      newInterval = 6;
    } else {
      // 그 이후: 이전 간격 * ease
      newInterval = (progress.interval * progress.ease).round();
    }

    // ease 조정 (SM-2 공식)
    double newEase = progress.ease +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEase < 1.3) newEase = 1.3; // 최소값

    // 상태 결정
    WordStatus newStatus;
    if (newInterval >= 21) {
      newStatus = WordStatus.mastered;
    } else if (newInterval >= 1) {
      newStatus = WordStatus.reviewing;
    } else {
      newStatus = WordStatus.learning;
    }

    return progress.copyWith(
      repetitions: newRepetitions,
      interval: newInterval,
      ease: newEase,
      nextReview: now.add(Duration(days: newInterval)),
      lastStudied: now,
      correctCount: progress.correctCount + 1,
      totalAttempts: progress.totalAttempts + 1,
      streak: progress.streak + 1,
      status: newStatus,
    );
  }

  /// 간단한 정답/오답으로 계산 (플래시카드용)
  /// known: true = quality 4, false = quality 1
  static WordProgress calculateSimple(WordProgress progress, bool isCorrect) {
    return calculate(progress, isCorrect ? 4 : 1);
  }

  /// 플래시카드 3단계 평가
  /// 'known' = 5, 'vague' = 3, 'unknown' = 1
  static WordProgress calculateFromFlashcard(WordProgress progress, String answer) {
    int quality;
    switch (answer) {
      case 'known':
        quality = 5;
        break;
      case 'vague':
        quality = 3;
        break;
      case 'unknown':
      default:
        quality = 1;
    }
    return calculate(progress, quality);
  }
}

/// 퀴즈 결과 모델
class QuizResult {
  final String id;
  final String bookId;
  final int chapter;
  final int totalQuestions;
  final int correctAnswers;
  final List<String> wrongWordIds;
  final int earnedTalants;
  final DateTime completedAt;

  const QuizResult({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongWordIds,
    required this.earnedTalants,
    required this.completedAt,
  });

  /// 정답률 퍼센트
  int get scorePercent =>
      totalQuestions > 0 ? (correctAnswers * 100 / totalQuestions).round() : 0;

  /// 통과 여부 (70% 이상)
  bool get isPassed => scorePercent >= 70;
}
