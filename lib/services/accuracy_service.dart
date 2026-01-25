/// 발음 정확도 평가 서비스 (강화 버전)
/// - 엄격한 단어별 비교
/// - 순서 일치 검증
/// - 누락/추가 단어 페널티
/// - 발음 혼동 단어 구분
class AccuracyService {
  // 난이도 강화 - 기준값 상향
  static const double _matchingThreshold = 0.75; // 매칭 최소 기준 (0.65 → 0.75)
  static const double _correctThreshold = 0.92;  // 정답 인정 기준 (0.85 → 0.92)
  static const double _orderPenalty = 0.15;      // 순서 틀림 페널티
  static const double _extraWordPenalty = 0.05;  // 추가 단어 페널티

  /// 원문과 발화 텍스트 비교
  EvaluationResult evaluate({
    required String originalText,
    required String spokenText,
  }) {
    final originalWords = _extractWords(originalText);
    final spokenWords = _extractWordsNormalized(spokenText);

    final wordResults = <WordResult>[];
    final usedSpokenIndices = <int>{};

    // 1단계: 각 원본 단어에 대해 최적 매칭 찾기
    for (int i = 0; i < originalWords.length; i++) {
      final originalWord = originalWords[i];
      final normalizedOriginal = _normalize(originalWord);

      // 짧은 기능어 (관사, 전치사 등)는 좀 더 관대하게
      final isShortWord = normalizedOriginal.length <= 3;
      final threshold = isShortWord ? _correctThreshold - 0.05 : _correctThreshold;

      int bestMatchIndex = -1;
      double bestScore = 0.0;
      String? matchedSpokenWord;

      for (int j = 0; j < spokenWords.length; j++) {
        if (usedSpokenIndices.contains(j)) continue;

        final spokenWord = spokenWords[j];

        // 발음 혼동 체크
        if (_isConfusablePair(normalizedOriginal, spokenWord)) {
          continue; // 혼동 가능한 쌍은 매칭 제외
        }

        double similarity = _calculateSimilarity(normalizedOriginal, spokenWord);

        // 순서 페널티 적용 (위치가 많이 다르면 감점)
        final positionDiff = (i - j).abs();
        if (positionDiff > 2) {
          similarity -= _orderPenalty * (positionDiff - 2) / originalWords.length;
        }

        if (similarity > bestScore && similarity >= _matchingThreshold) {
          bestScore = similarity;
          bestMatchIndex = j;
          matchedSpokenWord = spokenWord;
        }
      }

      final isCorrect = bestScore >= threshold;

      if (bestMatchIndex >= 0 && isCorrect) {
        usedSpokenIndices.add(bestMatchIndex);
      }

      wordResults.add(WordResult(
        originalWord: originalWord,
        normalizedOriginal: normalizedOriginal,
        spokenWord: matchedSpokenWord,
        isCorrect: isCorrect,
        similarity: bestScore,
        index: i,
      ));
    }

    // 2단계: 점수 계산 (추가 단어 페널티 포함)
    final correctCount = wordResults.where((r) => r.isCorrect).length;
    final totalCount = originalWords.length;

    // 기본 점수
    double score = totalCount > 0 ? (correctCount / totalCount * 100) : 0.0;

    // 추가 단어 페널티 (원본에 없는 단어를 말한 경우)
    final extraWords = spokenWords.length - usedSpokenIndices.length;
    if (extraWords > 0 && score > 0) {
      final extraPenalty = extraWords * _extraWordPenalty * 100;
      score = (score - extraPenalty).clamp(0.0, 100.0);
    }

    // 순서 일치율 체크 및 추가 페널티
    final orderScore = _calculateOrderScore(wordResults, usedSpokenIndices, spokenWords.length);
    if (orderScore < 0.8 && score > 50) {
      // 순서가 많이 틀리면 추가 감점
      score = score * (0.9 + orderScore * 0.1);
    }

    return EvaluationResult(
      score: score,
      correctCount: correctCount,
      totalCount: totalCount,
      wordResults: wordResults,
      originalText: originalText,
      spokenText: spokenText,
    );
  }

  /// 순서 일치율 계산
  double _calculateOrderScore(
    List<WordResult> wordResults,
    Set<int> usedIndices,
    int spokenLength,
  ) {
    if (usedIndices.isEmpty) return 0.0;

    final sortedIndices = usedIndices.toList()..sort();
    int orderCorrect = 0;

    for (int i = 1; i < sortedIndices.length; i++) {
      if (sortedIndices[i] > sortedIndices[i - 1]) {
        orderCorrect++;
      }
    }

    return sortedIndices.length > 1
        ? orderCorrect / (sortedIndices.length - 1)
        : 1.0;
  }

  /// 발음 혼동 가능한 단어 쌍 체크
  bool _isConfusablePair(String word1, String word2) {
    // 흔히 혼동되는 단어 쌍들
    const confusablePairs = [
      // 비슷한 발음
      ['the', 'a'], ['the', 'that'], ['the', 'they'],
      ['in', 'and'], ['in', 'an'], ['an', 'and'],
      ['is', 'his'], ['is', 'as'], ['is', 'it'],
      ['of', 'off'], ['of', 'if'],
      ['for', 'four'], ['for', 'from'],
      ['to', 'too'], ['to', 'two'],
      ['there', 'their'], ['there', 'they\'re'],
      ['your', 'you\'re'], ['your', 'you'],
      ['have', 'has'], ['have', 'had'],
      ['will', 'we\'ll'], ['will', 'well'],
      ['be', 'been'], ['be', 'being'],
      ['not', 'now'], ['not', 'know'],
      ['with', 'which'], ['with', 'will'],
      ['lord', 'word'], ['lord', 'load'],
      ['god', 'good'], ['god', 'got'],
      ['said', 'say'], ['said', 'says'],
      ['come', 'came'], ['come', 'some'],
      ['him', 'them'], ['him', 'his'],
      ['her', 'here'], ['her', 'hear'],
      ['man', 'men'], ['man', 'main'],
      ['son', 'sun'], ['son', 'some'],
    ];

    final w1 = word1.toLowerCase();
    final w2 = word2.toLowerCase();

    for (final pair in confusablePairs) {
      if ((pair[0] == w1 && pair[1] == w2) ||
          (pair[0] == w2 && pair[1] == w1)) {
        // 혼동 가능한 쌍인 경우, 정확히 일치해야만 매칭
        return w1 != w2;
      }
    }

    return false;
  }

  List<String> _extractWords(String text) {
    final regex = RegExp(r"[\w']+[.,!?;:]*|[.,!?;:]");
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  List<String> _extractWordsNormalized(String text) {
    final regex = RegExp(r"[\w']+");
    return regex.allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();
  }

  String _normalize(String word) {
    return word.toLowerCase().replaceAll(RegExp(r"[^\w']"), '');
  }

  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a.toLowerCase() == b.toLowerCase()) return 1.0;

    // 길이 차이가 너무 크면 바로 낮은 점수
    final lenDiff = (a.length - b.length).abs();
    if (lenDiff > a.length * 0.5) {
      return 0.3;
    }

    // Levenshtein distance
    final len1 = a.length;
    final len2 = b.length;

    var prev = List<int>.generate(len2 + 1, (i) => i);
    var curr = List<int>.filled(len2 + 1, 0);

    for (int i = 1; i <= len1; i++) {
      curr[0] = i;
      for (int j = 1; j <= len2; j++) {
        final cost = a[i - 1].toLowerCase() == b[j - 1].toLowerCase() ? 0 : 1;
        curr[j] = [prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    final maxLen = len1 > len2 ? len1 : len2;
    final similarity = 1.0 - (prev[len2] / maxLen);

    // 첫 글자/마지막 글자 일치 보너스
    double bonus = 0.0;
    if (a[0].toLowerCase() == b[0].toLowerCase()) {
      bonus += 0.02;
    }
    if (a[a.length - 1].toLowerCase() == b[b.length - 1].toLowerCase()) {
      bonus += 0.02;
    }

    return (similarity + bonus).clamp(0.0, 1.0);
  }

  /// 점수에 따른 등급
  static String getGrade(double score) {
    if (score >= 95) return '🏆 완벽해요!';
    if (score >= 85) return '🌟 훌륭해요!';
    if (score >= 70) return '👍 잘했어요!';
    if (score >= 50) return '💪 조금만 더!';
    return '📚 다시 연습해보세요';
  }
}

/// 평가 결과
class EvaluationResult {
  final double score;
  final int correctCount;
  final int totalCount;
  final List<WordResult> wordResults;
  final String originalText;
  final String spokenText;

  EvaluationResult({
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.wordResults,
    required this.originalText,
    required this.spokenText,
  });

  String get grade => AccuracyService.getGrade(score);

  List<WordResult> get correctWords =>
      wordResults.where((r) => r.isCorrect).toList();

  List<WordResult> get incorrectWords =>
      wordResults.where((r) => !r.isCorrect).toList();

  /// 문법적 구문 추출
  List<Phrase> get phrases {
    final result = <Phrase>[];
    final segments = originalText.split(RegExp(r'(?<=[,;:.!?])\s*'));

    int wordIndex = 0;
    for (final segment in segments) {
      final trimmedSegment = segment.trim();
      if (trimmedSegment.isEmpty) continue;

      final phraseWordCount = RegExp(r"[\w']+").allMatches(trimmedSegment).length;

      if (phraseWordCount > 0) {
        final startIndex = wordIndex;
        final endIndex = wordIndex + phraseWordCount - 1;

        final phraseWordResults = wordResults
            .where((w) => w.index >= startIndex && w.index <= endIndex)
            .toList();

        result.add(Phrase(
          text: trimmedSegment,
          startIndex: startIndex,
          endIndex: endIndex,
          wordResults: phraseWordResults,
        ));

        wordIndex += phraseWordCount;
      }
    }

    return result;
  }

  /// 특정 단어가 속한 구문 찾기
  Phrase? getPhraseForWord(WordResult word) {
    for (final phrase in phrases) {
      if (word.index >= phrase.startIndex && word.index <= phrase.endIndex) {
        return phrase;
      }
    }
    return null;
  }
}

/// 문법적 구문
class Phrase {
  final String text;
  final int startIndex;
  final int endIndex;
  final List<WordResult> wordResults;

  Phrase({
    required this.text,
    required this.startIndex,
    required this.endIndex,
    required this.wordResults,
  });

  bool get hasIncorrectWords => wordResults.any((w) => !w.isCorrect);

  List<WordResult> get incorrectWords =>
      wordResults.where((w) => !w.isCorrect).toList();

  String get cleanText {
    return text
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// 단어별 결과
class WordResult {
  final String originalWord;
  final String normalizedOriginal;
  final String? spokenWord;
  final bool isCorrect;
  final double similarity;
  final int index;

  WordResult({
    required this.originalWord,
    required this.normalizedOriginal,
    this.spokenWord,
    required this.isCorrect,
    required this.similarity,
    required this.index,
  });

  String get cleanWord => originalWord.replaceAll(RegExp(r"[^\w']"), '');
}
