import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_stats.dart';

/// 통계 서비스
class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// 사용자 통계 가져오기
  Future<UserStats?> getUserStats() async {
    final odId = currentUserId;
    if (odId == null) return null;

    try {
      // 기본 사용자 정보
      final userDoc = await _firestore.collection('users').doc(odId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;

      // 통계 문서
      final statsDoc = await _firestore
          .collection('users')
          .doc(odId)
          .collection('stats')
          .doc('summary')
          .get();

      final statsData = statsDoc.data() ?? {};

      // 스트릭 정보
      final streakDoc = await _firestore
          .collection('users')
          .doc(odId)
          .collection('stats')
          .doc('quizStreak')
          .get();

      final streakData = streakDoc.data() ?? {};

      // 활동 데이터
      final activityDoc = await _firestore
          .collection('users')
          .doc(odId)
          .collection('stats')
          .doc('activity')
          .get();

      final activityData = activityDoc.data() ?? {};

      return UserStats(
        userId: odId,
        totalVersesLearned: statsData['totalVersesLearned'] ?? 0,
        totalVersesMastered: statsData['totalVersesMastered'] ?? 0,
        totalStudyMinutes: statsData['totalStudyMinutes'] ?? 0,
        totalQuizzesTaken: streakData['totalQuizzesTaken'] ?? 0,
        perfectQuizCount: streakData['perfectScores'] ?? 0,
        currentStreak: streakData['currentStreak'] ?? 0,
        longestStreak: streakData['longestStreak'] ?? 0,
        totalTalants: userData['totalTalants'] ?? 0,
        totalReactionsReceived: statsData['totalReactionsReceived'] ?? 0,
        totalNudgesSent: statsData['totalNudgesSent'] ?? 0,
        totalNudgesReceived: statsData['totalNudgesReceived'] ?? 0,
        lastActiveDate: (streakData['lastQuizDate'] as Timestamp?)?.toDate(),
        dailyActivity:
            Map<String, int>.from(activityData['daily'] ?? {}),
        weeklyActivity:
            Map<String, int>.from(activityData['weekly'] ?? {}),
        monthlyActivity:
            Map<String, int>.from(activityData['monthly'] ?? {}),
      );
    } catch (e) {
      print('Get user stats error: $e');
      return null;
    }
  }

  /// 학습 시간 기록
  Future<void> recordStudyTime(int minutes) async {
    final odId = currentUserId;
    if (odId == null) return;

    try {
      final now = DateTime.now();
      final dayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final weekNumber = _getWeekNumber(now);
      final weekKey = '${now.year}-$weekNumber';
      final monthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      await _firestore.runTransaction((transaction) async {
        // 요약 통계 업데이트
        final summaryRef = _firestore
            .collection('users')
            .doc(odId)
            .collection('stats')
            .doc('summary');

        transaction.set(
          summaryRef,
          {'totalStudyMinutes': FieldValue.increment(minutes)},
          SetOptions(merge: true),
        );

        // 활동 데이터 업데이트
        final activityRef = _firestore
            .collection('users')
            .doc(odId)
            .collection('stats')
            .doc('activity');

        transaction.set(
          activityRef,
          {
            'daily.$dayKey': FieldValue.increment(minutes),
            'weekly.$weekKey': FieldValue.increment(minutes),
            'monthly.$monthKey': FieldValue.increment(minutes),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      print('Record study time error: $e');
    }
  }

  /// 구절 학습 완료 기록
  Future<void> recordVerseLearn({bool isMastered = false}) async {
    final odId = currentUserId;
    if (odId == null) return;

    try {
      final summaryRef = _firestore
          .collection('users')
          .doc(odId)
          .collection('stats')
          .doc('summary');

      final updates = <String, dynamic>{
        'totalVersesLearned': FieldValue.increment(1),
      };

      if (isMastered) {
        updates['totalVersesMastered'] = FieldValue.increment(1);
      }

      await summaryRef.set(updates, SetOptions(merge: true));
    } catch (e) {
      print('Record verse learn error: $e');
    }
  }

  /// 반응 수신 기록
  Future<void> recordReactionReceived() async {
    final odId = currentUserId;
    if (odId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(odId)
          .collection('stats')
          .doc('summary')
          .set(
            {'totalReactionsReceived': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
    } catch (e) {
      print('Record reaction received error: $e');
    }
  }

  /// 넛지 발송 기록
  Future<void> recordNudgeSent() async {
    final odId = currentUserId;
    if (odId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(odId)
          .collection('stats')
          .doc('summary')
          .set(
            {'totalNudgesSent': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
    } catch (e) {
      print('Record nudge sent error: $e');
    }
  }

  /// 넛지 수신 기록
  Future<void> recordNudgeReceived() async {
    final odId = currentUserId;
    if (odId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(odId)
          .collection('stats')
          .doc('summary')
          .set(
            {'totalNudgesReceived': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
    } catch (e) {
      print('Record nudge received error: $e');
    }
  }

  /// 학습 진도 가져오기
  Future<List<StudyProgress>> getStudyProgress() async {
    final odId = currentUserId;
    if (odId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(odId)
          .collection('progress')
          .get();

      final progressMap = <String, StudyProgress>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final book = data['book'] ?? 'Unknown';
        final isLearned = data['isLearned'] ?? false;
        final isMastered = data['isMastered'] ?? false;

        if (!progressMap.containsKey(book)) {
          progressMap[book] = StudyProgress(
            bookName: book,
            totalVerses: 0,
            learnedVerses: 0,
            masteredVerses: 0,
          );
        }

        final current = progressMap[book]!;
        progressMap[book] = StudyProgress(
          bookName: book,
          totalVerses: current.totalVerses + 1,
          learnedVerses: current.learnedVerses + (isLearned ? 1 : 0),
          masteredVerses: current.masteredVerses + (isMastered ? 1 : 0),
        );
      }

      return progressMap.values.toList()
        ..sort((a, b) => b.learnedRate.compareTo(a.learnedRate));
    } catch (e) {
      print('Get study progress error: $e');
      return [];
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) ~/ 7) + 1;
  }
}
