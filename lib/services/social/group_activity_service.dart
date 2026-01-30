import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_activity.dart';

/// Group Activity Service
/// Manages activity stream with 7-day TTL and reactions
class GroupActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _ttlDays = 7;
  static const int _pageSize = 20;

  /// Current user ID (exposed for widgets)
  String? get currentUserId => _auth.currentUser?.uid;

  /// Collection reference for a group's activities
  CollectionReference<Map<String, dynamic>> _activitiesRef(String groupId) {
    return _firestore.collection('groups').doc(groupId).collection('activities');
  }

  // ============================================================
  // READ Operations
  // ============================================================

  /// Watch recent activities (real-time stream)
  Stream<List<GroupActivity>> watchActivities(String groupId) {
    return _activitiesRef(groupId)
        .where('isHidden', isEqualTo: false)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupActivity.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Fetch activities since last fetch time (cost-efficient polling)
  Future<List<GroupActivity>> getActivitiesSince(
    String groupId,
    DateTime since,
  ) async {
    final snapshot = await _activitiesRef(groupId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();

    return snapshot.docs
        .map((doc) => GroupActivity.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Get initial activities (for first load)
  Future<List<GroupActivity>> getRecentActivities(String groupId) async {
    final snapshot = await _activitiesRef(groupId)
        .where('isHidden', isEqualTo: false)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();

    return snapshot.docs
        .map((doc) => GroupActivity.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  // ============================================================
  // WRITE Operations
  // ============================================================

  /// Create a new activity with automatic TTL
  Future<String?> createActivity({
    required String groupId,
    required ActivityType type,
    required String userName,
    String? userPhotoUrl,
    String? verseRef,
    int? milestone,
    String? bookName,
  }) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: _ttlDays));

      final activityData = {
        'type': type.value,
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'verseRef': verseRef,
        'milestone': milestone,
        'bookName': bookName,
        'reactions': {
          'clap': <String>[],
          'pray': <String>[],
          'fighting': <String>[],
        },
        'reactionCounts': {
          'clap': 0,
          'pray': 0,
          'fighting': 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isHidden': false,
      };

      final docRef = await _activitiesRef(groupId).add(activityData);
      return docRef.id;
    } catch (e) {
      print('Activity creation error: $e');
      return null;
    }
  }

  /// Post verse completion activity (with duplicate prevention)
  Future<bool> postVerseComplete({
    required String groupId,
    required String userName,
    required String verseRef,
    bool isStage3 = false,
  }) async {
    final userId = currentUserId;
    if (userId == null) return false;

    // Check for duplicate today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final existing = await _activitiesRef(groupId)
        .where('userId', isEqualTo: userId)
        .where('verseRef', isEqualTo: verseRef)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return false; // Already posted today
    }

    final activityId = await createActivity(
      groupId: groupId,
      type: isStage3 ? ActivityType.stage3Clear : ActivityType.verseComplete,
      userName: userName,
      verseRef: verseRef,
    );

    return activityId != null;
  }

  /// Post streak milestone activity
  Future<bool> postStreakMilestone({
    required String groupId,
    required String userName,
    required int milestone,
  }) async {
    final userId = currentUserId;
    if (userId == null) return false;

    // Only post for specific milestones
    const milestones = [3, 7, 14, 21, 30, 100, 365];
    if (!milestones.contains(milestone)) return false;

    // Check if already posted this milestone
    final existing = await _activitiesRef(groupId)
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: ActivityType.streakMilestone.value)
        .where('milestone', isEqualTo: milestone)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return false;

    final activityId = await createActivity(
      groupId: groupId,
      type: ActivityType.streakMilestone,
      userName: userName,
      milestone: milestone,
    );

    return activityId != null;
  }

  // ============================================================
  // REACTION Operations (Optimized)
  // ============================================================

  /// Toggle reaction (add or remove)
  /// Returns the new state (true = added, false = removed, null = error)
  Future<bool?> toggleReaction({
    required String groupId,
    required String activityId,
    required ReactionType type,
  }) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final activityRef = _activitiesRef(groupId).doc(activityId);

      // Use transaction for atomic read-modify-write
      return await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(activityRef);
        if (!snapshot.exists) return false;

        final reactions = snapshot.data()?['reactions'] as Map<String, dynamic>? ?? {};
        final userList = List<String>.from(reactions[type.value] ?? []);
        final hasReacted = userList.contains(userId);

        if (hasReacted) {
          // Remove reaction (set + merge로 필드 없어도 안전)
          transaction.set(activityRef, {
            'reactions': {type.value: FieldValue.arrayRemove([userId])},
            'reactionCounts': {type.value: FieldValue.increment(-1)},
          }, SetOptions(merge: true));
          return false;
        } else {
          // Add reaction (set + merge로 필드 없어도 안전)
          transaction.set(activityRef, {
            'reactions': {type.value: FieldValue.arrayUnion([userId])},
            'reactionCounts': {type.value: FieldValue.increment(1)},
          }, SetOptions(merge: true));
          return true;
        }
      });
    } catch (e) {
      print('Reaction toggle error: $e');
      return null;
    }
  }

  /// Add reaction (optimistic update friendly)
  Future<bool> addReaction({
    required String groupId,
    required String activityId,
    required ReactionType type,
  }) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      // set + merge로 필드 없어도 안전
      await _activitiesRef(groupId).doc(activityId).set({
        'reactions': {type.value: FieldValue.arrayUnion([userId])},
        'reactionCounts': {type.value: FieldValue.increment(1)},
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Add reaction error: $e');
      return false;
    }
  }

  /// Remove reaction (optimistic update friendly)
  Future<bool> removeReaction({
    required String groupId,
    required String activityId,
    required ReactionType type,
  }) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      // set + merge로 필드 없어도 안전
      await _activitiesRef(groupId).doc(activityId).set({
        'reactions': {type.value: FieldValue.arrayRemove([userId])},
        'reactionCounts': {type.value: FieldValue.increment(-1)},
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Remove reaction error: $e');
      return false;
    }
  }

  // ============================================================
  // CLEANUP Operations (for Cloud Function migration)
  // ============================================================

  /// Delete expired activities (call from Cloud Function)
  /// In production, use Firestore TTL policy or scheduled function
  Future<int> cleanupExpiredActivities(String groupId) async {
    final now = Timestamp.now();
    final expired = await _activitiesRef(groupId)
        .where('expiresAt', isLessThan: now)
        .limit(500) // Batch limit
        .get();

    if (expired.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final doc in expired.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    return expired.docs.length;
  }

  /// Hide activity (soft delete)
  Future<bool> hideActivity(String groupId, String activityId) async {
    try {
      // set + merge로 안전하게 업데이트
      await _activitiesRef(groupId).doc(activityId).set({
        'isHidden': true,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Hide activity error: $e');
      return false;
    }
  }
}
