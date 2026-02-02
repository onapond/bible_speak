import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_streak.dart';

/// 스트릭 관리 서비스
class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// 현재 날짜 문자열 (YYYY-MM-DD)
  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 어제 날짜 문자열
  String get _yesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  /// 사용자 문서 참조
  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  /// 스트릭 데이터 가져오기
  Future<UserStreak> getStreak() async {
    final uid = currentUserId;
    if (uid == null) return const UserStreak();

    try {
      final doc = await _userRef(uid).get();
      final streakData = doc.data()?['streak'] as Map<String, dynamic>?;
      return UserStreak.fromMap(streakData);
    } catch (e) {
      print('Get streak error: $e');
      return const UserStreak();
    }
  }

  /// 스트릭 실시간 스트림
  Stream<UserStreak> watchStreak() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const UserStreak());

    return _userRef(uid).snapshots().map((doc) {
      final streakData = doc.data()?['streak'] as Map<String, dynamic>?;
      return UserStreak.fromMap(streakData);
    });
  }

  /// 학습 완료 기록 (스트릭 업데이트)
  /// 반환값: 달성한 마일스톤 (없으면 null)
  Future<StreakMilestone?> recordLearning() async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final currentStreak = await getStreak();

      // 이미 오늘 학습했으면 스킵
      if (currentStreak.lastLearnedDate == _today) {
        return null;
      }

      int newStreak;
      String? newStreakStartDate;
      StreakMilestone? achievedMilestone;

      // 스트릭 계산
      if (currentStreak.lastLearnedDate == _yesterday) {
        // 연속 유지
        newStreak = currentStreak.currentStreak + 1;
        newStreakStartDate = currentStreak.streakStartDate;
      } else if (currentStreak.lastLearnedDate == null) {
        // 첫 학습
        newStreak = 1;
        newStreakStartDate = _today;
      } else {
        // 스트릭 끊김 - 리셋
        newStreak = 1;
        newStreakStartDate = _today;
      }

      // 마일스톤 달성 확인
      achievedMilestone = StreakMilestone.getForDays(newStreak);

      // 주간 히스토리 업데이트
      final weeklyHistory = _updateWeeklyHistory(currentStreak.weeklyHistory);

      // 마일스톤 맵 업데이트
      final milestones = Map<String, String>.from(currentStreak.milestones);
      if (achievedMilestone != null && !milestones.containsKey(newStreak.toString())) {
        milestones[newStreak.toString()] = _today;
      }

      // Firestore 업데이트
      await _userRef(uid).set({
        'streak': {
          'currentStreak': newStreak,
          'longestStreak': newStreak > currentStreak.longestStreak
              ? newStreak
              : currentStreak.longestStreak,
          'lastLearnedDate': _today,
          'streakStartDate': newStreakStartDate,
          'protectionUsedThisMonth': currentStreak.protectionUsedThisMonth,
          'protectedDates': currentStreak.protectedDates,
          'weeklyHistory': weeklyHistory,
          'milestones': milestones,
          'totalDaysLearned': currentStreak.totalDaysLearned + 1,
        }
      }, SetOptions(merge: true));

      return achievedMilestone;
    } catch (e) {
      print('Record learning error: $e');
      return null;
    }
  }

  /// 스트릭 보호권 사용
  Future<bool> useProtection() async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      final currentStreak = await getStreak();

      // 사용 조건 확인
      if (!currentStreak.canUseProtection) {
        return false;
      }

      // 오늘 이미 학습했으면 필요 없음
      if (currentStreak.lastLearnedDate == _today) {
        return false;
      }

      final protectedDates = List<String>.from(currentStreak.protectedDates);
      protectedDates.add(_today);

      await _userRef(uid).set({
        'streak': {
          'lastLearnedDate': _today,
          'protectionUsedThisMonth': currentStreak.protectionUsedThisMonth + 1,
          'protectedDates': protectedDates,
        }
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Use protection error: $e');
      return false;
    }
  }

  /// 스트릭 리셋 확인 (앱 시작 시 호출)
  Future<bool> checkAndResetStreak() async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      final currentStreak = await getStreak();

      // 스트릭이 없으면 스킵
      if (currentStreak.currentStreak == 0) return false;

      // 오늘 또는 어제 학습했으면 유지
      if (currentStreak.lastLearnedDate == _today ||
          currentStreak.lastLearnedDate == _yesterday) {
        return false;
      }

      // 2일 이상 지남 - 스트릭 리셋
      await _userRef(uid).set({
        'streak': {
          'currentStreak': 0,
          'streakStartDate': null,
          // 다른 필드는 유지
        }
      }, SetOptions(merge: true));

      return true; // 리셋됨
    } catch (e) {
      print('Check streak error: $e');
      return false;
    }
  }

  /// 월간 보호권 사용 횟수 리셋 (매월 1일)
  Future<void> resetMonthlyProtection() async {
    final uid = currentUserId;
    if (uid == null) return;

    final now = DateTime.now();
    if (now.day == 1) {
      try {
        await _userRef(uid).set({
          'streak': {
            'protectionUsedThisMonth': 0,
          }
        }, SetOptions(merge: true));
      } catch (e) {
        print('Reset monthly protection error: $e');
      }
    }
  }

  /// 주간 히스토리 업데이트
  List<bool> _updateWeeklyHistory(List<bool> current) {
    final now = DateTime.now();
    final dayIndex = (now.weekday - 1) % 7; // 월=0, 일=6

    final history = List<bool>.from(current);
    if (history.length < 7) {
      history.addAll(List.filled(7 - history.length, false));
    }
    history[dayIndex] = true;
    return history;
  }
}
