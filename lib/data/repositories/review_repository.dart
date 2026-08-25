import '../../models/review_item.dart';

/// 복습 데이터 영속화 계약.
///
/// 서비스와 UI는 Firestore 문서 경로나 쿼리 타입 대신 이 계약에만
/// 의존한다. 다른 데이터베이스로 전환할 때는 이 인터페이스의 새 구현을
/// 추가하고 기존 호출 코드는 유지한다.
abstract interface class ReviewRepository {
  Future<ReviewItem?> findByReference({
    required String userId,
    required String verseReference,
  });

  /// 같은 사용자와 정규 구절 좌표의 동시 요청은 동일 항목을 반환해야 한다.
  Future<ReviewItem> createOrGet({
    required String userId,
    required String verseReference,
    required String book,
    required int chapter,
    required int verse,
    required String verseText,
    required DateTime createdAt,
  });

  Future<List<ReviewItem>> findDue({
    required String userId,
    required DateTime dueBefore,
    required int limit,
  });

  Future<int> countDue({
    required String userId,
    required DateTime dueBefore,
  });

  Future<List<ReviewItem>> findAll({required String userId});

  Future<List<ReviewItem>> findMastered({
    required String userId,
    required int minimumIntervalDays,
  });

  Future<void> save({
    required String userId,
    required ReviewItem item,
  });

  Future<bool> delete({
    required String userId,
    required String itemId,
  });

  Future<List<ReviewItem>> findScheduled({
    required String userId,
    required DateTime after,
    required DateTime through,
  });
}
