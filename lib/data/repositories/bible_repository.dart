import '../../domain/models/bible/bible_models.dart';

/// 성경 데이터 Repository 인터페이스
/// Firestore와 로컬 캐시 추상화
abstract class BibleRepository {
  /// 지원하는 모든 성경책 목록 가져오기
  Future<List<Book>> getBooks();

  /// 특정 성경책 가져오기
  Future<Book?> getBook(String bookId);

  /// 특정 성경책의 모든 챕터 가져오기
  Future<List<Chapter>> getChapters(String bookId);

  /// 특정 챕터 가져오기
  Future<Chapter?> getChapter(String bookId, int chapter);

  /// 특정 챕터의 모든 구절 가져오기
  Future<List<Verse>> getVerses(String bookId, int chapter);

  /// 특정 구절 가져오기
  Future<Verse?> getVerse(String bookId, int chapter, int verse);

  /// 특정 범위의 구절 가져오기
  Future<List<Verse>> getVerseRange(
    String bookId,
    int chapter, {
    required int startVerse,
    required int endVerse,
  });

  /// 무료 콘텐츠 여부 확인
  Future<bool> isFreeContent(String bookId, {int? chapter});

  /// 캐시 초기화
  Future<void> clearCache();

  /// 특정 책 데이터 프리로드
  Future<void> preloadBook(String bookId);
}
