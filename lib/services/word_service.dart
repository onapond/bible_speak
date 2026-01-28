import '../models/bible_word.dart';
import '../data/words/malachi_words.dart';

/// 단어 데이터 서비스
class WordService {
  /// 책별 단어 가져오기
  List<BibleWord> getBookWords(String bookId) {
    switch (bookId) {
      case 'malachi':
        return MalachiWords.allWords;
      // 추후 다른 책 추가
      // case 'philippians':
      //   return PhilippiansWords.allWords;
      default:
        return [];
    }
  }

  /// 특정 장의 단어 가져오기
  List<BibleWord> getChapterWords(String bookId, int chapter) {
    switch (bookId) {
      case 'malachi':
        return MalachiWords.getChapterWords(chapter);
      default:
        return [];
    }
  }

  /// 특정 단어 가져오기
  BibleWord? getWord(String wordId) {
    // 모든 책에서 검색
    final allWords = [
      ...MalachiWords.allWords,
      // 추후 다른 책 추가
    ];

    try {
      return allWords.firstWhere((w) => w.id == wordId);
    } catch (_) {
      return null;
    }
  }

  /// 난이도별 필터링
  List<BibleWord> filterByDifficulty(
    List<BibleWord> words, {
    int? minDifficulty,
    int? maxDifficulty,
  }) {
    return words.where((w) {
      if (minDifficulty != null && w.difficulty < minDifficulty) return false;
      if (maxDifficulty != null && w.difficulty > maxDifficulty) return false;
      return true;
    }).toList();
  }

  /// 검색
  List<BibleWord> search(String query, {String? bookId}) {
    final words = bookId != null ? getBookWords(bookId) : MalachiWords.allWords;
    final lowerQuery = query.toLowerCase();

    return words.where((w) {
      // 영단어 검색
      if (w.word.toLowerCase().contains(lowerQuery)) return true;
      // 한글 뜻 검색
      if (w.meanings.any((m) => m.contains(query))) return true;
      return false;
    }).toList();
  }

  /// 책별 단어 통계
  Map<String, int> getWordStats(String bookId) {
    final words = getBookWords(bookId);
    final stats = <String, int>{
      'total': words.length,
      'easy': words.where((w) => w.difficulty <= 2).length,
      'medium': words.where((w) => w.difficulty == 3).length,
      'hard': words.where((w) => w.difficulty >= 4).length,
    };
    return stats;
  }

  /// 지원하는 책 목록
  List<String> get supportedBooks => ['malachi'];

  /// 모든 단어 가져오기
  List<BibleWord> getAllWords() {
    return [
      ...MalachiWords.allWords,
      // 추후 다른 책 추가
    ];
  }

  /// 책에 단어 데이터가 있는 장 목록
  List<int> getChaptersWithWords(String bookId) {
    switch (bookId) {
      case 'malachi':
        final chapters = <int>[];
        for (int i = 1; i <= 4; i++) {
          if (MalachiWords.getChapterWords(i).isNotEmpty) {
            chapters.add(i);
          }
        }
        return chapters;
      default:
        return [];
    }
  }
}
