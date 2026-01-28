import 'package:cloud_firestore/cloud_firestore.dart';

/// 복습 품질 등급 (SM-2 알고리즘)
enum ReviewQuality {
  /// 완전히 잊음 (0)
  forgot,
  /// 힌트 필요 (1)
  needHint,
  /// 어렵게 기억 (2)
  hard,
  /// 보통 (3)
  normal,
  /// 쉬움 (4)
  easy,
  /// 완벽 (5)
  perfect,
}

/// 복습 아이템 모델 (SM-2 알고리즘 기반)
class ReviewItem {
  final String id;
  final String odId;
  final String verseReference; // e.g., "John 3:16"
  final String book;
  final int chapter;
  final int verse;
  final String verseText;

  // SM-2 알고리즘 필드
  final double easinessFactor; // 난이도 계수 (기본 2.5)
  final int interval; // 다음 복습까지 일수
  final int repetitions; // 연속 성공 횟수
  final DateTime nextReviewDate; // 다음 복습 날짜
  final DateTime? lastReviewDate; // 마지막 복습 날짜

  // 통계
  final int totalReviews; // 총 복습 횟수
  final int correctCount; // 정답 횟수
  final DateTime createdAt;

  const ReviewItem({
    required this.id,
    required this.odId,
    required this.verseReference,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.verseText,
    this.easinessFactor = 2.5,
    this.interval = 1,
    this.repetitions = 0,
    required this.nextReviewDate,
    this.lastReviewDate,
    this.totalReviews = 0,
    this.correctCount = 0,
    required this.createdAt,
  });

  factory ReviewItem.fromFirestore(String docId, Map<String, dynamic> data) {
    return ReviewItem(
      id: docId,
      odId: data['userId'] ?? '',
      verseReference: data['verseReference'] ?? '',
      book: data['book'] ?? '',
      chapter: data['chapter'] ?? 1,
      verse: data['verse'] ?? 1,
      verseText: data['verseText'] ?? '',
      easinessFactor: (data['easinessFactor'] ?? 2.5).toDouble(),
      interval: data['interval'] ?? 1,
      repetitions: data['repetitions'] ?? 0,
      nextReviewDate: (data['nextReviewDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastReviewDate: (data['lastReviewDate'] as Timestamp?)?.toDate(),
      totalReviews: data['totalReviews'] ?? 0,
      correctCount: data['correctCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': odId,
        'verseReference': verseReference,
        'book': book,
        'chapter': chapter,
        'verse': verse,
        'verseText': verseText,
        'easinessFactor': easinessFactor,
        'interval': interval,
        'repetitions': repetitions,
        'nextReviewDate': Timestamp.fromDate(nextReviewDate),
        'lastReviewDate': lastReviewDate != null
            ? Timestamp.fromDate(lastReviewDate!)
            : null,
        'totalReviews': totalReviews,
        'correctCount': correctCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// 복습 필요 여부
  bool get isDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDate = DateTime(
      nextReviewDate.year,
      nextReviewDate.month,
      nextReviewDate.day,
    );
    return !reviewDate.isAfter(today);
  }

  /// 정답률 (0.0 ~ 1.0)
  double get accuracy {
    if (totalReviews == 0) return 0.0;
    return correctCount / totalReviews;
  }

  /// 마스터 여부 (간격이 30일 이상이면 마스터)
  bool get isMastered => interval >= 30;

  /// 레벨 (1-5)
  int get level {
    if (interval >= 30) return 5; // 마스터
    if (interval >= 14) return 4;
    if (interval >= 7) return 3;
    if (interval >= 3) return 2;
    return 1;
  }

  /// 레벨 이름
  String get levelName {
    switch (level) {
      case 5:
        return '마스터';
      case 4:
        return '숙련';
      case 3:
        return '익숙';
      case 2:
        return '학습 중';
      default:
        return '시작';
    }
  }

  /// 레벨 색상
  int get levelColor {
    switch (level) {
      case 5:
        return 0xFFFFD700; // Gold
      case 4:
        return 0xFF9C27B0; // Purple
      case 3:
        return 0xFF2196F3; // Blue
      case 2:
        return 0xFF4CAF50; // Green
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// 복습 결과 적용 (SM-2 알고리즘)
  ReviewItem applyReview(ReviewQuality quality) {
    final q = quality.index; // 0-5
    final now = DateTime.now();

    // 새로운 값 계산
    double newEF = easinessFactor;
    int newInterval = interval;
    int newReps = repetitions;

    if (q < 3) {
      // 실패: 처음부터 다시
      newReps = 0;
      newInterval = 1;
    } else {
      // 성공
      if (newReps == 0) {
        newInterval = 1;
      } else if (newReps == 1) {
        newInterval = 6;
      } else {
        newInterval = (interval * newEF).round();
      }
      newReps++;
    }

    // 난이도 계수 업데이트
    newEF = newEF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (newEF < 1.3) newEF = 1.3;

    // 다음 복습 날짜 계산
    final nextDate = DateTime(now.year, now.month, now.day)
        .add(Duration(days: newInterval));

    return ReviewItem(
      id: id,
      odId: odId,
      verseReference: verseReference,
      book: book,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      easinessFactor: newEF,
      interval: newInterval,
      repetitions: newReps,
      nextReviewDate: nextDate,
      lastReviewDate: now,
      totalReviews: totalReviews + 1,
      correctCount: q >= 3 ? correctCount + 1 : correctCount,
      createdAt: createdAt,
    );
  }

  ReviewItem copyWith({
    double? easinessFactor,
    int? interval,
    int? repetitions,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    int? totalReviews,
    int? correctCount,
  }) {
    return ReviewItem(
      id: id,
      odId: odId,
      verseReference: verseReference,
      book: book,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      easinessFactor: easinessFactor ?? this.easinessFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      totalReviews: totalReviews ?? this.totalReviews,
      correctCount: correctCount ?? this.correctCount,
      createdAt: createdAt,
    );
  }
}

/// 복습 세션 결과
class ReviewSessionResult {
  final int totalReviewed;
  final int correctCount;
  final int masteredCount;
  final Duration duration;
  final DateTime completedAt;

  const ReviewSessionResult({
    required this.totalReviewed,
    required this.correctCount,
    required this.masteredCount,
    required this.duration,
    required this.completedAt,
  });

  double get accuracy {
    if (totalReviewed == 0) return 0.0;
    return correctCount / totalReviewed;
  }
}
