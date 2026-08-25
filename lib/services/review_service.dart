import '../data/repositories/review_repository.dart';
import '../models/review_item.dart';

/// 복습 스케줄 서비스 (Spaced Repetition)
class ReviewService {
  final ReviewRepository _repository;
  final String? Function() _currentUserId;
  final DateTime Function() _now;

  ReviewService({
    required ReviewRepository repository,
    required String? Function() currentUserId,
    DateTime Function()? now,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        _now = now ?? DateTime.now;

  String? get currentUserId => _currentUserId();

  /// 복습 아이템 추가 (새로운 구절 학습 시)
  Future<ReviewItem?> addReviewItem({
    required String verseReference,
    required String book,
    required int chapter,
    required int verse,
    required String verseText,
  }) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final existing = await _repository.findByReference(
        userId: userId,
        verseReference: verseReference,
      );
      if (existing != null) return existing;

      final now = _now();
      return await _repository.createOrGet(
        userId: userId,
        verseReference: verseReference,
        book: book,
        chapter: chapter,
        verse: verse,
        verseText: verseText,
        createdAt: now,
      );
    } catch (e) {
      print('Add review item error: $e');
      return null;
    }
  }

  /// 오늘 복습할 아이템 목록
  Future<List<ReviewItem>> getDueItems({int limit = 20}) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final now = _now();
      final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return await _repository.findDue(
        userId: userId,
        dueBefore: today,
        limit: limit,
      );
    } catch (e) {
      print('Get due items error: $e');
      return [];
    }
  }

  /// 오늘 복습할 아이템 개수
  Future<int> getDueCount() async {
    final userId = currentUserId;
    if (userId == null) return 0;

    try {
      final now = _now();
      final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return await _repository.countDue(userId: userId, dueBefore: today);
    } catch (e) {
      print('Get due count error: $e');
      return 0;
    }
  }

  /// 복습 결과 저장 (set + merge로 안전하게)
  Future<ReviewItem?> submitReview(
      ReviewItem item, ReviewQuality quality) async {
    final userId = currentUserId;
    if (userId == null || item.userId != userId) return null;

    try {
      final updated = item.applyReview(quality, reviewedAt: _now());
      await _repository.save(userId: userId, item: updated);
      return updated;
    } catch (e) {
      print('Submit review error: $e');
      return null;
    }
  }

  /// 모든 복습 아이템 가져오기
  Future<List<ReviewItem>> getAllItems() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      return await _repository.findAll(userId: userId);
    } catch (e) {
      print('Get all items error: $e');
      return [];
    }
  }

  /// 마스터한 아이템 가져오기
  Future<List<ReviewItem>> getMasteredItems() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      return await _repository.findMastered(
        userId: userId,
        minimumIntervalDays: 30,
      );
    } catch (e) {
      print('Get mastered items error: $e');
      return [];
    }
  }

  /// 복습 통계
  Future<ReviewStats> getStats() async {
    final userId = currentUserId;
    if (userId == null) return const ReviewStats();

    try {
      final now = _now();
      final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final allItems = await _repository.findAll(userId: userId);
      final dueCount = await _repository.countDue(
        userId: userId,
        dueBefore: today,
      );

      int totalItems = allItems.length;
      int masteredCount = 0;
      int learningCount = 0;
      int totalReviews = 0;
      int totalCorrect = 0;

      for (final item in allItems) {
        totalReviews += item.totalReviews;
        totalCorrect += item.correctCount;

        if (item.isMastered) {
          masteredCount++;
        } else {
          learningCount++;
        }
      }

      return ReviewStats(
        totalItems: totalItems,
        dueCount: dueCount,
        masteredCount: masteredCount,
        learningCount: learningCount,
        totalReviews: totalReviews,
        totalCorrect: totalCorrect,
      );
    } catch (e) {
      print('Get stats error: $e');
      return const ReviewStats();
    }
  }

  /// 특정 구절의 복습 아이템 가져오기
  Future<ReviewItem?> getItemByReference(String verseReference) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      return await _repository.findByReference(
        userId: userId,
        verseReference: verseReference,
      );
    } catch (e) {
      print('Get item by reference error: $e');
      return null;
    }
  }

  /// 복습 아이템 삭제
  Future<bool> deleteItem(String itemId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      return await _repository.delete(userId: userId, itemId: itemId);
    } catch (e) {
      print('Delete item error: $e');
      return false;
    }
  }

  /// 앞으로 7일간의 복습 예정 수
  Future<Map<String, int>> getUpcomingSchedule() async {
    final userId = currentUserId;
    if (userId == null) return {};

    try {
      final now = _now();
      final weekLater = now.add(const Duration(days: 7));
      final items = await _repository.findScheduled(
        userId: userId,
        after: now,
        through: weekLater,
      );

      final schedule = <String, int>{};

      for (final item in items) {
        final dateKey =
            '${item.nextReviewDate.month}/${item.nextReviewDate.day}';
        schedule[dateKey] = (schedule[dateKey] ?? 0) + 1;
      }

      return schedule;
    } catch (e) {
      print('Get upcoming schedule error: $e');
      return {};
    }
  }
}

/// 복습 통계
class ReviewStats {
  final int totalItems;
  final int dueCount;
  final int masteredCount;
  final int learningCount;
  final int totalReviews;
  final int totalCorrect;

  const ReviewStats({
    this.totalItems = 0,
    this.dueCount = 0,
    this.masteredCount = 0,
    this.learningCount = 0,
    this.totalReviews = 0,
    this.totalCorrect = 0,
  });

  double get accuracy {
    if (totalReviews == 0) return 0.0;
    return totalCorrect / totalReviews;
  }

  double get masteryRate {
    if (totalItems == 0) return 0.0;
    return masteredCount / totalItems;
  }
}
