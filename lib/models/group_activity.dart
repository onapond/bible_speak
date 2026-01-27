import 'package:cloud_firestore/cloud_firestore.dart';

/// Activity Types
enum ActivityType {
  verseComplete('verse_complete'),
  stage3Clear('stage3_clear'),
  streakMilestone('streak_milestone'),
  bookComplete('book_complete'),
  joinedGroup('joined_group'),
  bookStart('book_start'),
  comeback('comeback');

  final String value;
  const ActivityType(this.value);

  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ActivityType.verseComplete,
    );
  }

  String get icon {
    switch (this) {
      case ActivityType.verseComplete:
        return '🎉';
      case ActivityType.stage3Clear:
        return '⭐';
      case ActivityType.streakMilestone:
        return '🔥';
      case ActivityType.bookComplete:
        return '📖';
      case ActivityType.joinedGroup:
        return '👋';
      case ActivityType.bookStart:
        return '🙏';
      case ActivityType.comeback:
        return '🎊';
    }
  }
}

/// Reaction Types
enum ReactionType {
  clap('clap', '👏', '박수'),
  pray('pray', '🙏', '기도'),
  fighting('fighting', '💪', '화이팅');

  final String value;
  final String emoji;
  final String label;
  const ReactionType(this.value, this.emoji, this.label);

  static ReactionType fromString(String value) {
    return ReactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReactionType.clap,
    );
  }
}

/// Group Activity Model
class GroupActivity {
  final String id;
  final ActivityType type;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? verseRef;
  final int? milestone;
  final String? bookName;
  final Map<ReactionType, List<String>> reactions;
  final Map<ReactionType, int> reactionCounts;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isHidden;

  const GroupActivity({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.verseRef,
    this.milestone,
    this.bookName,
    this.reactions = const {},
    this.reactionCounts = const {},
    required this.createdAt,
    required this.expiresAt,
    this.isHidden = false,
  });

  factory GroupActivity.fromFirestore(String id, Map<String, dynamic> data) {
    final reactionsData = data['reactions'] as Map<String, dynamic>? ?? {};
    final countsData = data['reactionCounts'] as Map<String, dynamic>? ?? {};

    final reactions = <ReactionType, List<String>>{};
    final counts = <ReactionType, int>{};

    for (final type in ReactionType.values) {
      final userList = reactionsData[type.value] as List<dynamic>? ?? [];
      reactions[type] = userList.cast<String>();
      counts[type] = countsData[type.value] as int? ?? 0;
    }

    return GroupActivity(
      id: id,
      type: ActivityType.fromString(data['type'] ?? 'verse_complete'),
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '익명',
      userPhotoUrl: data['userPhotoUrl'],
      verseRef: data['verseRef'],
      milestone: data['milestone'],
      bookName: data['bookName'],
      reactions: reactions,
      reactionCounts: counts,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
      isHidden: data['isHidden'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    final reactionsMap = <String, List<String>>{};
    final countsMap = <String, int>{};

    for (final type in ReactionType.values) {
      reactionsMap[type.value] = reactions[type] ?? [];
      countsMap[type.value] = reactionCounts[type] ?? 0;
    }

    return {
      'type': type.value,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'verseRef': verseRef,
      'milestone': milestone,
      'bookName': bookName,
      'reactions': reactionsMap,
      'reactionCounts': countsMap,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isHidden': isHidden,
    };
  }

  /// Get formatted message
  String get message {
    switch (type) {
      case ActivityType.verseComplete:
        return '$userName님이 $verseRef 암송 완료!';
      case ActivityType.stage3Clear:
        return '$userName님이 $verseRef 완전 암기!';
      case ActivityType.streakMilestone:
        return '$userName님이 ${milestone}일 연속 학습!';
      case ActivityType.bookComplete:
        return '$userName님이 $bookName 완독!';
      case ActivityType.joinedGroup:
        return '$userName님이 그룹에 합류!';
      case ActivityType.bookStart:
        return '$userName님이 $bookName 시작!';
      case ActivityType.comeback:
        return '$userName님이 돌아왔어요!';
    }
  }

  /// Get relative time string
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  /// Total reaction count
  int get totalReactions {
    return reactionCounts.values.fold(0, (sum, count) => sum + count);
  }

  /// Check if user has reacted with specific type
  bool hasReacted(String userId, ReactionType type) {
    return reactions[type]?.contains(userId) ?? false;
  }

  /// Copy with updated reactions (for optimistic UI)
  GroupActivity copyWithReaction({
    required String userId,
    required ReactionType type,
    required bool add,
  }) {
    final newReactions = Map<ReactionType, List<String>>.from(reactions);
    final newCounts = Map<ReactionType, int>.from(reactionCounts);

    final userList = List<String>.from(newReactions[type] ?? []);
    if (add && !userList.contains(userId)) {
      userList.add(userId);
      newCounts[type] = (newCounts[type] ?? 0) + 1;
    } else if (!add && userList.contains(userId)) {
      userList.remove(userId);
      newCounts[type] = ((newCounts[type] ?? 1) - 1).clamp(0, 999999);
    }
    newReactions[type] = userList;

    return GroupActivity(
      id: id,
      type: this.type,
      userId: this.userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      verseRef: verseRef,
      milestone: milestone,
      bookName: bookName,
      reactions: newReactions,
      reactionCounts: newCounts,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isHidden: isHidden,
    );
  }
}
