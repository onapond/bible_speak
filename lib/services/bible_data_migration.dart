import '../data/bible_data.dart' as legacy;
import '../data/repositories/firestore_bible_repository.dart';
import '../domain/models/bible/bible_models.dart';
import '../services/esv_service.dart';

/// 로컬 데이터 → Firestore 마이그레이션 서비스
/// 한 번만 실행하여 Firestore에 데이터를 채움
class BibleDataMigration {
  final FirestoreBibleRepository _repository;
  final EsvService _esvService;

  BibleDataMigration({
    FirestoreBibleRepository? repository,
    EsvService? esvService,
  })  : _repository = repository ?? FirestoreBibleRepository(),
        _esvService = esvService ?? EsvService();

  /// 전체 마이그레이션 실행
  Future<MigrationResult> migrateAll({
    void Function(String message)? onProgress,
  }) async {
    final result = MigrationResult();
    final stopwatch = Stopwatch()..start();

    try {
      // 1. 책 마이그레이션
      onProgress?.call('📚 성경책 마이그레이션 시작...');
      await _migrateBooks(result, onProgress);

      // 2. 각 책의 챕터와 구절 마이그레이션
      for (final legacyBook in legacy.BibleData.supportedBooks) {
        onProgress?.call('📖 ${legacyBook.nameKo} 마이그레이션 시작...');
        await _migrateBookContent(legacyBook, result, onProgress);
      }

      result.success = true;
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      onProgress?.call('❌ 오류 발생: $e');
    }

    stopwatch.stop();
    result.durationMs = stopwatch.elapsedMilliseconds;
    onProgress?.call('✅ 마이그레이션 완료! (${result.durationMs}ms)');

    return result;
  }

  /// 책 메타데이터 마이그레이션
  Future<void> _migrateBooks(
    MigrationResult result,
    void Function(String)? onProgress,
  ) async {
    for (int i = 0; i < legacy.BibleData.supportedBooks.length; i++) {
      final legacyBook = legacy.BibleData.supportedBooks[i];

      final book = Book(
        id: legacyBook.id,
        nameKo: legacyBook.nameKo,
        nameEn: legacyBook.nameEn,
        nameEsv: legacyBook.nameEn,
        testament: legacyBook.testament == '구약' ? 'OT' : 'NT',
        chapterCount: legacyBook.chapters,
        totalVerses: _calculateTotalVerses(legacyBook),
        order: i,
        isFree: legacyBook.id == 'malachi',
        isPremium: legacyBook.id != 'malachi',
      );

      await _repository.setBook(book);
      result.booksCreated++;
      onProgress?.call('  ✓ ${book.nameKo} 생성 완료');
    }
  }

  /// 책의 챕터와 구절 마이그레이션
  Future<void> _migrateBookContent(
    legacy.BibleBook legacyBook,
    MigrationResult result,
    void Function(String)? onProgress,
  ) async {
    for (int ch = 1; ch <= legacyBook.chapters; ch++) {
      final verseCount = legacy.BibleData.getVerseCount(legacyBook.id, ch);

      // 챕터 생성
      final chapter = Chapter(
        bookId: legacyBook.id,
        chapter: ch,
        verseCount: verseCount,
      );
      await _repository.setChapter(legacyBook.id, chapter);
      result.chaptersCreated++;

      // ESV에서 영문 텍스트 가져오기
      Map<int, String> englishVerses = {};
      try {
        final esvVerses = await _esvService.getChapter(
          book: legacy.BibleData.getEsvBookName(legacyBook.id),
          chapter: ch,
        );
        for (final v in esvVerses) {
          englishVerses[v.verse] = v.english;
        }
      } catch (e) {
        onProgress?.call('  ⚠️ ESV API 오류 (${legacyBook.id} $ch장): $e');
      }

      // 구절 배치 생성
      final verses = <Verse>[];
      for (int v = 1; v <= verseCount; v++) {
        final koreanText = legacy.BibleData.getKoreanVerse(legacyBook.id, ch, v) ?? '';
        final englishText = englishVerses[v] ?? '';

        verses.add(Verse(
          bookId: legacyBook.id,
          chapter: ch,
          verse: v,
          textEn: englishText,
          textKo: koreanText,
          keyWords: _extractKeyWords(englishText),
          difficulty: _calculateDifficulty(englishText),
        ));
      }

      // 배치로 저장
      await _repository.setVersesBatch(verses);
      result.versesCreated += verses.length;

      onProgress?.call('  ✓ ${legacyBook.nameKo} $ch장 완료 ($verseCount절)');

      // API 레이트 리밋 방지
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// 총 구절 수 계산
  int _calculateTotalVerses(legacy.BibleBook book) {
    int total = 0;
    for (int ch = 1; ch <= book.chapters; ch++) {
      total += legacy.BibleData.getVerseCount(book.id, ch);
    }
    return total;
  }

  /// 핵심 단어 추출 (간단한 구현)
  List<String> _extractKeyWords(String text) {
    if (text.isEmpty) return [];

    // 불용어 제거 및 긴 단어 추출
    final stopWords = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'must', 'shall', 'can', 'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they', 'who', 'whom', 'which', 'what', 'whose', 'my', 'your', 'his', 'her', 'its', 'our', 'their', 'me', 'him', 'us', 'them', 'not', 'no', 'so', 'as', 'if', 'then', 'than', 'when', 'where', 'how', 'all', 'each', 'every', 'both', 'few', 'more', 'most', 'other', 'some', 'such', 'only', 'own', 'same', 'too', 'very', 'just', 'also', 'now', 'here', 'there', 'from', 'into', 'through', 'during', 'before', 'after', 'above', 'below', 'between', 'under', 'again', 'further', 'once'};

    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4 && !stopWords.contains(w))
        .toSet()
        .take(5)
        .toList();

    return words;
  }

  /// 난이도 계산 (단어 수 기반)
  int _calculateDifficulty(String text) {
    if (text.isEmpty) return 2;

    final wordCount = text.split(RegExp(r'\s+')).length;
    if (wordCount <= 10) return 1;
    if (wordCount <= 20) return 2;
    if (wordCount <= 30) return 3;
    if (wordCount <= 40) return 4;
    return 5;
  }
}

/// 마이그레이션 결과
class MigrationResult {
  bool success = false;
  String? error;
  int booksCreated = 0;
  int chaptersCreated = 0;
  int versesCreated = 0;
  int durationMs = 0;

  @override
  String toString() {
    return '''
MigrationResult:
  success: $success
  books: $booksCreated
  chapters: $chaptersCreated
  verses: $versesCreated
  duration: ${durationMs}ms
  ${error != null ? 'error: $error' : ''}
''';
  }
}
