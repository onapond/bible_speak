import 'package:bible_speak/data/repositories/firestore_review_repository.dart';
import 'package:bible_speak/models/review_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore review ids are stable and path safe', () {
    final first = FirestoreReviewRepository.documentIdFor(
      userId: 'user/1',
      book: 'John',
      chapter: 3,
      verse: 16,
    );
    final second = FirestoreReviewRepository.documentIdFor(
      userId: 'user/1',
      book: 'john',
      chapter: 3,
      verse: 16,
    );

    expect(first, second);
    expect(first, startsWith('review_'));
    expect(first, isNot(contains('/')));
  });

  test('Firestore review mapper preserves the portable domain model', () {
    const mapper = FirestoreReviewItemMapper();
    final createdAt = DateTime.utc(2026, 8, 20, 9, 30);
    final nextReviewDate = DateTime.utc(2026, 8, 27);
    final item = ReviewItem(
      id: 'review-1',
      userId: 'user-1',
      verseReference: 'John 3:16',
      book: 'john',
      chapter: 3,
      verse: 16,
      verseText: 'For God so loved the world',
      easinessFactor: 2.6,
      interval: 7,
      repetitions: 3,
      nextReviewDate: nextReviewDate,
      lastReviewDate: createdAt,
      totalReviews: 4,
      correctCount: 3,
      createdAt: createdAt,
    );

    final document = mapper.toDocument(item);
    final restored = mapper.fromDocument(item.id, document);

    expect(document['schemaVersion'], 1);
    expect(document['nextReviewDate'], isA<Timestamp>());
    expect(restored.id, item.id);
    expect(restored.userId, item.userId);
    expect(restored.verseReference, item.verseReference);
    expect(restored.easinessFactor, item.easinessFactor);
    expect(restored.interval, item.interval);
    expect(restored.nextReviewDate.isAtSameMomentAs(nextReviewDate), isTrue);
    expect(restored.createdAt.isAtSameMomentAs(createdAt), isTrue);
  });

  test('Firestore review mapper remains compatible with unversioned documents',
      () {
    const mapper = FirestoreReviewItemMapper();
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 8, 25));

    final item = mapper.fromDocument('legacy-review', {
      'userId': 'legacy-user',
      'verseReference': 'Psalm 23:1',
      'book': 'psalms',
      'chapter': 23,
      'verse': 1,
      'verseText': 'The Lord is my shepherd',
      'nextReviewDate': timestamp,
      'createdAt': timestamp,
    });

    expect(item.id, 'legacy-review');
    expect(item.userId, 'legacy-user');
    expect(item.interval, 1);
    expect(item.easinessFactor, 2.5);
  });
}
