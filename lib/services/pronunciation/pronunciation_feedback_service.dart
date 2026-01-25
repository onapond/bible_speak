import 'azure_pronunciation_service.dart';

/// 발음 피드백 생성 서비스
/// - Azure 평가 결과를 구체적인 한국어 피드백으로 변환
/// - 발음 교정 팁 제공
class PronunciationFeedbackService {
  /// 종합 피드백 생성
  PronunciationFeedback generateFeedback(PronunciationResult result) {
    if (!result.isSuccess) {
      return PronunciationFeedback(
        summary: result.errorMessage ?? '평가 실패',
        details: [],
        tips: [],
        encouragement: '다시 시도해보세요.',
      );
    }

    final details = <FeedbackDetail>[];
    final tips = <String>[];

    // 1. 틀린 단어 분석
    for (final word in result.incorrectWords) {
      final detail = _analyzeWord(word);
      details.add(detail);

      // 발음 팁 추가
      final tip = _getPronunciationTip(word);
      if (tip != null && !tips.contains(tip)) {
        tips.add(tip);
      }
    }

    // 2. 개선 필요 단어
    for (final word in result.needsImprovementWords) {
      details.add(FeedbackDetail(
        word: word.word,
        score: word.accuracyScore,
        status: FeedbackStatus.needsImprovement,
        message: '조금 더 명확하게 발음해보세요',
        phonemeIssues: _getPhonemeIssues(word),
      ));
    }

    // 3. 전체 점수 기반 격려 메시지
    final encouragement = _getEncouragement(result);

    // 4. 요약 생성
    final summary = _generateSummary(result);

    // 5. 유창성/운율 팁
    if (result.fluencyScore < 70) {
      tips.add('💡 더 자연스럽게: 단어 사이를 끊지 말고 연결해서 읽어보세요.');
    }
    if (result.prosodyScore < 70) {
      tips.add('💡 강세 연습: 중요한 단어는 더 세게, 기능어는 약하게 발음해보세요.');
    }

    return PronunciationFeedback(
      summary: summary,
      details: details,
      tips: tips,
      encouragement: encouragement,
      overallScore: result.overallScore,
      accuracyScore: result.accuracyScore,
      fluencyScore: result.fluencyScore,
      prosodyScore: result.prosodyScore,
    );
  }

  /// 단어 분석
  FeedbackDetail _analyzeWord(WordPronunciation word) {
    String message;
    List<PhonemeIssue> phonemeIssues = [];

    switch (word.errorType) {
      case 'Omission':
        message = '이 단어를 빠뜨렸어요';
        break;
      case 'Insertion':
        message = '원문에 없는 단어예요';
        break;
      case 'Mispronunciation':
        phonemeIssues = _getPhonemeIssues(word);
        if (phonemeIssues.isNotEmpty) {
          final worst = phonemeIssues.first;
          message = "'${worst.phoneme}' 발음을 '${worst.koreanHint}'처럼 해보세요";
        } else {
          message = '발음이 부정확해요';
        }
        break;
      default:
        phonemeIssues = _getPhonemeIssues(word);
        if (phonemeIssues.isNotEmpty) {
          message = '일부 음소가 부정확해요';
        } else {
          message = '발음 점수: ${word.accuracyScore.toInt()}%';
        }
    }

    return FeedbackDetail(
      word: word.word,
      score: word.accuracyScore,
      status: word.isOmitted
          ? FeedbackStatus.omitted
          : (word.accuracyScore < 60
              ? FeedbackStatus.incorrect
              : FeedbackStatus.needsImprovement),
      message: message,
      phonemeIssues: phonemeIssues,
      errorType: word.errorTypeKorean,
    );
  }

  /// 음소 이슈 추출
  List<PhonemeIssue> _getPhonemeIssues(WordPronunciation word) {
    return word.phonemes
        .where((p) => p.accuracyScore < 70)
        .map((p) => PhonemeIssue(
              phoneme: p.phoneme,
              score: p.accuracyScore,
              koreanHint: p.koreanHint,
              tip: _getPhonemeTip(p.phoneme),
            ))
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));
  }

  /// 음소별 발음 팁
  String? _getPhonemeTip(String phoneme) {
    const tips = {
      // R vs L (한국인 취약)
      'r': '혀끝을 입천장에 닿지 않게 뒤로 말아올리세요',
      'l': '혀끝을 윗니 뒤에 붙이세요',

      // TH 발음 (한국인 취약)
      'θ': '혀를 윗니 사이에 살짝 내밀고 바람을 내보내세요 (think의 th)',
      'ð': '혀를 윗니 사이에 살짝 내밀고 성대를 울리세요 (the의 th)',

      // F vs P (한국인 취약)
      'f': '윗니로 아랫입술을 살짝 물고 바람을 내보내세요',
      'v': '윗니로 아랫입술을 살짝 물고 성대를 울리세요',

      // 모음
      'æ': '입을 옆으로 넓게 벌리고 "애"라고 하세요',
      'ʌ': '"어"보다 입을 더 벌리고 짧게 발음하세요',
      'ɑ': '입을 크게 벌리고 "아"라고 하세요',
      'ə': '힘을 빼고 약하게 "어"라고 하세요',

      // 기타
      'ŋ': '콧소리로 "응"하듯 발음하세요',
      'ʃ': '입술을 둥글게 모으고 "쉬"라고 하세요',
      'tʃ': '혀를 입천장에 붙였다 떼면서 "취"라고 하세요',
      'dʒ': '혀를 입천장에 붙였다 떼면서 "쥐"라고 하세요',
    };
    return tips[phoneme];
  }

  /// 단어별 발음 팁
  String? _getPronunciationTip(WordPronunciation word) {
    // 흔히 틀리는 단어 패턴
    final lowercaseWord = word.word.toLowerCase();

    // th 발음
    if (lowercaseWord.contains('th')) {
      return '💡 "th" 발음: 혀를 윗니 사이에 살짝 내밀어보세요.';
    }

    // r 발음
    if (lowercaseWord.startsWith('r') || lowercaseWord.contains('ri') || lowercaseWord.contains('ro')) {
      return '💡 "r" 발음: 혀끝을 입천장에 닿지 않게 뒤로 말아올리세요.';
    }

    // -tion 발음
    if (lowercaseWord.endsWith('tion')) {
      return '💡 "-tion": "션"이 아니라 "션"처럼 부드럽게 발음하세요.';
    }

    // -ness 발음
    if (lowercaseWord.endsWith('ness')) {
      return '💡 "-ness": "니스"가 아니라 "nɪs"로 짧게 발음하세요.';
    }

    // 가장 틀린 음소 기반 팁
    final worstPhoneme = word.worstPhoneme;
    if (worstPhoneme != null) {
      final tip = _getPhonemeTip(worstPhoneme.phoneme);
      if (tip != null) {
        return '💡 "${word.word}"의 "${worstPhoneme.phoneme}" 발음: $tip';
      }
    }

    return null;
  }

  /// 격려 메시지
  String _getEncouragement(PronunciationResult result) {
    final score = result.overallScore;

    if (score >= 90) {
      return '🏆 완벽해요! 원어민 수준의 발음이에요!';
    } else if (score >= 80) {
      return '🌟 훌륭해요! 거의 완벽한 발음이에요!';
    } else if (score >= 70) {
      return '👍 잘하고 있어요! 조금만 더 연습하면 완벽해질 거예요!';
    } else if (score >= 60) {
      return '💪 좋은 시도예요! 틀린 부분을 집중해서 연습해보세요!';
    } else if (score >= 50) {
      return '📚 TTS로 원어민 발음을 다시 듣고 따라해보세요!';
    } else {
      return '🎯 천천히 한 단어씩 연습해볼까요? 화이팅!';
    }
  }

  /// 요약 생성
  String _generateSummary(PronunciationResult result) {
    final incorrect = result.incorrectWords.length;
    final total = result.words.length;
    final correct = result.correctWords.length;

    if (incorrect == 0) {
      return '모든 단어를 정확하게 발음했어요!';
    } else if (incorrect <= 2) {
      final words = result.incorrectWords.map((w) => '"${w.word}"').join(', ');
      return '$words 발음을 다시 연습해보세요.';
    } else {
      return '$total개 중 $correct개 정확, ${incorrect}개 개선 필요';
    }
  }
}

/// 발음 피드백 결과
class PronunciationFeedback {
  final String summary;
  final List<FeedbackDetail> details;
  final List<String> tips;
  final String encouragement;
  final double overallScore;
  final double accuracyScore;
  final double fluencyScore;
  final double prosodyScore;

  PronunciationFeedback({
    required this.summary,
    required this.details,
    required this.tips,
    required this.encouragement,
    this.overallScore = 0,
    this.accuracyScore = 0,
    this.fluencyScore = 0,
    this.prosodyScore = 0,
  });

  bool get hasIssues => details.isNotEmpty;

  List<FeedbackDetail> get incorrectWords =>
      details.where((d) => d.status == FeedbackStatus.incorrect).toList();

  List<FeedbackDetail> get omittedWords =>
      details.where((d) => d.status == FeedbackStatus.omitted).toList();
}

/// 피드백 상세
class FeedbackDetail {
  final String word;
  final double score;
  final FeedbackStatus status;
  final String message;
  final List<PhonemeIssue> phonemeIssues;
  final String? errorType;

  FeedbackDetail({
    required this.word,
    required this.score,
    required this.status,
    required this.message,
    this.phonemeIssues = const [],
    this.errorType,
  });
}

/// 음소 이슈
class PhonemeIssue {
  final String phoneme;
  final double score;
  final String koreanHint;
  final String? tip;

  PhonemeIssue({
    required this.phoneme,
    required this.score,
    required this.koreanHint,
    this.tip,
  });
}

/// 피드백 상태
enum FeedbackStatus {
  correct,
  needsImprovement,
  incorrect,
  omitted,
}
