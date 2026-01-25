import 'korean_verses.dart';
import 'korean_ephesians.dart';
import 'korean_hebrews_1.dart';
import 'korean_hebrews_2.dart';

/// 성경 구절 데이터 모델
class VerseData {
  final int verse;
  final String korean;
  final String english;
  final String? audioUrl;

  const VerseData({
    required this.verse,
    required this.korean,
    required this.english,
    this.audioUrl,
  });
}

/// 성경책 정보
class BibleBook {
  final String id;           // 영문 ID (API용)
  final String nameKo;       // 한글 이름
  final String nameEn;       // 영문 이름
  final int chapters;        // 총 장 수
  final String testament;    // 구약/신약

  const BibleBook({
    required this.id,
    required this.nameKo,
    required this.nameEn,
    required this.chapters,
    required this.testament,
  });
}

/// 성경 데이터 저장소
class BibleData {
  /// 지원하는 성경책 목록
  static const List<BibleBook> supportedBooks = [
    BibleBook(
      id: 'malachi',
      nameKo: '말라기',
      nameEn: 'Malachi',
      chapters: 4,
      testament: '구약',
    ),
    BibleBook(
      id: 'philippians',
      nameKo: '빌립보서',
      nameEn: 'Philippians',
      chapters: 4,
      testament: '신약',
    ),
    BibleBook(
      id: 'hebrews',
      nameKo: '히브리서',
      nameEn: 'Hebrews',
      chapters: 13,
      testament: '신약',
    ),
    BibleBook(
      id: 'ephesians',
      nameKo: '에베소서',
      nameEn: 'Ephesians',
      chapters: 6,
      testament: '신약',
    ),
  ];

  /// 책 ID로 BibleBook 가져오기
  static BibleBook? getBook(String bookId) {
    try {
      return supportedBooks.firstWhere((b) => b.id == bookId);
    } catch (_) {
      return null;
    }
  }

  /// 책 이름 (한글)
  static String getBookName(String bookId) {
    return getBook(bookId)?.nameKo ?? bookId;
  }

  /// ESV API용 영문 이름
  static String getEsvBookName(String bookId) {
    return getBook(bookId)?.nameEn ?? bookId;
  }

  /// 책별 총 챕터 수
  static int getChapterCount(String bookId) {
    return getBook(bookId)?.chapters ?? 0;
  }

  /// 장별 절 수 (근사치 - 실제 API 호출로 정확한 값 얻음)
  static int getVerseCount(String bookId, int chapter) {
    final key = '${bookId}_$chapter';
    return _verseCountMap[key] ?? 20; // 기본값 20
  }

  /// 장별 절 수 맵
  static const Map<String, int> _verseCountMap = {
    // 말라기 (4장)
    'malachi_1': 14, 'malachi_2': 17, 'malachi_3': 18, 'malachi_4': 6,
    // 빌립보서 (4장)
    'philippians_1': 30, 'philippians_2': 30, 'philippians_3': 21, 'philippians_4': 23,
    // 히브리서 (13장)
    'hebrews_1': 14, 'hebrews_2': 18, 'hebrews_3': 19, 'hebrews_4': 16,
    'hebrews_5': 14, 'hebrews_6': 20, 'hebrews_7': 28, 'hebrews_8': 13,
    'hebrews_9': 28, 'hebrews_10': 39, 'hebrews_11': 40, 'hebrews_12': 29,
    'hebrews_13': 25,
    // 에베소서 (6장)
    'ephesians_1': 23, 'ephesians_2': 22, 'ephesians_3': 21, 'ephesians_4': 32,
    'ephesians_5': 33, 'ephesians_6': 24,
  };

  /// 통합된 한글 번역 데이터
  static Map<String, String> get _allKoreanVerses {
    return {
      ...KoreanVerses.data,        // 말라기 + 빌립보서
      ...KoreanEphesians.data,     // 에베소서
      ...KoreanHebrews1.data,      // 히브리서 1-7장
      ...KoreanHebrews2.data,      // 히브리서 8-13장
    };
  }

  /// 한글 번역 데이터 가져오기
  static String? getKoreanVerse(String bookId, int chapter, int verse) {
    final key = '${bookId}_${chapter}_$verse';
    return _allKoreanVerses[key];
  }

  /// 특정 장의 모든 한글 번역이 있는지 확인
  static bool hasKoreanChapter(String bookId, int chapter) {
    final verseCount = getVerseCount(bookId, chapter);
    for (int v = 1; v <= verseCount; v++) {
      if (getKoreanVerse(bookId, chapter, v) == null) {
        return false;
      }
    }
    return true;
  }

  /// 한글 번역 통계
  static Map<String, int> getKoreanVerseStats() {
    final stats = <String, int>{};
    for (final book in supportedBooks) {
      int count = 0;
      for (int ch = 1; ch <= book.chapters; ch++) {
        final verseCount = getVerseCount(book.id, ch);
        for (int v = 1; v <= verseCount; v++) {
          if (getKoreanVerse(book.id, ch, v) != null) {
            count++;
          }
        }
      }
      stats[book.id] = count;
    }
    return stats;
  }
}
