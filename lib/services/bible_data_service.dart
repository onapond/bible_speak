import '../data/repositories/bible_repository.dart';
import '../data/repositories/firestore_bible_repository.dart';
import '../domain/models/bible/bible_models.dart';
import 'offline/bible_offline_service.dart';

// 기존 로컬 데이터 (폴백용)
import '../data/bible_data.dart' as legacy;

/// 성경 데이터 서비스 (파사드)
/// - Firestore 우선, 로컬 데이터 폴백
/// - 앱 전체에서 사용하는 단일 진입점
class BibleDataService {
  static BibleDataService? _instance;
  static BibleDataService get instance => _instance ??= BibleDataService._();

  late final BibleRepository _repository;
  bool _initialized = false;
  bool _useLocalFallback = false;

  BibleDataService._() {
    _repository = FirestoreBibleRepository();
  }

  /// 테스트용 생성자
  BibleDataService.withRepository(BibleRepository repository)
      : _repository = repository;

  /// 서비스 초기화
  /// Firestore 연결 확인 및 필요시 로컬 폴백 설정
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Firestore 연결 테스트
      final books = await _repository.getBooks();
      _useLocalFallback = books.isEmpty;
      _initialized = true;
    } catch (e) {
      // Firestore 오류 시 로컬 폴백 사용
      _useLocalFallback = true;
      _initialized = true;
    }
  }

  /// 로컬 폴백 사용 여부
  bool get isUsingLocalFallback => _useLocalFallback;

  // ============ 책 관련 메서드 ============

  /// 모든 성경책 목록
  Future<List<Book>> getBooks() async {
    if (_useLocalFallback) {
      return _getLegacyBooks();
    }

    try {
      final books = await _repository.getBooks();
      if (books.isEmpty) {
        return _getLegacyBooks();
      }
      return books;
    } catch (e) {
      return _getLegacyBooks();
    }
  }

  /// 특정 성경책 정보
  Future<Book?> getBook(String bookId) async {
    if (_useLocalFallback) {
      return _getLegacyBook(bookId);
    }

    try {
      final book = await _repository.getBook(bookId);
      return book ?? _getLegacyBook(bookId);
    } catch (e) {
      return _getLegacyBook(bookId);
    }
  }

  /// 책 이름 (한글)
  Future<String> getBookNameKo(String bookId) async {
    final book = await getBook(bookId);
    return book?.nameKo ?? legacy.BibleData.getBookName(bookId);
  }

  /// 책 이름 (영문 - ESV용)
  Future<String> getBookNameEn(String bookId) async {
    final book = await getBook(bookId);
    return book?.nameEsv ?? legacy.BibleData.getEsvBookName(bookId);
  }

  // ============ 챕터 관련 메서드 ============

  /// 책의 총 챕터 수
  Future<int> getChapterCount(String bookId) async {
    final book = await getBook(bookId);
    return book?.chapterCount ?? legacy.BibleData.getChapterCount(bookId);
  }

  /// 책의 모든 챕터 목록
  Future<List<Chapter>> getChapters(String bookId) async {
    if (_useLocalFallback) {
      return _getLegacyChapters(bookId);
    }

    try {
      final chapters = await _repository.getChapters(bookId);
      if (chapters.isEmpty) {
        return _getLegacyChapters(bookId);
      }
      return chapters;
    } catch (e) {
      return _getLegacyChapters(bookId);
    }
  }

  /// 특정 챕터 정보
  Future<Chapter?> getChapter(String bookId, int chapter) async {
    final chapters = await getChapters(bookId);
    return chapters.where((c) => c.chapter == chapter).firstOrNull;
  }

  // ============ 구절 관련 메서드 ============

  /// 챕터의 총 구절 수
  Future<int> getVerseCount(String bookId, int chapter) async {
    if (_useLocalFallback) {
      return legacy.BibleData.getVerseCount(bookId, chapter);
    }

    try {
      final chapterData = await _repository.getChapter(bookId, chapter);
      return chapterData?.verseCount ?? legacy.BibleData.getVerseCount(bookId, chapter);
    } catch (e) {
      return legacy.BibleData.getVerseCount(bookId, chapter);
    }
  }

  /// 챕터의 모든 구절
  Future<List<Verse>> getVerses(String bookId, int chapter) async {
    // 1. 오프라인 캐시 확인 (최우선)
    final offlineService = BibleOfflineService();
    if (offlineService.isInitialized && offlineService.isBookCached(bookId)) {
      final cachedVerses = await offlineService.getCachedVerses(bookId, chapter);
      if (cachedVerses.isNotEmpty) {
        return cachedVerses;
      }
    }

    // 2. 로컬 폴백
    if (_useLocalFallback) {
      return _getLegacyVerses(bookId, chapter);
    }

    // 3. Firestore
    try {
      final verses = await _repository.getVerses(bookId, chapter);
      if (verses.isEmpty) {
        return _getLegacyVerses(bookId, chapter);
      }
      return verses;
    } catch (e) {
      return _getLegacyVerses(bookId, chapter);
    }
  }

  /// 특정 구절
  Future<Verse?> getVerse(String bookId, int chapter, int verse) async {
    // 1. 오프라인 캐시 확인 (최우선)
    final offlineService = BibleOfflineService();
    if (offlineService.isInitialized && offlineService.isBookCached(bookId)) {
      final cachedVerse = await offlineService.getCachedVerse(bookId, chapter, verse);
      if (cachedVerse != null) {
        return cachedVerse;
      }
    }

    // 2. 로컬 폴백
    if (_useLocalFallback) {
      return _getLegacyVerse(bookId, chapter, verse);
    }

    // 3. Firestore
    try {
      final verseData = await _repository.getVerse(bookId, chapter, verse);
      return verseData ?? _getLegacyVerse(bookId, chapter, verse);
    } catch (e) {
      return _getLegacyVerse(bookId, chapter, verse);
    }
  }

  /// 한글 번역 텍스트
  Future<String?> getKoreanText(String bookId, int chapter, int verse) async {
    final verseData = await getVerse(bookId, chapter, verse);
    return verseData?.textKo ?? legacy.BibleData.getKoreanVerse(bookId, chapter, verse);
  }

  /// 영문 텍스트
  Future<String?> getEnglishText(String bookId, int chapter, int verse) async {
    final verseData = await getVerse(bookId, chapter, verse);
    return verseData?.textEn;
  }

  // ============ 콘텐츠 접근 권한 ============

  /// 무료 콘텐츠 여부
  Future<bool> isFreeContent(String bookId, {int? chapter}) async {
    return _repository.isFreeContent(bookId, chapter: chapter);
  }

  // ============ 캐시 관리 ============

  /// 캐시 초기화
  Future<void> clearCache() async {
    await _repository.clearCache();
  }

  /// 특정 책 프리로드
  Future<void> preloadBook(String bookId) async {
    await _repository.preloadBook(bookId);
  }

  // ============ 레거시 데이터 변환 (폴백용) ============

  List<Book> _getLegacyBooks() {
    return legacy.BibleData.supportedBooks.map((b) => Book(
      id: b.id,
      nameKo: b.nameKo,
      nameEn: b.nameEn,
      nameEsv: b.nameEn,
      testament: b.testament == '구약' ? 'OT' : 'NT',
      chapterCount: b.chapters,
      totalVerses: _calculateTotalVerses(b.id, b.chapters),
      order: legacy.BibleData.supportedBooks.indexOf(b),
      isFree: b.id == 'malachi', // 말라기만 무료
    )).toList();
  }

  Book? _getLegacyBook(String bookId) {
    final legacyBook = legacy.BibleData.getBook(bookId);
    if (legacyBook == null) return null;

    return Book(
      id: legacyBook.id,
      nameKo: legacyBook.nameKo,
      nameEn: legacyBook.nameEn,
      nameEsv: legacyBook.nameEn,
      testament: legacyBook.testament == '구약' ? 'OT' : 'NT',
      chapterCount: legacyBook.chapters,
      totalVerses: _calculateTotalVerses(legacyBook.id, legacyBook.chapters),
      order: legacy.BibleData.supportedBooks.indexWhere((b) => b.id == bookId),
      isFree: bookId == 'malachi',
    );
  }

  List<Chapter> _getLegacyChapters(String bookId) {
    final chapterCount = legacy.BibleData.getChapterCount(bookId);
    return List.generate(chapterCount, (i) {
      final chapter = i + 1;
      return Chapter(
        bookId: bookId,
        chapter: chapter,
        verseCount: legacy.BibleData.getVerseCount(bookId, chapter),
      );
    });
  }

  List<Verse> _getLegacyVerses(String bookId, int chapter) {
    final verseCount = legacy.BibleData.getVerseCount(bookId, chapter);
    return List.generate(verseCount, (i) {
      final verse = i + 1;
      return Verse(
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        textEn: '', // 영문은 ESV API에서 가져옴
        textKo: legacy.BibleData.getKoreanVerse(bookId, chapter, verse) ?? '',
      );
    });
  }

  Verse? _getLegacyVerse(String bookId, int chapter, int verse) {
    final koreanText = legacy.BibleData.getKoreanVerse(bookId, chapter, verse);
    if (koreanText == null) return null;

    return Verse(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      textEn: '',
      textKo: koreanText,
    );
  }

  int _calculateTotalVerses(String bookId, int chapters) {
    int total = 0;
    for (int ch = 1; ch <= chapters; ch++) {
      total += legacy.BibleData.getVerseCount(bookId, ch);
    }
    return total;
  }
}
