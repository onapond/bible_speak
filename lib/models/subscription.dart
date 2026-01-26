/// 구독 플랜 정의
enum SubscriptionPlan {
  free('free', '무료', 0),
  monthly('bible_speak_premium_monthly', '월간 프리미엄', 4900),
  yearly('bible_speak_premium_yearly', '연간 프리미엄', 39000);

  final String productId;
  final String displayName;
  final int priceKRW;

  const SubscriptionPlan(this.productId, this.displayName, this.priceKRW);

  /// 월 환산 가격
  int get monthlyEquivalent {
    switch (this) {
      case SubscriptionPlan.free:
        return 0;
      case SubscriptionPlan.monthly:
        return priceKRW;
      case SubscriptionPlan.yearly:
        return (priceKRW / 12).round();
    }
  }

  /// 할인율 (연간 대비)
  int get discountPercent {
    if (this == SubscriptionPlan.yearly) {
      final monthlyTotal = SubscriptionPlan.monthly.priceKRW * 12;
      return ((monthlyTotal - priceKRW) / monthlyTotal * 100).round();
    }
    return 0;
  }

  /// Product ID로 플랜 찾기
  static SubscriptionPlan? fromProductId(String productId) {
    for (final plan in SubscriptionPlan.values) {
      if (plan.productId == productId) return plan;
    }
    return null;
  }
}

/// 사용자 구독 상태
class UserSubscription {
  final SubscriptionPlan plan;
  final DateTime? expiryDate;
  final String? originalTransactionId;
  final bool isActive;

  const UserSubscription({
    required this.plan,
    this.expiryDate,
    this.originalTransactionId,
    this.isActive = false,
  });

  /// 무료 플랜 기본값
  factory UserSubscription.free() {
    return const UserSubscription(
      plan: SubscriptionPlan.free,
      isActive: false,
    );
  }

  /// Firestore에서 로드
  factory UserSubscription.fromMap(Map<String, dynamic> map) {
    final planId = map['planId'] as String? ?? 'free';
    final plan = SubscriptionPlan.fromProductId(planId) ?? SubscriptionPlan.free;

    DateTime? expiryDate;
    if (map['expiryDate'] != null) {
      expiryDate = DateTime.tryParse(map['expiryDate'].toString());
    }

    final isActive = map['isActive'] as bool? ?? false;

    return UserSubscription(
      plan: plan,
      expiryDate: expiryDate,
      originalTransactionId: map['originalTransactionId'] as String?,
      isActive: isActive && (expiryDate?.isAfter(DateTime.now()) ?? false),
    );
  }

  /// Firestore 저장용
  Map<String, dynamic> toMap() {
    return {
      'planId': plan.productId,
      'expiryDate': expiryDate?.toIso8601String(),
      'originalTransactionId': originalTransactionId,
      'isActive': isActive,
    };
  }

  /// 프리미엄 여부
  bool get isPremium => isActive && plan != SubscriptionPlan.free;

  /// 만료까지 남은 일수
  int? get daysRemaining {
    if (expiryDate == null) return null;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// 상태 복사
  UserSubscription copyWith({
    SubscriptionPlan? plan,
    DateTime? expiryDate,
    String? originalTransactionId,
    bool? isActive,
  }) {
    return UserSubscription(
      plan: plan ?? this.plan,
      expiryDate: expiryDate ?? this.expiryDate,
      originalTransactionId: originalTransactionId ?? this.originalTransactionId,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// 프리미엄 기능 목록
class PremiumFeature {
  final String title;
  final String description;
  final String icon;
  final bool availableInFree;

  const PremiumFeature({
    required this.title,
    required this.description,
    required this.icon,
    this.availableInFree = false,
  });

  static const List<PremiumFeature> all = [
    PremiumFeature(
      title: '무제한 학습',
      description: '하루 3구절 제한 없이 모든 구절 학습',
      icon: '♾️',
    ),
    PremiumFeature(
      title: '전체 성경 콘텐츠',
      description: '말라기, 에베소서, 히브리서 등 전체 접근',
      icon: '📖',
    ),
    PremiumFeature(
      title: '상세 발음 분석',
      description: '음소별 피드백, 유창성, 운율 분석',
      icon: '🎯',
    ),
    PremiumFeature(
      title: 'AI 맞춤 피드백',
      description: 'Gemini AI가 제공하는 개인화 학습 조언',
      icon: '🤖',
    ),
    PremiumFeature(
      title: '광고 제거',
      description: '방해 없는 집중 학습 환경',
      icon: '🚫',
    ),
    PremiumFeature(
      title: '오프라인 모드',
      description: '인터넷 없이도 캐시된 구절 학습',
      icon: '📴',
    ),
  ];
}

/// 무료 사용 제한
class FreeTierLimits {
  /// 하루 최대 학습 구절 수
  static const int dailyVerseLimit = 3;

  /// 무료로 접근 가능한 책
  static const List<String> freeBooks = ['malachi'];

  /// 무료로 접근 가능한 챕터 (책별)
  static const Map<String, List<int>> freeChapters = {
    'malachi': [1],
  };

  /// 해당 책이 무료 접근 가능한지
  static bool isBookFree(String bookId) {
    return freeBooks.contains(bookId.toLowerCase());
  }

  /// 해당 챕터가 무료 접근 가능한지
  static bool isChapterFree(String bookId, int chapter) {
    final chapters = freeChapters[bookId.toLowerCase()];
    if (chapters == null) return false;
    return chapters.contains(chapter);
  }
}
