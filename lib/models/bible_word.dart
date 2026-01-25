/// 성경 단어 모델
class BibleWord {
  final String id;
  final String word;
  final String pronunciation;
  final String partOfSpeech;
  final List<String> meanings;
  final List<VerseReference> verses;
  final String? memoryTip;
  final int difficulty;

  const BibleWord({
    required this.id,
    required this.word,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.meanings,
    required this.verses,
    this.memoryTip,
    this.difficulty = 3,
  });

  /// 품사 한글 표시
  String get partOfSpeechKo {
    switch (partOfSpeech) {
      case 'noun':
        return '명사';
      case 'verb':
        return '동사';
      case 'adj':
        return '형용사';
      case 'adv':
        return '부사';
      case 'prep':
        return '전치사';
      case 'conj':
        return '접속사';
      default:
        return partOfSpeech;
    }
  }

  /// 주요 뜻 (첫 번째)
  String get primaryMeaning => meanings.isNotEmpty ? meanings.first : '';

  /// 모든 뜻을 콤마로 연결
  String get allMeanings => meanings.join(', ');
}

/// 구절 참조
class VerseReference {
  final String book;
  final int chapter;
  final int verse;
  final String excerpt;
  final String korean;

  const VerseReference({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.excerpt,
    required this.korean,
  });

  /// 참조 문자열 (예: "말 2:10")
  String get reference {
    final bookNames = {
      'malachi': '말',
      'philippians': '빌',
      'hebrews': '히',
      'ephesians': '엡',
    };
    final shortName = bookNames[book] ?? book;
    return '$shortName $chapter:$verse';
  }
}
