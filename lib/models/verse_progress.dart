import 'package:cloud_firestore/cloud_firestore.dart';
import 'learning_stage.dart';

/// 구절별 학습 진행 상태
class VerseProgress {
  final String bookId;
  final int chapter;
  final int verse;
  final LearningStage currentStage;
  final Map<LearningStage, StageProgress> stages;
  final bool isCompleted;
  final DateTime? completedAt;

  VerseProgress({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.currentStage,
    required this.stages,
    this.isCompleted = false,
    this.completedAt,
  });

  /// 구절 참조 키 (예: "malachi_1_2")
  String get verseKey => '${bookId}_${chapter}_$verse';

  /// 현재 스테이지의 최고 점수
  double get currentStageBestScore =>
      stages[currentStage]?.bestScore ?? 0.0;

  /// 전체 최고 점수 (모든 스테이지 중)
  double get overallBestScore {
    if (stages.isEmpty) return 0.0;
    return stages.values
        .map((s) => s.bestScore)
        .reduce((a, b) => a > b ? a : b);
  }

  /// 현재 스테이지 통과 여부
  bool get isCurrentStagePassed =>
      currentStage.isPassed(currentStageBestScore);

  /// 다음 스테이지가 잠금 해제되었는지
  bool get isNextStageUnlocked =>
      isCurrentStagePassed && currentStage.nextStage != null;

  /// 빈 진행 상태 생성
  factory VerseProgress.empty({
    required String bookId,
    required int chapter,
    required int verse,
  }) {
    return VerseProgress(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      currentStage: LearningStage.listenRepeat,
      stages: {},
    );
  }

  /// Firestore 데이터로부터 생성
  factory VerseProgress.fromMap(
    Map<String, dynamic> map, {
    required String bookId,
    required int chapter,
    required int verse,
  }) {
    final stagesMap = <LearningStage, StageProgress>{};

    if (map['stages'] != null) {
      final stagesData = map['stages'] as Map<String, dynamic>;
      for (final entry in stagesData.entries) {
        final stageNumber = int.tryParse(entry.key);
        if (stageNumber != null) {
          final stage = LearningStage.fromNumber(stageNumber);
          stagesMap[stage] = StageProgress.fromMap(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    return VerseProgress(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      currentStage: LearningStage.fromNumber(map['currentStage'] ?? 1),
      stages: stagesMap,
      isCompleted: map['isCompleted'] ?? false,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Firestore 저장용 Map으로 변환
  Map<String, dynamic> toMap() {
    final stagesData = <String, dynamic>{};
    for (final entry in stages.entries) {
      stagesData[entry.key.stageNumber.toString()] = entry.value.toMap();
    }

    return {
      'currentStage': currentStage.stageNumber,
      'stages': stagesData,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }

  /// 점수 업데이트 후 새 인스턴스 반환
  VerseProgress withScoreUpdate(LearningStage stage, double score) {
    final updatedStages = Map<LearningStage, StageProgress>.from(stages);
    final currentProgress = updatedStages[stage] ?? StageProgress.empty();

    updatedStages[stage] = currentProgress.withNewScore(score);

    // 스테이지 통과 시 다음 스테이지로 이동
    LearningStage newCurrentStage = currentStage;
    if (stage == currentStage && stage.isPassed(score)) {
      if (stage.nextStage != null) {
        newCurrentStage = stage.nextStage!;
      }
    }

    // 마지막 스테이지 통과 시 완료 처리
    final nowCompleted = stage == LearningStage.realSpeak &&
        stage.isPassed(score);

    return VerseProgress(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      currentStage: newCurrentStage,
      stages: updatedStages,
      isCompleted: isCompleted || nowCompleted,
      completedAt: nowCompleted && completedAt == null
          ? DateTime.now()
          : completedAt,
    );
  }

  @override
  String toString() {
    return 'VerseProgress($verseKey, stage: ${currentStage.koreanName}, '
        'completed: $isCompleted)';
  }
}

/// 스테이지별 진행 상태
class StageProgress {
  final int attempts;
  final double bestScore;
  final double lastScore;
  final DateTime? lastAttemptAt;

  StageProgress({
    required this.attempts,
    required this.bestScore,
    required this.lastScore,
    this.lastAttemptAt,
  });

  /// 빈 상태 생성
  factory StageProgress.empty() {
    return StageProgress(
      attempts: 0,
      bestScore: 0.0,
      lastScore: 0.0,
    );
  }

  /// Map으로부터 생성
  factory StageProgress.fromMap(Map<String, dynamic> map) {
    return StageProgress(
      attempts: map['attempts'] ?? 0,
      bestScore: (map['bestScore'] ?? 0.0).toDouble(),
      lastScore: (map['lastScore'] ?? 0.0).toDouble(),
      lastAttemptAt: map['lastAttemptAt'] != null
          ? (map['lastAttemptAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'attempts': attempts,
      'bestScore': bestScore,
      'lastScore': lastScore,
      'lastAttemptAt': lastAttemptAt != null
          ? Timestamp.fromDate(lastAttemptAt!)
          : null,
    };
  }

  /// 새 점수로 업데이트한 인스턴스 반환
  StageProgress withNewScore(double score) {
    return StageProgress(
      attempts: attempts + 1,
      bestScore: score > bestScore ? score : bestScore,
      lastScore: score,
      lastAttemptAt: DateTime.now(),
    );
  }
}

/// 챕터 진행 요약
class ChapterProgress {
  final String bookId;
  final int chapter;
  final int totalVerses;
  final int completedVerses;
  final int inProgressVerses;
  final double averageScore;

  ChapterProgress({
    required this.bookId,
    required this.chapter,
    required this.totalVerses,
    required this.completedVerses,
    required this.inProgressVerses,
    required this.averageScore,
  });

  /// 진척률 (0.0 ~ 1.0)
  double get progressRate =>
      totalVerses > 0 ? completedVerses / totalVerses : 0.0;

  /// 진척률 퍼센트
  int get progressPercent => (progressRate * 100).round();

  /// 상태 (완료 / 진행중 / 미시작)
  ChapterStatus get status {
    if (completedVerses == totalVerses) return ChapterStatus.completed;
    if (completedVerses > 0 || inProgressVerses > 0) {
      return ChapterStatus.inProgress;
    }
    return ChapterStatus.notStarted;
  }
}

/// 챕터 상태
enum ChapterStatus {
  notStarted,
  inProgress,
  completed,
}
