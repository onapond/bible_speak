import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_paths.dart';
import '../../domain/models/bible/bible_models.dart';
import 'bible_repository.dart';

/// Firestore 기반 BibleRepository 구현
/// - 메모리 캐시로 반복 요청 최적화
/// - 오프라인 지원 (Firestore 기본 캐시)
class FirestoreBibleRepository implements BibleRepository {
  final FirebaseFirestore _firestore;

  // 메모리 캐시
  final Map<String, Book> _bookCache = {};
  final Map<String, List<Chapter>> _chaptersCache = {};
  final Map<String, List<Verse>> _versesCache = {};
  final Map<String, Verse> _singleVerseCache = {};

  // 캐시 만료 시간 (30분)
  static const Duration _cacheExpiration = Duration(minutes: 30);
  DateTime? _lastCacheTime;

  FirestoreBibleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// 캐시 유효성 확인
  bool get _isCacheValid {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheExpiration;
  }

  /// 캐시 시간 업데이트
  void _updateCacheTime() {
    _lastCacheTime = DateTime.now();
  }

  @override
  Future<List<Book>> getBooks() async {
    // 캐시 확인
    if (_isCacheValid && _bookCache.isNotEmpty) {
      return _bookCache.values.toList()..sort((a, b) => a.order.compareTo(b.order));
    }

    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.bible)
          .orderBy('order')
          .get();

      final books = snapshot.docs.map((doc) => Book.fromFirestore(doc)).toList();

      // 캐시 업데이트
      _bookCache.clear();
      for (final book in books) {
        _bookCache[book.id] = book;
      }
      _updateCacheTime();

      return books;
    } catch (e) {
      // Firestore 오류 시 캐시 반환 (오프라인 지원)
      if (_bookCache.isNotEmpty) {
        return _bookCache.values.toList()..sort((a, b) => a.order.compareTo(b.order));
      }
      rethrow;
    }
  }

  @override
  Future<Book?> getBook(String bookId) async {
    // 캐시 확인
    if (_isCacheValid && _bookCache.containsKey(bookId)) {
      return _bookCache[bookId];
    }

    try {
      final doc = await _firestore
          .collection(FirestorePaths.bible)
          .doc(bookId)
          .get();

      if (!doc.exists) return null;

      final book = Book.fromFirestore(doc);
      _bookCache[bookId] = book;
      _updateCacheTime();

      return book;
    } catch (e) {
      // 오프라인 시 캐시 반환
      return _bookCache[bookId];
    }
  }

  @override
  Future<List<Chapter>> getChapters(String bookId) async {
    final cacheKey = bookId;

    // 캐시 확인
    if (_isCacheValid && _chaptersCache.containsKey(cacheKey)) {
      return _chaptersCache[cacheKey]!;
    }

    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.bible)
          .doc(bookId)
          .collection(FirestorePaths.chapters)
          .orderBy('chapter')
          .get();

      final chapters = snapshot.docs
          .map((doc) => Chapter.fromFirestore(doc, bookId: bookId))
          .toList();

      // 캐시 업데이트
      _chaptersCache[cacheKey] = chapters;
      _updateCacheTime();

      return chapters;
    } catch (e) {
      // 오프라인 시 캐시 반환
      return _chaptersCache[cacheKey] ?? [];
    }
  }

  @override
  Future<Chapter?> getChapter(String bookId, int chapter) async {
    final chapters = await getChapters(bookId);
    return chapters.where((c) => c.chapter == chapter).firstOrNull;
  }

  @override
  Future<List<Verse>> getVerses(String bookId, int chapter) async {
    final cacheKey = '${bookId}_$chapter';

    // 캐시 확인
    if (_isCacheValid && _versesCache.containsKey(cacheKey)) {
      return _versesCache[cacheKey]!;
    }

    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.bible)
          .doc(bookId)
          .collection(FirestorePaths.chapters)
          .doc(chapter.toString())
          .collection(FirestorePaths.verses)
          .orderBy('verse')
          .get();

      final verses = snapshot.docs
          .map((doc) => Verse.fromFirestore(doc, bookId: bookId, chapter: chapter))
          .toList();

      // 캐시 업데이트
      _versesCache[cacheKey] = verses;

      // 개별 구절도 캐시
      for (final verse in verses) {
        _singleVerseCache[verse.key] = verse;
      }
      _updateCacheTime();

      return verses;
    } catch (e) {
      // 오프라인 시 캐시 반환
      return _versesCache[cacheKey] ?? [];
    }
  }

  @override
  Future<Verse?> getVerse(String bookId, int chapter, int verse) async {
    final cacheKey = '${bookId}_${chapter}_$verse';

    // 단일 구절 캐시 확인
    if (_isCacheValid && _singleVerseCache.containsKey(cacheKey)) {
      return _singleVerseCache[cacheKey];
    }

    // 챕터 캐시 확인
    final chapterCacheKey = '${bookId}_$chapter';
    if (_isCacheValid && _versesCache.containsKey(chapterCacheKey)) {
      return _versesCache[chapterCacheKey]!
          .where((v) => v.verse == verse)
          .firstOrNull;
    }

    try {
      final doc = await _firestore
          .collection(FirestorePaths.bible)
          .doc(bookId)
          .collection(FirestorePaths.chapters)
          .doc(chapter.toString())
          .collection(FirestorePaths.verses)
          .doc(verse.toString())
          .get();

      if (!doc.exists) return null;

      final verseData = Verse.fromFirestore(doc, bookId: bookId, chapter: chapter);
      _singleVerseCache[cacheKey] = verseData;
      _updateCacheTime();

      return verseData;
    } catch (e) {
      return _singleVerseCache[cacheKey];
    }
  }

  @override
  Future<List<Verse>> getVerseRange(
    String bookId,
    int chapter, {
    required int startVerse,
    required int endVerse,
  }) async {
    final allVerses = await getVerses(bookId, chapter);
    return allVerses
        .where((v) => v.verse >= startVerse && v.verse <= endVerse)
        .toList();
  }

  @override
  Future<bool> isFreeContent(String bookId, {int? chapter}) async {
    final book = await getBook(bookId);
    if (book == null) return false;

    // 책 전체가 무료인 경우
    if (book.isFree) return true;

    // TODO: 챕터별 무료 설정이 필요하면 구현
    // 현재는 책 단위로만 무료/유료 구분
    return false;
  }

  @override
  Future<void> clearCache() async {
    _bookCache.clear();
    _chaptersCache.clear();
    _versesCache.clear();
    _singleVerseCache.clear();
    _lastCacheTime = null;
  }

  @override
  Future<void> preloadBook(String bookId) async {
    // 책 정보 로드
    await getBook(bookId);

    // 모든 챕터 로드
    final chapters = await getChapters(bookId);

    // 모든 구절 로드 (병렬 처리)
    await Future.wait(
      chapters.map((chapter) => getVerses(bookId, chapter.chapter)),
    );
  }

  // ============ 데이터 쓰기 메서드 (관리자용) ============

  /// 성경책 추가/업데이트
  Future<void> setBook(Book book) async {
    await _firestore
        .collection(FirestorePaths.bible)
        .doc(book.id)
        .set(book.toFirestore());

    _bookCache[book.id] = book;
  }

  /// 챕터 추가/업데이트
  Future<void> setChapter(String bookId, Chapter chapter) async {
    await _firestore
        .collection(FirestorePaths.bible)
        .doc(bookId)
        .collection(FirestorePaths.chapters)
        .doc(chapter.chapter.toString())
        .set(chapter.toFirestore());

    // 캐시 무효화
    _chaptersCache.remove(bookId);
  }

  /// 구절 추가/업데이트
  Future<void> setVerse(Verse verse) async {
    await _firestore
        .collection(FirestorePaths.bible)
        .doc(verse.bookId)
        .collection(FirestorePaths.chapters)
        .doc(verse.chapter.toString())
        .collection(FirestorePaths.verses)
        .doc(verse.verse.toString())
        .set(verse.toFirestore());

    // 캐시 무효화
    _versesCache.remove('${verse.bookId}_${verse.chapter}');
    _singleVerseCache.remove(verse.key);
  }

  /// 배치로 여러 구절 추가
  Future<void> setVersesBatch(List<Verse> verses) async {
    final batch = _firestore.batch();

    for (final verse in verses) {
      final ref = _firestore
          .collection(FirestorePaths.bible)
          .doc(verse.bookId)
          .collection(FirestorePaths.chapters)
          .doc(verse.chapter.toString())
          .collection(FirestorePaths.verses)
          .doc(verse.verse.toString());

      batch.set(ref, verse.toFirestore());
    }

    await batch.commit();

    // 캐시 무효화
    for (final verse in verses) {
      _versesCache.remove('${verse.bookId}_${verse.chapter}');
      _singleVerseCache.remove(verse.key);
    }
  }
}
