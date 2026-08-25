import 'package:bible_speak/data/repositories/review_repository.dart';
import 'package:bible_speak/models/review_item.dart';
import 'package:bible_speak/services/review_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 25, 10);

  group('ReviewService repository boundary', () {
    test('does not access storage without an authenticated user', () async {
      final repository = _FakeReviewRepository();
      final service = ReviewService(
        repository: repository,
        currentUserId: () => null,
        now: () => now,
      );

      expect(await service.getDueItems(), isEmpty);
      expect(
          await service.addReviewItem(
            verseReference: 'John 3:16',
            book: 'john',
            chapter: 3,
            verse: 16,
            verseText: 'For God so loved the world',
          ),
          isNull);
      expect(repository.readCount, 0);
      expect(repository.writeCount, 0);
    });

    test('creates a review through the repository using a portable user id',
        () async {
      final repository = _FakeReviewRepository();
      final service = ReviewService(
        repository: repository,
        currentUserId: () => 'user-1',
        now: () => now,
      );

      final item = await service.addReviewItem(
        verseReference: 'John 3:16',
        book: 'john',
        chapter: 3,
        verse: 16,
        verseText: 'For God so loved the world',
      );

      expect(item, isNotNull);
      expect(item!.userId, 'user-1');
      expect(item.id, 'review-1');
      expect(item.createdAt, now);
      expect(repository.writeCount, 1);
    });

    test('returns an existing review instead of creating a duplicate',
        () async {
      final existing = _item(userId: 'user-1', now: now);
      final repository = _FakeReviewRepository()..items.add(existing);
      final service = ReviewService(
        repository: repository,
        currentUserId: () => 'user-1',
        now: () => now,
      );

      final item = await service.addReviewItem(
        verseReference: existing.verseReference,
        book: existing.book,
        chapter: existing.chapter,
        verse: existing.verse,
        verseText: existing.verseText,
      );

      expect(item, same(existing));
      expect(repository.writeCount, 0);
    });

    test('concurrent creates converge through the repository contract',
        () async {
      final repository = _FakeReviewRepository();
      final service = ReviewService(
        repository: repository,
        currentUserId: () => 'user-1',
        now: () => now,
      );

      Future<ReviewItem?> add() => service.addReviewItem(
            verseReference: 'John 3:16',
            book: 'john',
            chapter: 3,
            verse: 16,
            verseText: 'For God so loved the world',
          );

      final results = await Future.wait([add(), add()]);

      expect(results[0]!.id, results[1]!.id);
      expect(repository.items, hasLength(1));
      expect(repository.writeCount, 1);
    });

    test('passes an end-of-day due boundary to the repository', () async {
      final repository = _FakeReviewRepository();
      final service = ReviewService(
        repository: repository,
        currentUserId: () => 'user-1',
        now: () => now,
      );

      await service.getDueItems(limit: 7);

      expect(repository.lastUserId, 'user-1');
      expect(repository.lastLimit, 7);
      expect(repository.lastDueBefore, DateTime(2026, 8, 25, 23, 59, 59));
    });

    test('rejects a review owned by another account before saving', () async {
      final repository = _FakeReviewRepository();
      final service = ReviewService(
        repository: repository,
        currentUserId: () => 'user-1',
        now: () => now,
      );

      final result = await service.submitReview(
        _item(userId: 'user-2', now: now),
        ReviewQuality.perfect,
      );

      expect(result, isNull);
      expect(repository.writeCount, 0);
    });

    test('saves an owned review with the injected clock', () async {
      final original = _item(userId: 'user-1', now: now);
      final repository = _FakeReviewRepository()..items.add(original);
      final service = ReviewService(
        repository: repository,
        currentUserId: () => 'user-1',
        now: () => now,
      );

      final result = await service.submitReview(
        original,
        ReviewQuality.perfect,
      );

      expect(result, isNotNull);
      expect(result!.lastReviewDate, now);
      expect(result.totalReviews, 1);
      expect(result.correctCount, 1);
      expect(repository.writeCount, 1);
    });

    test('aggregates review stats without backend-specific types', () async {
      final repository = _FakeReviewRepository()
        ..items.addAll([
          _item(
            id: 'learning',
            userId: 'user-1',
            now: now,
            interval: 6,
            totalReviews: 4,
            correctCount: 3,
          ),
          _item(
            id: 'mastered',
            userId: 'user-1',
            now: now,
            interval: 30,
            totalReviews: 6,
            correctCount: 5,
          ),
        ]);
      final service = ReviewService(
        repository: repository,
        currentUserId: () => 'user-1',
        now: () => now,
      );

      final stats = await service.getStats();

      expect(stats.totalItems, 2);
      expect(stats.learningCount, 1);
      expect(stats.masteredCount, 1);
      expect(stats.totalReviews, 10);
      expect(stats.totalCorrect, 8);
    });
  });
}

ReviewItem _item({
  String id = 'review-1',
  required String userId,
  required DateTime now,
  int interval = 1,
  int totalReviews = 0,
  int correctCount = 0,
}) {
  return ReviewItem(
    id: id,
    userId: userId,
    verseReference: 'John 3:16',
    book: 'john',
    chapter: 3,
    verse: 16,
    verseText: 'For God so loved the world',
    interval: interval,
    nextReviewDate: now,
    totalReviews: totalReviews,
    correctCount: correctCount,
    createdAt: now,
  );
}

class _FakeReviewRepository implements ReviewRepository {
  final List<ReviewItem> items = [];
  int readCount = 0;
  int writeCount = 0;
  String? lastUserId;
  DateTime? lastDueBefore;
  int? lastLimit;

  @override
  Future<ReviewItem?> findByReference({
    required String userId,
    required String verseReference,
  }) async {
    readCount++;
    return items
        .where(
          (item) =>
              item.userId == userId && item.verseReference == verseReference,
        )
        .firstOrNull;
  }

  @override
  Future<ReviewItem> createOrGet({
    required String userId,
    required String verseReference,
    required String book,
    required int chapter,
    required int verse,
    required String verseText,
    required DateTime createdAt,
  }) async {
    final existing = items.where(
      (item) =>
          item.userId == userId &&
          item.book == book &&
          item.chapter == chapter &&
          item.verse == verse,
    );
    if (existing.isNotEmpty) return existing.first;

    writeCount++;
    final item = ReviewItem(
      id: 'review-${items.length + 1}',
      userId: userId,
      verseReference: verseReference,
      book: book,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      nextReviewDate: createdAt,
      createdAt: createdAt,
    );
    items.add(item);
    return item;
  }

  @override
  Future<List<ReviewItem>> findDue({
    required String userId,
    required DateTime dueBefore,
    required int limit,
  }) async {
    readCount++;
    lastUserId = userId;
    lastDueBefore = dueBefore;
    lastLimit = limit;
    return items
        .where(
          (item) =>
              item.userId == userId && !item.nextReviewDate.isAfter(dueBefore),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<int> countDue({
    required String userId,
    required DateTime dueBefore,
  }) async {
    readCount++;
    return items
        .where(
          (item) =>
              item.userId == userId && !item.nextReviewDate.isAfter(dueBefore),
        )
        .length;
  }

  @override
  Future<List<ReviewItem>> findAll({required String userId}) async {
    readCount++;
    return items.where((item) => item.userId == userId).toList();
  }

  @override
  Future<List<ReviewItem>> findMastered({
    required String userId,
    required int minimumIntervalDays,
  }) async {
    readCount++;
    return items
        .where(
          (item) =>
              item.userId == userId && item.interval >= minimumIntervalDays,
        )
        .toList();
  }

  @override
  Future<void> save({
    required String userId,
    required ReviewItem item,
  }) async {
    if (item.userId != userId) throw StateError('wrong owner');
    writeCount++;
    final index = items.indexWhere((current) => current.id == item.id);
    if (index >= 0) items[index] = item;
  }

  @override
  Future<bool> delete({
    required String userId,
    required String itemId,
  }) async {
    final index = items.indexWhere(
      (item) => item.id == itemId && item.userId == userId,
    );
    if (index < 0) return false;
    items.removeAt(index);
    writeCount++;
    return true;
  }

  @override
  Future<List<ReviewItem>> findScheduled({
    required String userId,
    required DateTime after,
    required DateTime through,
  }) async {
    readCount++;
    return items
        .where(
          (item) =>
              item.userId == userId &&
              item.nextReviewDate.isAfter(after) &&
              !item.nextReviewDate.isAfter(through),
        )
        .toList();
  }
}
