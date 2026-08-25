import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../../models/review_item.dart';
import 'review_repository.dart';

/// Firestore의 `reviews` 컬렉션을 [ReviewRepository] 계약에 연결한다.
class FirestoreReviewRepository implements ReviewRepository {
  final FirebaseFirestore _firestore;
  final FirestoreReviewItemMapper _mapper;

  FirestoreReviewRepository({
    FirebaseFirestore? firestore,
    FirestoreReviewItemMapper mapper = const FirestoreReviewItemMapper(),
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _mapper = mapper;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('reviews');

  @override
  Future<ReviewItem?> findByReference({
    required String userId,
    required String verseReference,
  }) async {
    final snapshot = await _reviews
        .where('userId', isEqualTo: userId)
        .where('verseReference', isEqualTo: verseReference)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return _mapper.fromDocument(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
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
    final document = _reviews.doc(
      documentIdFor(
        userId: userId,
        book: book,
        chapter: chapter,
        verse: verse,
      ),
    );
    return _firestore.runTransaction((transaction) async {
      final current = await transaction.get(document);
      if (current.exists) {
        final existing = _mapper.fromDocument(
          current.id,
          current.data()!,
        );
        final sameOwnerAndVerse = existing.userId == userId &&
            existing.book.toLowerCase() == book.toLowerCase() &&
            existing.chapter == chapter &&
            existing.verse == verse;
        if (!sameOwnerAndVerse) {
          throw StateError('Stable review id collision detected.');
        }
        return existing;
      }

      final item = ReviewItem(
        id: document.id,
        userId: userId,
        verseReference: verseReference,
        book: book,
        chapter: chapter,
        verse: verse,
        verseText: verseText,
        nextReviewDate: createdAt,
        createdAt: createdAt,
      );
      transaction.set(document, _mapper.toDocument(item));
      return item;
    });
  }

  /// Stable IDs make concurrent writes to the same user and verse converge on
  /// one Firestore document. Existing random IDs remain readable.
  static String documentIdFor({
    required String userId,
    required String book,
    required int chapter,
    required int verse,
  }) {
    final canonicalVerse = '${book.toLowerCase()}:$chapter:$verse';
    final digest = sha256.convert(utf8.encode('$userId\u0000$canonicalVerse'));
    return 'review_$digest';
  }

  @override
  Future<List<ReviewItem>> findDue({
    required String userId,
    required DateTime dueBefore,
    required int limit,
  }) async {
    final snapshot = await _reviews
        .where('userId', isEqualTo: userId)
        .where(
          'nextReviewDate',
          isLessThanOrEqualTo: Timestamp.fromDate(dueBefore),
        )
        .orderBy('nextReviewDate')
        .limit(limit)
        .get();
    return _items(snapshot.docs);
  }

  @override
  Future<int> countDue({
    required String userId,
    required DateTime dueBefore,
  }) async {
    final snapshot = await _reviews
        .where('userId', isEqualTo: userId)
        .where(
          'nextReviewDate',
          isLessThanOrEqualTo: Timestamp.fromDate(dueBefore),
        )
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Future<List<ReviewItem>> findAll({required String userId}) async {
    final snapshot = await _reviews
        .where('userId', isEqualTo: userId)
        .orderBy('nextReviewDate')
        .get();
    return _items(snapshot.docs);
  }

  @override
  Future<List<ReviewItem>> findMastered({
    required String userId,
    required int minimumIntervalDays,
  }) async {
    final snapshot = await _reviews
        .where('userId', isEqualTo: userId)
        .where('interval', isGreaterThanOrEqualTo: minimumIntervalDays)
        .get();
    return _items(snapshot.docs);
  }

  @override
  Future<void> save({
    required String userId,
    required ReviewItem item,
  }) async {
    if (item.userId != userId) {
      throw StateError('Cannot save another user\'s review item.');
    }

    final document = _reviews.doc(item.id);
    final current = await document.get();
    if (!current.exists || current.data()?['userId'] != userId) {
      throw StateError('Review item does not belong to the current user.');
    }

    await document.set(
      _mapper.toDocument(item),
      SetOptions(merge: true),
    );
  }

  @override
  Future<bool> delete({
    required String userId,
    required String itemId,
  }) async {
    final document = _reviews.doc(itemId);
    final current = await document.get();
    if (!current.exists || current.data()?['userId'] != userId) return false;

    await document.delete();
    return true;
  }

  @override
  Future<List<ReviewItem>> findScheduled({
    required String userId,
    required DateTime after,
    required DateTime through,
  }) async {
    final snapshot = await _reviews
        .where('userId', isEqualTo: userId)
        .where('nextReviewDate', isGreaterThan: Timestamp.fromDate(after))
        .where(
          'nextReviewDate',
          isLessThanOrEqualTo: Timestamp.fromDate(through),
        )
        .get();
    return _items(snapshot.docs);
  }

  List<ReviewItem> _items(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return documents
        .map((document) => _mapper.fromDocument(document.id, document.data()))
        .toList(growable: false);
  }
}

/// Firestore wire format is kept outside the domain model so a SQL/API adapter
/// can use its own mapper without importing Firebase packages.
class FirestoreReviewItemMapper {
  static const int currentSchemaVersion = 1;

  const FirestoreReviewItemMapper();

  ReviewItem fromDocument(String documentId, Map<String, dynamic> data) {
    final now = DateTime.now();
    return ReviewItem(
      id: documentId,
      userId: data['userId'] as String? ?? '',
      verseReference: data['verseReference'] as String? ?? '',
      book: data['book'] as String? ?? '',
      chapter: data['chapter'] as int? ?? 1,
      verse: data['verse'] as int? ?? 1,
      verseText: data['verseText'] as String? ?? '',
      easinessFactor: (data['easinessFactor'] as num? ?? 2.5).toDouble(),
      interval: data['interval'] as int? ?? 1,
      repetitions: data['repetitions'] as int? ?? 0,
      nextReviewDate: _date(data['nextReviewDate']) ?? now,
      lastReviewDate: _date(data['lastReviewDate']),
      totalReviews: data['totalReviews'] as int? ?? 0,
      correctCount: data['correctCount'] as int? ?? 0,
      createdAt: _date(data['createdAt']) ?? now,
    );
  }

  Map<String, dynamic> toDocument(ReviewItem item) {
    return {
      'schemaVersion': currentSchemaVersion,
      'userId': item.userId,
      'verseReference': item.verseReference,
      'book': item.book,
      'chapter': item.chapter,
      'verse': item.verse,
      'verseText': item.verseText,
      'easinessFactor': item.easinessFactor,
      'interval': item.interval,
      'repetitions': item.repetitions,
      'nextReviewDate': Timestamp.fromDate(item.nextReviewDate),
      'lastReviewDate': item.lastReviewDate == null
          ? null
          : Timestamp.fromDate(item.lastReviewDate!),
      'totalReviews': item.totalReviews,
      'correctCount': item.correctCount,
      'createdAt': Timestamp.fromDate(item.createdAt),
    };
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
