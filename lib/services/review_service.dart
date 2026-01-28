import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review_item.dart';

/// 복습 스케줄 서비스 (Spaced Repetition)
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _reviewCollection =>
      _firestore.collection('reviews');

  /// 복습 아이템 추가 (새로운 구절 학습 시)
  Future<ReviewItem?> addReviewItem({
    required String verseReference,
    required String book,
    required int chapter,
    required int verse,
    required String verseText,
  }) async {
    final odId = currentUserId;
    if (odId == null) return null;

    try {
      // 이미 존재하는지 확인
      final existing = await _reviewCollection
          .where('userId', isEqualTo: odId)
          .where('verseReference', isEqualTo: verseReference)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return ReviewItem.fromFirestore(
          existing.docs.first.id,
          existing.docs.first.data(),
        );
      }

      // 새 아이템 생성
      final now = DateTime.now();
      final docRef = _reviewCollection.doc();

      final item = ReviewItem(
        id: docRef.id,
        odId: odId,
        verseReference: verseReference,
        book: book,
        chapter: chapter,
        verse: verse,
        verseText: verseText,
        nextReviewDate: now, // 오늘부터 복습 시작
        createdAt: now,
      );

      await docRef.set(item.toFirestore());
      return item;
    } catch (e) {
      print('Add review item error: $e');
      return null;
    }
  }

  /// 오늘 복습할 아이템 목록
  Future<List<ReviewItem>> getDueItems({int limit = 20}) async {
    final odId = currentUserId;
    if (odId == null) return [];

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _reviewCollection
          .where('userId', isEqualTo: odId)
          .where('nextReviewDate', isLessThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('nextReviewDate')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ReviewItem.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Get due items error: $e');
      return [];
    }
  }

  /// 오늘 복습할 아이템 개수
  Future<int> getDueCount() async {
    final odId = currentUserId;
    if (odId == null) return 0;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _reviewCollection
          .where('userId', isEqualTo: odId)
          .where('nextReviewDate', isLessThanOrEqualTo: Timestamp.fromDate(today))
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Get due count error: $e');
      return 0;
    }
  }

  /// 복습 결과 저장
  Future<ReviewItem?> submitReview(ReviewItem item, ReviewQuality quality) async {
    try {
      final updated = item.applyReview(quality);
      await _reviewCollection.doc(item.id).update(updated.toFirestore());
      return updated;
    } catch (e) {
      print('Submit review error: $e');
      return null;
    }
  }

  /// 모든 복습 아이템 가져오기
  Future<List<ReviewItem>> getAllItems() async {
    final odId = currentUserId;
    if (odId == null) return [];

    try {
      final snapshot = await _reviewCollection
          .where('userId', isEqualTo: odId)
          .orderBy('nextReviewDate')
          .get();

      return snapshot.docs
          .map((doc) => ReviewItem.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Get all items error: $e');
      return [];
    }
  }

  /// 마스터한 아이템 가져오기
  Future<List<ReviewItem>> getMasteredItems() async {
    final odId = currentUserId;
    if (odId == null) return [];

    try {
      final snapshot = await _reviewCollection
          .where('userId', isEqualTo: odId)
          .where('interval', isGreaterThanOrEqualTo: 30)
          .get();

      return snapshot.docs
          .map((doc) => ReviewItem.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Get mastered items error: $e');
      return [];
    }
  }

  /// 복습 통계
  Future<ReviewStats> getStats() async {
    final odId = currentUserId;
    if (odId == null) return const ReviewStats();

    try {
      final allItems = await getAllItems();
      final dueCount = await getDueCount();

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
    final odId = currentUserId;
    if (odId == null) return null;

    try {
      final snapshot = await _reviewCollection
          .where('userId', isEqualTo: odId)
          .where('verseReference', isEqualTo: verseReference)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return ReviewItem.fromFirestore(
        snapshot.docs.first.id,
        snapshot.docs.first.data(),
      );
    } catch (e) {
      print('Get item by reference error: $e');
      return null;
    }
  }

  /// 복습 아이템 삭제
  Future<bool> deleteItem(String itemId) async {
    try {
      await _reviewCollection.doc(itemId).delete();
      return true;
    } catch (e) {
      print('Delete item error: $e');
      return false;
    }
  }

  /// 앞으로 7일간의 복습 예정 수
  Future<Map<String, int>> getUpcomingSchedule() async {
    final odId = currentUserId;
    if (odId == null) return {};

    try {
      final now = DateTime.now();
      final weekLater = now.add(const Duration(days: 7));

      final snapshot = await _reviewCollection
          .where('userId', isEqualTo: odId)
          .where('nextReviewDate', isGreaterThan: Timestamp.fromDate(now))
          .where('nextReviewDate', isLessThanOrEqualTo: Timestamp.fromDate(weekLater))
          .get();

      final schedule = <String, int>{};

      for (final doc in snapshot.docs) {
        final item = ReviewItem.fromFirestore(doc.id, doc.data());
        final dateKey = '${item.nextReviewDate.month}/${item.nextReviewDate.day}';
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
