import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/achievement.dart';

/// 업적 관리 서비스
class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 업적 조회
  // ============================================================

  /// 사용자의 모든 업적 진행 상태 가져오기
  Future<List<UserAchievement>> getUserAchievements() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .get();

      final userAchievements = <String, UserAchievement>{};

      // Firestore에서 가져온 데이터
      for (final doc in snapshot.docs) {
        userAchievements[doc.id] = UserAchievement.fromFirestore(doc.data());
      }

      // 모든 업적에 대해 진행 상태 반환 (없으면 기본값)
      return Achievement.all.map((ach) {
        return userAchievements[ach.id] ?? UserAchievement(achievementId: ach.id);
      }).toList();
    } catch (e) {
      print('Get achievements error: $e');
      return Achievement.all
          .map((ach) => UserAchievement(achievementId: ach.id))
          .toList();
    }
  }

  /// 해금된 업적만 가져오기
  Future<List<UserAchievement>> getUnlockedAchievements() async {
    final all = await getUserAchievements();
    return all.where((ua) => ua.isUnlocked).toList();
  }

  /// 특정 업적 진행 상태 가져오기
  Future<UserAchievement?> getAchievement(String achievementId) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievementId)
          .get();

      if (doc.exists) {
        return UserAchievement.fromFirestore(doc.data()!);
      }
      return UserAchievement(achievementId: achievementId);
    } catch (e) {
      print('Get achievement error: $e');
      return null;
    }
  }

  // ============================================================
  // 업적 진행/해금
  // ============================================================

  /// 업적 진행 업데이트 (자동 해금 체크)
  Future<UnlockResult?> updateProgress(String achievementId, int newProgress) async {
    final userId = currentUserId;
    if (userId == null) return null;

    final achievement = Achievement.findById(achievementId);
    if (achievement == null) return null;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievementId);

      final doc = await docRef.get();
      final current = doc.exists
          ? UserAchievement.fromFirestore(doc.data()!)
          : UserAchievement(achievementId: achievementId);

      // 이미 해금된 경우 스킵
      if (current.isUnlocked) return null;

      // 진행 업데이트
      final shouldUnlock = newProgress >= achievement.requirement;

      await docRef.set({
        'achievementId': achievementId,
        'progress': newProgress,
        'isUnlocked': shouldUnlock,
        'unlockedAt': shouldUnlock ? FieldValue.serverTimestamp() : null,
        'isRewardClaimed': false,
      }, SetOptions(merge: true));

      if (shouldUnlock) {
        return UnlockResult(
          achievement: achievement,
          isNewUnlock: true,
        );
      }
      return null;
    } catch (e) {
      print('Update progress error: $e');
      return null;
    }
  }

  /// 진행량 증가 (현재 + delta)
  Future<UnlockResult?> incrementProgress(String achievementId, int delta) async {
    final userId = currentUserId;
    if (userId == null) return null;

    final achievement = Achievement.findById(achievementId);
    if (achievement == null) return null;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievementId);

      final doc = await docRef.get();
      final current = doc.exists
          ? UserAchievement.fromFirestore(doc.data()!)
          : UserAchievement(achievementId: achievementId);

      // 이미 해금된 경우 스킵
      if (current.isUnlocked) return null;

      final newProgress = current.progress + delta;
      return await updateProgress(achievementId, newProgress);
    } catch (e) {
      print('Increment progress error: $e');
      return null;
    }
  }

  /// 보상 수령
  Future<bool> claimReward(String achievementId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final achievement = Achievement.findById(achievementId);
    if (achievement == null) return false;

    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final achievementRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('achievements')
            .doc(achievementId);

        final achievementDoc = await transaction.get(achievementRef);

        if (!achievementDoc.exists) return false;

        final userAch = UserAchievement.fromFirestore(achievementDoc.data()!);

        if (!userAch.isUnlocked || userAch.isRewardClaimed) return false;

        // 보상 지급 (set + merge로 필드 없어도 안전)
        final userRef = _firestore.collection('users').doc(userId);
        transaction.set(userRef, {
          'talants': FieldValue.increment(achievement.talantReward),
          'totalTalants': FieldValue.increment(achievement.talantReward),
        }, SetOptions(merge: true));

        // 보상 수령 표시
        transaction.set(achievementRef, {
          'isRewardClaimed': true,
        }, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      print('Claim reward error: $e');
      return false;
    }
  }

  // ============================================================
  // 통합 업적 체크
  // ============================================================

  /// 스트릭 업적 체크
  Future<List<UnlockResult>> checkStreakAchievements(int currentStreak) async {
    final results = <UnlockResult>[];

    final streakAchievements = [
      'streak_3',
      'streak_7',
      'streak_14',
      'streak_30',
      'streak_100',
    ];

    for (final id in streakAchievements) {
      final result = await updateProgress(id, currentStreak);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  /// 구절 암송 업적 체크
  Future<List<UnlockResult>> checkVerseAchievements(int completedVerses) async {
    final results = <UnlockResult>[];

    final verseAchievements = [
      'verse_1',
      'verse_10',
      'verse_50',
      'verse_100',
      'verse_200',
    ];

    for (final id in verseAchievements) {
      final result = await updateProgress(id, completedVerses);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  /// 탈란트 업적 체크
  Future<List<UnlockResult>> checkTalantAchievements(int totalTalants) async {
    final results = <UnlockResult>[];

    final talantAchievements = [
      'talant_100',
      'talant_500',
      'talant_1000',
      'talant_5000',
      'talant_10000',
    ];

    for (final id in talantAchievements) {
      final result = await updateProgress(id, totalTalants);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  /// 넛지 업적 체크
  Future<UnlockResult?> checkNudgeAchievements(int nudgeCount) async {
    if (nudgeCount >= 10) {
      return await updateProgress('social_nudge_10', nudgeCount);
    } else if (nudgeCount >= 1) {
      return await updateProgress('social_nudge_1', nudgeCount);
    }
    return null;
  }

  /// 반응 업적 체크
  Future<UnlockResult?> checkReactionAchievements(int reactionCount) async {
    if (reactionCount >= 50) {
      return await updateProgress('social_reaction_50', reactionCount);
    } else if (reactionCount >= 10) {
      return await updateProgress('social_reaction_10', reactionCount);
    }
    return null;
  }

  /// 시간대 업적 체크 (얼리버드/밤올빼미)
  Future<UnlockResult?> checkTimeAchievements() async {
    final now = DateTime.now();

    if (now.hour < 6) {
      // 얼리버드: 오전 6시 이전
      return await updateProgress('special_early_bird', 1);
    } else if (now.hour >= 0 && now.hour < 1) {
      // 밤올빼미: 자정~새벽 1시
      return await updateProgress('special_night_owl', 1);
    }
    return null;
  }

  /// 랭킹 1위 업적 체크
  Future<UnlockResult?> checkFirstPlaceAchievement() async {
    return await updateProgress('special_first_place', 1);
  }

  // ============================================================
  // 통계
  // ============================================================

  /// 업적 통계 가져오기
  Future<AchievementStats> getStats() async {
    final achievements = await getUserAchievements();

    final unlocked = achievements.where((a) => a.isUnlocked).length;
    final total = Achievement.all.length;
    final unclaimed = achievements
        .where((a) => a.isUnlocked && !a.isRewardClaimed)
        .length;

    return AchievementStats(
      totalAchievements: total,
      unlockedCount: unlocked,
      unclaimedRewards: unclaimed,
    );
  }
}

/// 업적 해금 결과
class UnlockResult {
  final Achievement achievement;
  final bool isNewUnlock;

  const UnlockResult({
    required this.achievement,
    required this.isNewUnlock,
  });
}

/// 업적 통계
class AchievementStats {
  final int totalAchievements;
  final int unlockedCount;
  final int unclaimedRewards;

  const AchievementStats({
    required this.totalAchievements,
    required this.unlockedCount,
    required this.unclaimedRewards,
  });

  double get progressRate => totalAchievements > 0
      ? unlockedCount / totalAchievements
      : 0;

  int get progressPercent => (progressRate * 100).round();
}
