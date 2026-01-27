import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/nudge.dart';

/// 찌르기(Nudge) 서비스
class NudgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// 오늘 날짜 문자열 (YYYY-MM-DD)
  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 찌르기 보내기
  Future<bool> sendNudge({
    required String toUserId,
    required String toUserName,
    required String message,
    String? templateId,
    required String groupId,
    required String fromUserName,
  }) async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      // 일일 통계 확인
      final stats = await getDailyStats();
      if (!stats.canNudgeUser(toUserId)) {
        return false;
      }

      // 찌르기 문서 생성
      final nudgeRef = _firestore.collection('users').doc(toUserId).collection('nudges').doc();
      final nudge = Nudge(
        id: nudgeRef.id,
        fromUserId: uid,
        fromUserName: fromUserName,
        toUserId: toUserId,
        toUserName: toUserName,
        message: message,
        templateId: templateId,
        groupId: groupId,
        createdAt: DateTime.now(),
      );

      // 트랜잭션으로 찌르기 + 통계 업데이트
      await _firestore.runTransaction((transaction) async {
        // 찌르기 저장
        transaction.set(nudgeRef, nudge.toMap());

        // 발신자 일일 통계 업데이트
        final statsRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('dailyStats')
            .doc(_today);

        transaction.set(statsRef, {
          'nudgesSent': FieldValue.increment(1),
          'nudgesTo.$toUserId': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      return true;
    } catch (e) {
      print('Send nudge error: $e');
      return false;
    }
  }

  /// 일일 통계 가져오기
  Future<NudgeDailyStats> getDailyStats({bool isLeader = false}) async {
    final uid = currentUserId;
    if (uid == null) {
      return NudgeDailyStats(nudgesSent: 0, nudgesTo: {}, dailyLimit: 3);
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('dailyStats')
          .doc(_today)
          .get();

      return NudgeDailyStats.fromMap(doc.data(), isLeader: isLeader);
    } catch (e) {
      return NudgeDailyStats(nudgesSent: 0, nudgesTo: {}, dailyLimit: isLeader ? 10 : 3);
    }
  }

  /// 받은 찌르기 목록 (읽지 않은 것)
  Future<List<Nudge>> getUnreadNudges() async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('nudges')
          .where('readAt', isNull: true)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => Nudge.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Get unread nudges error: $e');
      return [];
    }
  }

  /// 찌르기 읽음 처리
  Future<void> markAsRead(String nudgeId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('nudges')
          .doc(nudgeId)
          .update({'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Mark nudge as read error: $e');
    }
  }

  /// 찌르기 응답 처리 (앱 접속)
  Future<void> markAsResponded(String nudgeId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('nudges')
          .doc(nudgeId)
          .update({'respondedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Mark nudge as responded error: $e');
    }
  }

  /// 비활성 멤버 목록 가져오기
  Future<List<InactiveMember>> getInactiveMembers(String groupId) async {
    try {
      // 그룹 멤버 목록 가져오기
      final membersSnapshot = await _firestore
          .collection('users')
          .where('groupId', isEqualTo: groupId)
          .get();

      final today = DateTime.now();
      final inactiveMembers = <InactiveMember>[];

      for (final doc in membersSnapshot.docs) {
        final data = doc.data();
        final streakData = data['streak'] as Map<String, dynamic>?;
        final lastLearnedDate = streakData?['lastLearnedDate'] as String?;

        if (lastLearnedDate == null) {
          // 한 번도 학습 안 함
          inactiveMembers.add(InactiveMember(
            odId: doc.id,
            name: data['name'] ?? '멤버',
            daysSinceActive: 999,
            lastActiveDate: null,
          ));
        } else {
          // 마지막 학습일 계산
          final parts = lastLearnedDate.split('-');
          if (parts.length == 3) {
            final lastDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            final daysSince = today.difference(lastDate).inDays;

            if (daysSince >= 3) {
              inactiveMembers.add(InactiveMember(
                odId: doc.id,
                name: data['name'] ?? '멤버',
                daysSinceActive: daysSince,
                lastActiveDate: lastLearnedDate,
              ));
            }
          }
        }
      }

      // 미접속 일수 기준 정렬 (오래된 순)
      inactiveMembers.sort((a, b) => b.daysSinceActive.compareTo(a.daysSinceActive));

      return inactiveMembers;
    } catch (e) {
      print('Get inactive members error: $e');
      return [];
    }
  }

  /// 읽지 않은 찌르기 개수 스트림
  Stream<int> watchUnreadNudgeCount() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('nudges')
        .where('readAt', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
