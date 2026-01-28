/// 퀴즈 유형
enum QuizType {
  /// Type A: 영어 단어 보고 한글 뜻 맞추기
  englishToKorean,

  /// Type B: 한글 뜻 보고 영어 단어 맞추기
  koreanToEnglish,

  /// Type C: 빈칸 채우기 (추후 구현)
  fillInBlank,

  /// Type D: 듣고 맞추기 (추후 구현)
  listening,
}

extension QuizTypeExtension on QuizType {
  String get displayName {
    switch (this) {
      case QuizType.englishToKorean:
        return '영어 → 한글';
      case QuizType.koreanToEnglish:
        return '한글 → 영어';
      case QuizType.fillInBlank:
        return '빈칸 채우기';
      case QuizType.listening:
        return '듣고 맞추기';
    }
  }

  String get description {
    switch (this) {
      case QuizType.englishToKorean:
        return '영어 단어를 보고 한글 뜻을 선택하세요';
      case QuizType.koreanToEnglish:
        return '한글 뜻을 보고 영어 단어를 선택하세요';
      case QuizType.fillInBlank:
        return '문장의 빈칸에 들어갈 단어를 입력하세요';
      case QuizType.listening:
        return '발음을 듣고 단어를 입력하세요';
    }
  }

  String get emoji {
    switch (this) {
      case QuizType.englishToKorean:
        return '🇺🇸';
      case QuizType.koreanToEnglish:
        return '🇰🇷';
      case QuizType.fillInBlank:
        return '📝';
      case QuizType.listening:
        return '🎧';
    }
  }

  bool get isAvailable {
    switch (this) {
      case QuizType.englishToKorean:
      case QuizType.koreanToEnglish:
      case QuizType.fillInBlank:
        return true;
      case QuizType.listening:
        return false; // 추후 구현
    }
  }
}
