/// 오늘의 구절 모델
class DailyVerse {
  final String reference; // "잠언 9:10"
  final String bookId; // "proverbs"
  final int chapter;
  final int verse;
  final String textEn;
  final String textKo;
  final String date; // "2026-01-27"
  final String source; // "seasonal", "personal", "group", "curated"

  const DailyVerse({
    required this.reference,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.textEn,
    required this.textKo,
    required this.date,
    required this.source,
  });

  factory DailyVerse.fromMap(Map<String, dynamic> data) {
    return DailyVerse(
      reference: data['reference'] ?? '',
      bookId: data['bookId'] ?? '',
      chapter: data['chapter'] ?? 1,
      verse: data['verse'] ?? 1,
      textEn: data['textEn'] ?? '',
      textKo: data['textKo'] ?? '',
      date: data['date'] ?? '',
      source: data['source'] ?? 'curated',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reference': reference,
      'bookId': bookId,
      'chapter': chapter,
      'verse': verse,
      'textEn': textEn,
      'textKo': textKo,
      'date': date,
      'source': source,
    };
  }
}

/// Early Bird 보너스 정보
class EarlyBirdBonus {
  final int bonusAmount;
  final String message;
  final String emoji;
  final bool isEligible;

  const EarlyBirdBonus({
    required this.bonusAmount,
    required this.message,
    required this.emoji,
    required this.isEligible,
  });

  static EarlyBirdBonus calculate(DateTime time) {
    final hour = time.hour;

    if (hour >= 5 && hour < 6) {
      return const EarlyBirdBonus(
        bonusAmount: 3,
        message: '새벽 기도의 시간!',
        emoji: '🌅',
        isEligible: true,
      );
    } else if (hour >= 6 && hour < 7) {
      return const EarlyBirdBonus(
        bonusAmount: 2,
        message: '아침 골든타임!',
        emoji: '☀️',
        isEligible: true,
      );
    } else if (hour >= 7 && hour < 8) {
      return const EarlyBirdBonus(
        bonusAmount: 1,
        message: '좋은 아침이에요!',
        emoji: '🌤️',
        isEligible: true,
      );
    } else {
      return const EarlyBirdBonus(
        bonusAmount: 0,
        message: '오늘도 화이팅!',
        emoji: '💪',
        isEligible: false,
      );
    }
  }
}

/// 시즌별 구절 정의
class SeasonalVerse {
  final String season;
  final String reference;
  final String bookId;
  final int chapter;
  final int verse;
  final String textKo;

  const SeasonalVerse({
    required this.season,
    required this.reference,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.textKo,
  });

  /// 시즌 구절 풀
  static const List<SeasonalVerse> pool = [
    // 신년 (1/1-1/7)
    SeasonalVerse(
      season: 'newyear',
      reference: '여호수아 1:9',
      bookId: 'joshua',
      chapter: 1,
      verse: 9,
      textKo: '내가 네게 명령한 것이 아니냐 강하고 담대하라 두려워하지 말며 놀라지 말라 네가 어디로 가든지 네 하나님 여호와가 너와 함께 하느니라',
    ),
    SeasonalVerse(
      season: 'newyear',
      reference: '잠언 16:3',
      bookId: 'proverbs',
      chapter: 16,
      verse: 3,
      textKo: '너의 행사를 여호와께 맡기라 그리하면 네가 경영하는 것이 이루어지리라',
    ),
    SeasonalVerse(
      season: 'newyear',
      reference: '예레미야 29:11',
      bookId: 'jeremiah',
      chapter: 29,
      verse: 11,
      textKo: '여호와의 말씀이니라 너희를 향한 나의 생각을 내가 아나니 평안이요 재앙이 아니니라 너희에게 미래와 희망을 주는 것이니라',
    ),
    // 성탄절 (12/20-12/25)
    SeasonalVerse(
      season: 'christmas',
      reference: '누가복음 2:11',
      bookId: 'luke',
      chapter: 2,
      verse: 11,
      textKo: '오늘 다윗의 동네에 너희를 위하여 구주가 나셨으니 곧 그리스도 주시니라',
    ),
    SeasonalVerse(
      season: 'christmas',
      reference: '이사야 9:6',
      bookId: 'isaiah',
      chapter: 9,
      verse: 6,
      textKo: '이는 한 아기가 우리에게 났고 한 아들을 우리에게 주신 바 되었는데 그의 어깨에는 정사를 메었고 그의 이름은 기묘자라, 모사라, 전능하신 하나님이라, 영존하시는 아버지라, 평강의 왕이라 할 것임이라',
    ),
  ];

  /// 현재 시즌에 맞는 구절 가져오기
  static SeasonalVerse? getForDate(DateTime date) {
    final month = date.month;
    final day = date.day;

    // 신년 (1/1-1/7)
    if (month == 1 && day <= 7) {
      final verses = pool.where((v) => v.season == 'newyear').toList();
      if (verses.isNotEmpty) {
        return verses[day % verses.length];
      }
    }

    // 성탄절 (12/20-12/25)
    if (month == 12 && day >= 20 && day <= 25) {
      final verses = pool.where((v) => v.season == 'christmas').toList();
      if (verses.isNotEmpty) {
        return verses[(day - 20) % verses.length];
      }
    }

    return null;
  }
}

/// 큐레이션된 명구절 풀
class CuratedVerses {
  static const List<Map<String, dynamic>> pool = [
    {
      'reference': '잠언 9:10',
      'bookId': 'proverbs',
      'chapter': 9,
      'verse': 10,
      'textKo': '여호와를 경외하는 것이 지혜의 근본이요 거룩하신 자를 아는 것이 명철이니라',
    },
    {
      'reference': '시편 23:1',
      'bookId': 'psalms',
      'chapter': 23,
      'verse': 1,
      'textKo': '여호와는 나의 목자시니 내게 부족함이 없으리로다',
    },
    {
      'reference': '시편 119:105',
      'bookId': 'psalms',
      'chapter': 119,
      'verse': 105,
      'textKo': '주의 말씀은 내 발에 등이요 내 길에 빛이니이다',
    },
    {
      'reference': '요한복음 3:16',
      'bookId': 'john',
      'chapter': 3,
      'verse': 16,
      'textKo': '하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라',
    },
    {
      'reference': '빌립보서 4:13',
      'bookId': 'philippians',
      'chapter': 4,
      'verse': 13,
      'textKo': '내게 능력 주시는 자 안에서 내가 모든 것을 할 수 있느니라',
    },
    {
      'reference': '로마서 8:28',
      'bookId': 'romans',
      'chapter': 8,
      'verse': 28,
      'textKo': '우리가 알거니와 하나님을 사랑하는 자 곧 그의 뜻대로 부르심을 입은 자들에게는 모든 것이 합력하여 선을 이루느니라',
    },
    {
      'reference': '이사야 40:31',
      'bookId': 'isaiah',
      'chapter': 40,
      'verse': 31,
      'textKo': '오직 여호와를 앙망하는 자는 새 힘을 얻으리니 독수리가 날개치며 올라감 같을 것이요 달음박질하여도 곤비하지 아니하겠고 걸어가도 피곤하지 아니하리로다',
    },
    {
      'reference': '마태복음 11:28',
      'bookId': 'matthew',
      'chapter': 11,
      'verse': 28,
      'textKo': '수고하고 무거운 짐 진 자들아 다 내게로 오라 내가 너희를 쉬게 하리라',
    },
    {
      'reference': '히브리서 11:1',
      'bookId': 'hebrews',
      'chapter': 11,
      'verse': 1,
      'textKo': '믿음은 바라는 것들의 실상이요 보이지 않는 것들의 증거니',
    },
    {
      'reference': '고린도전서 13:4',
      'bookId': '1corinthians',
      'chapter': 13,
      'verse': 4,
      'textKo': '사랑은 오래 참고 사랑은 온유하며 시기하지 아니하며 사랑은 자랑하지 아니하며 교만하지 아니하며',
    },
  ];

  /// 날짜 기반 구절 선택 (같은 날에는 같은 구절)
  static Map<String, dynamic> getForDate(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final index = dayOfYear % pool.length;
    return pool[index];
  }
}
