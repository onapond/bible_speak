/// 단어 학습 진행 상태
enum WordStatus {
  notStarted, // 미학습
  learning, // 학습중
  mastered, // 암기완료
}

/// 단어 학습 진행 모델
class WordProgress {
  final String wordId;
  final int correctCount;
  final int totalAttempts;
  final DateTime? lastStudied;
  final WordStatus status;
  final int streak;

  const WordProgress({
    required this.wordId,
    this.correctCount = 0,
    this.totalAttempts = 0,
    this.lastStudied,
    this.status = WordStatus.notStarted,
    this.streak = 0,
  });

  /// 정답률 (0.0 ~ 1.0)
  double get accuracy =>
      totalAttempts > 0 ? correctCount / totalAttempts : 0.0;

  /// 정답률 퍼센트
  int get accuracyPercent => (accuracy * 100).round();

  /// 암기 완료 여부
  bool get isMastered => status == WordStatus.mastered;

  /// JSON 변환 (저장용)
  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'correctCount': correctCount,
        'totalAttempts': totalAttempts,
        'lastStudied': lastStudied?.toIso8601String(),
        'status': status.index,
        'streak': streak,
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
    );
  }

  /// 복사본 생성
  WordProgress copyWith({
    int? correctCount,
    int? totalAttempts,
    DateTime? lastStudied,
    WordStatus? status,
    int? streak,
  }) {
    return WordProgress(
      wordId: wordId,
      correctCount: correctCount ?? this.correctCount,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      lastStudied: lastStudied ?? this.lastStudied,
      status: status ?? this.status,
      streak: streak ?? this.streak,
    );
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
