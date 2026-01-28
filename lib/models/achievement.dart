import 'package:flutter/material.dart';

/// 업적 카테고리
enum AchievementCategory {
  streak('연속 학습', Icons.local_fire_department),
  verse('구절 암송', Icons.menu_book),
  talant('탈란트', Icons.toll),
  social('소셜', Icons.people),
  special('특별', Icons.star);

  final String label;
  final IconData icon;

  const AchievementCategory(this.label, this.icon);
}

/// 업적 등급
enum AchievementTier {
  bronze('브론즈', Color(0xFFCD7F32), 1),
  silver('실버', Color(0xFFC0C0C0), 2),
  gold('골드', Color(0xFFFFD700), 3),
  platinum('플래티넘', Color(0xFFE5E4E2), 4),
  diamond('다이아', Color(0xFFB9F2FF), 5);

  final String label;
  final Color color;
  final int level;

  const AchievementTier(this.label, this.color, this.level);
}

/// 업적 정의
class Achievement {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final AchievementCategory category;
  final AchievementTier tier;
  final int requirement;
  final int talantReward;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.tier,
    required this.requirement,
    required this.talantReward,
  });

  /// 기본 업적 목록
  static const List<Achievement> all = [
    // ============================================================
    // 연속 학습 업적
    // ============================================================
    Achievement(
      id: 'streak_3',
      name: '첫 걸음',
      description: '3일 연속 학습',
      emoji: '🔥',
      category: AchievementCategory.streak,
      tier: AchievementTier.bronze,
      requirement: 3,
      talantReward: 10,
    ),
    Achievement(
      id: 'streak_7',
      name: '일주일 도전',
      description: '7일 연속 학습',
      emoji: '🔥',
      category: AchievementCategory.streak,
      tier: AchievementTier.silver,
      requirement: 7,
      talantReward: 30,
    ),
    Achievement(
      id: 'streak_14',
      name: '2주 습관',
      description: '14일 연속 학습',
      emoji: '🔥',
      category: AchievementCategory.streak,
      tier: AchievementTier.gold,
      requirement: 14,
      talantReward: 50,
    ),
    Achievement(
      id: 'streak_30',
      name: '한 달 마스터',
      description: '30일 연속 학습',
      emoji: '🔥',
      category: AchievementCategory.streak,
      tier: AchievementTier.platinum,
      requirement: 30,
      talantReward: 100,
    ),
    Achievement(
      id: 'streak_100',
      name: '100일 전설',
      description: '100일 연속 학습',
      emoji: '👑',
      category: AchievementCategory.streak,
      tier: AchievementTier.diamond,
      requirement: 100,
      talantReward: 300,
    ),

    // ============================================================
    // 구절 암송 업적
    // ============================================================
    Achievement(
      id: 'verse_1',
      name: '첫 구절',
      description: '첫 번째 구절 완료',
      emoji: '📖',
      category: AchievementCategory.verse,
      tier: AchievementTier.bronze,
      requirement: 1,
      talantReward: 5,
    ),
    Achievement(
      id: 'verse_10',
      name: '입문자',
      description: '10개 구절 완료',
      emoji: '📖',
      category: AchievementCategory.verse,
      tier: AchievementTier.silver,
      requirement: 10,
      talantReward: 20,
    ),
    Achievement(
      id: 'verse_50',
      name: '암송가',
      description: '50개 구절 완료',
      emoji: '📚',
      category: AchievementCategory.verse,
      tier: AchievementTier.gold,
      requirement: 50,
      talantReward: 80,
    ),
    Achievement(
      id: 'verse_100',
      name: '숙련자',
      description: '100개 구절 완료',
      emoji: '📚',
      category: AchievementCategory.verse,
      tier: AchievementTier.platinum,
      requirement: 100,
      talantReward: 150,
    ),
    Achievement(
      id: 'verse_200',
      name: '암송 마스터',
      description: '200개 구절 완료',
      emoji: '🏆',
      category: AchievementCategory.verse,
      tier: AchievementTier.diamond,
      requirement: 200,
      talantReward: 500,
    ),

    // ============================================================
    // 탈란트 업적
    // ============================================================
    Achievement(
      id: 'talant_100',
      name: '첫 탈란트',
      description: '총 100 탈란트 획득',
      emoji: '💰',
      category: AchievementCategory.talant,
      tier: AchievementTier.bronze,
      requirement: 100,
      talantReward: 10,
    ),
    Achievement(
      id: 'talant_500',
      name: '부자의 길',
      description: '총 500 탈란트 획득',
      emoji: '💰',
      category: AchievementCategory.talant,
      tier: AchievementTier.silver,
      requirement: 500,
      talantReward: 30,
    ),
    Achievement(
      id: 'talant_1000',
      name: '탈란트 부자',
      description: '총 1000 탈란트 획득',
      emoji: '💎',
      category: AchievementCategory.talant,
      tier: AchievementTier.gold,
      requirement: 1000,
      talantReward: 50,
    ),
    Achievement(
      id: 'talant_5000',
      name: '탈란트 수집가',
      description: '총 5000 탈란트 획득',
      emoji: '💎',
      category: AchievementCategory.talant,
      tier: AchievementTier.platinum,
      requirement: 5000,
      talantReward: 100,
    ),
    Achievement(
      id: 'talant_10000',
      name: '탈란트 대부호',
      description: '총 10000 탈란트 획득',
      emoji: '👑',
      category: AchievementCategory.talant,
      tier: AchievementTier.diamond,
      requirement: 10000,
      talantReward: 300,
    ),

    // ============================================================
    // 소셜 업적
    // ============================================================
    Achievement(
      id: 'social_nudge_1',
      name: '첫 넛지',
      description: '첫 번째 넛지 보내기',
      emoji: '👋',
      category: AchievementCategory.social,
      tier: AchievementTier.bronze,
      requirement: 1,
      talantReward: 5,
    ),
    Achievement(
      id: 'social_nudge_10',
      name: '응원단장',
      description: '10번 넛지 보내기',
      emoji: '📣',
      category: AchievementCategory.social,
      tier: AchievementTier.silver,
      requirement: 10,
      talantReward: 20,
    ),
    Achievement(
      id: 'social_reaction_10',
      name: '리액션 마스터',
      description: '10번 반응 보내기',
      emoji: '👏',
      category: AchievementCategory.social,
      tier: AchievementTier.bronze,
      requirement: 10,
      talantReward: 10,
    ),
    Achievement(
      id: 'social_reaction_50',
      name: '열정 응원러',
      description: '50번 반응 보내기',
      emoji: '🎉',
      category: AchievementCategory.social,
      tier: AchievementTier.silver,
      requirement: 50,
      talantReward: 30,
    ),

    // ============================================================
    // 특별 업적
    // ============================================================
    Achievement(
      id: 'special_early_bird',
      name: '얼리버드',
      description: '오전 6시 이전에 학습 완료',
      emoji: '🌅',
      category: AchievementCategory.special,
      tier: AchievementTier.silver,
      requirement: 1,
      talantReward: 20,
    ),
    Achievement(
      id: 'special_night_owl',
      name: '밤올빼미',
      description: '자정 이후에 학습 완료',
      emoji: '🦉',
      category: AchievementCategory.special,
      tier: AchievementTier.silver,
      requirement: 1,
      talantReward: 20,
    ),
    Achievement(
      id: 'special_perfect_week',
      name: '완벽한 주',
      description: '7일 연속 목표 100% 달성',
      emoji: '⭐',
      category: AchievementCategory.special,
      tier: AchievementTier.gold,
      requirement: 7,
      talantReward: 50,
    ),
    Achievement(
      id: 'special_first_place',
      name: '챔피언',
      description: '그룹 랭킹 1위 달성',
      emoji: '🏆',
      category: AchievementCategory.special,
      tier: AchievementTier.platinum,
      requirement: 1,
      talantReward: 100,
    ),
  ];

  /// ID로 업적 찾기
  static Achievement? findById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 카테고리별 업적 가져오기
  static List<Achievement> byCategory(AchievementCategory category) {
    return all.where((a) => a.category == category).toList();
  }
}

/// 사용자의 업적 진행 상태
class UserAchievement {
  final String achievementId;
  final int progress;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final bool isRewardClaimed;

  const UserAchievement({
    required this.achievementId,
    this.progress = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    this.isRewardClaimed = false,
  });

  factory UserAchievement.fromFirestore(Map<String, dynamic> data) {
    return UserAchievement(
      achievementId: data['achievementId'] ?? '',
      progress: data['progress'] ?? 0,
      isUnlocked: data['isUnlocked'] ?? false,
      unlockedAt: data['unlockedAt']?.toDate(),
      isRewardClaimed: data['isRewardClaimed'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'achievementId': achievementId,
      'progress': progress,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt,
      'isRewardClaimed': isRewardClaimed,
    };
  }

  /// 업적 정보와 함께 반환
  Achievement? get achievement => Achievement.findById(achievementId);

  /// 진행률 (0.0 ~ 1.0)
  double get progressRate {
    final ach = achievement;
    if (ach == null || ach.requirement == 0) return 0;
    return (progress / ach.requirement).clamp(0.0, 1.0);
  }

  /// 진행률 퍼센트
  int get progressPercent => (progressRate * 100).round();

  UserAchievement copyWith({
    int? progress,
    bool? isUnlocked,
    DateTime? unlockedAt,
    bool? isRewardClaimed,
  }) {
    return UserAchievement(
      achievementId: achievementId,
      progress: progress ?? this.progress,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isRewardClaimed: isRewardClaimed ?? this.isRewardClaimed,
    );
  }
}
