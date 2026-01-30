import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/social/group_goal_widget.dart';

/// Group Challenge Service
/// Manages weekly challenges and contributions
class GroupChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current week ID (ISO format: YYYY-Www)
  String get currentWeekId {
    final now = DateTime.now();
    final weekOfYear = _weekNumber(now);
    return '${now.year}-W${weekOfYear.toString().padLeft(2, '0')}';
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  /// Collection reference for challenges
  CollectionReference<Map<String, dynamic>> _challengesRef(String groupId) {
    return _firestore.collection('groups').doc(groupId).collection('challenges');
  }

  /// Watch current week's challenge
  Stream<WeeklyChallenge?> watchCurrentChallenge(String groupId) {
    return _challengesRef(groupId)
        .doc(currentWeekId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return WeeklyChallenge.fromFirestore(snapshot.id, snapshot.data()!);
    });
  }

  /// Get current challenge
  Future<WeeklyChallenge?> getCurrentChallenge(String groupId) async {
    final doc = await _challengesRef(groupId).doc(currentWeekId).get();
    if (!doc.exists) return null;
    return WeeklyChallenge.fromFirestore(doc.id, doc.data()!);
  }

  /// Get user's contribution for current challenge
  Future<int> getMyContribution(String groupId) async {
    final userId = currentUserId;
    if (userId == null) return 0;

    final doc = await _challengesRef(groupId).doc(currentWeekId).get();
    if (!doc.exists) return 0;

    final contributors = doc.data()?['contributors'] as Map<String, dynamic>? ?? {};
    final userContrib = contributors[userId];
    if (userContrib is Map) {
      return (userContrib['count'] as num?)?.toInt() ?? 0;
    }
    return (userContrib as num?)?.toInt() ?? 0;
  }

  /// Add contribution to challenge (called when verse is completed)
  Future<bool> addContribution({
    required String groupId,
    required String userName,
    int amount = 1,
  }) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final challengeRef = _challengesRef(groupId).doc(currentWeekId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(challengeRef);

        if (!snapshot.exists) {
          // Create challenge if it doesn't exist
          final weekEnd = _getWeekEnd();
          transaction.set(challengeRef, {
            'theme': 'temple',
            'targetValue': 40,
            'currentValue': amount,
            'weekStart': Timestamp.now(),
            'weekEnd': Timestamp.fromDate(weekEnd),
            'contributors': {
              userId: {'name': userName, 'count': amount, 'lastContributed': Timestamp.now()}
            },
            'contributorCount': 1,
            'isCompleted': false,
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
        } else {
          // Update existing challenge (set + merge로 필드 없어도 안전)
          transaction.set(challengeRef, {
            'currentValue': FieldValue.increment(amount),
            'contributors': {
              userId: {
                'count': FieldValue.increment(amount),
                'name': userName,
                'lastContributed': Timestamp.now(),
              }
            },
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));
        }
      });

      return true;
    } catch (e) {
      print('Add contribution error: $e');
      return false;
    }
  }

  /// Check and mark challenge as completed
  Future<bool> checkAndCompleteChallenge(String groupId) async {
    try {
      final challenge = await getCurrentChallenge(groupId);
      if (challenge == null || challenge.isCompleted) return false;

      if (challenge.currentValue >= challenge.targetValue) {
        // set + merge로 필드 없어도 안전
        await _challengesRef(groupId).doc(currentWeekId).set({
          'isCompleted': true,
          'completedAt': Timestamp.now(),
        }, SetOptions(merge: true));
        return true;
      }
      return false;
    } catch (e) {
      print('Check challenge completion error: $e');
      return false;
    }
  }

  /// Get top contributors for current challenge
  Future<List<MapEntry<String, int>>> getTopContributors(
    String groupId, {
    int limit = 5,
  }) async {
    final challenge = await getCurrentChallenge(groupId);
    if (challenge == null) return [];

    final entries = challenge.contributors.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).toList();
  }

  DateTime _getWeekEnd() {
    final now = DateTime.now();
    final daysUntilSunday = DateTime.sunday - now.weekday;
    return DateTime(now.year, now.month, now.day + daysUntilSunday, 23, 59, 59);
  }

  /// Create weekly challenge (for Cloud Function or admin)
  Future<bool> createWeeklyChallenge({
    required String groupId,
    int targetValue = 40,
    String theme = 'temple',
  }) async {
    try {
      final weekEnd = _getWeekEnd();
      final weekStart = weekEnd.subtract(const Duration(days: 6));

      await _challengesRef(groupId).doc(currentWeekId).set({
        'theme': theme,
        'targetValue': targetValue,
        'currentValue': 0,
        'weekStart': Timestamp.fromDate(weekStart),
        'weekEnd': Timestamp.fromDate(weekEnd),
        'contributors': {},
        'contributorCount': 0,
        'isCompleted': false,
        'reward': {'dalants': 5, 'badge': 'weekly_winner'},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Create challenge error: $e');
      return false;
    }
  }
}
