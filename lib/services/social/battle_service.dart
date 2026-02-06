import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/friend.dart';

/// 1:1 대전 서비스
class BattleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 대전 생성/관리
  // ============================================================

  /// 대전 신청
  Future<BattleCreateResult> createBattle({
    required String opponentId,
    required String verseReference,
    int betAmount = 10,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      return const BattleCreateResult(success: false, message: '로그인이 필요합니다');
    }

    try {
      // 사용자 정보 가져오기
      final challengerDoc = await _firestore.collection('users').doc(userId).get();
      final opponentDoc = await _firestore.collection('users').doc(opponentId).get();

      if (!opponentDoc.exists) {
        return const BattleCreateResult(success: false, message: '상대를 찾을 수 없습니다');
      }

      final challengerTalants = challengerDoc.data()?['talants'] ?? 0;
      if (challengerTalants < betAmount) {
        return BattleCreateResult(
          success: false,
          message: '탈란트가 부족합니다 (필요: $betAmount, 보유: $challengerTalants)',
        );
      }

      final challengerName = challengerDoc.data()?['name'] ?? '익명';
      final opponentName = opponentDoc.data()?['name'] ?? '익명';

      // 대전 생성
      final battleRef = await _firestore.collection('battles').add({
        'challengerId': userId,
        'challengerName': challengerName,
        'opponentId': opponentId,
        'opponentName': opponentName,
        'verseReference': verseReference,
        'status': 'pending',
        'betAmount': betAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
      });

      return BattleCreateResult(
        success: true,
        message: '대전 신청을 보냈습니다',
        battleId: battleRef.id,
      );
    } catch (e) {
      print('Create battle error: $e');
      return const BattleCreateResult(success: false, message: '대전 생성 중 오류가 발생했습니다');
    }
  }

  /// 대전 수락
  Future<bool> acceptBattle(String battleId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final battleDoc = await _firestore.collection('battles').doc(battleId).get();
      if (!battleDoc.exists) return false;

      final battle = Battle.fromFirestore(battleId, battleDoc.data()!);
      if (battle.opponentId != userId) return false;
      if (battle.status != BattleStatus.pending) return false;

      // 베팅 금액 확인
      final opponentDoc = await _firestore.collection('users').doc(userId).get();
      final opponentTalants = opponentDoc.data()?['talants'] ?? 0;

      if (opponentTalants < battle.betAmount) {
        return false; // 탈란트 부족
      }

      // set + merge로 안전하게 업데이트
      await battleDoc.reference.set({
        'status': 'active',
        'acceptedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Accept battle error: $e');
      return false;
    }
  }

  /// 대전 거절
  Future<bool> declineBattle(String battleId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final battleDoc = await _firestore.collection('battles').doc(battleId).get();
      if (!battleDoc.exists) return false;

      final battle = Battle.fromFirestore(battleId, battleDoc.data()!);
      if (battle.opponentId != userId) return false;
      if (battle.status != BattleStatus.pending) return false;

      // set + merge로 안전하게 업데이트
      await battleDoc.reference.set({'status': 'declined'}, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Decline battle error: $e');
      return false;
    }
  }

  /// 점수 제출
  Future<bool> submitScore(String battleId, int score) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final battleDoc = await _firestore.collection('battles').doc(battleId).get();
      if (!battleDoc.exists) return false;

      final battle = Battle.fromFirestore(battleId, battleDoc.data()!);
      if (battle.status != BattleStatus.active) return false;

      final isChallenger = battle.isChallenger(userId);
      final isOpponent = battle.isOpponent(userId);

      if (!isChallenger && !isOpponent) return false;

      final scoreField = isChallenger ? 'challengerScore' : 'opponentScore';

      // 이미 점수를 제출했는지 확인
      if (isChallenger && battle.challengerScore != null) return false;
      if (isOpponent && battle.opponentScore != null) return false;

      // set + merge로 안전하게 업데이트
      await battleDoc.reference.set({scoreField: score}, SetOptions(merge: true));

      // 양쪽 점수가 모두 있으면 완료 처리
      final updatedDoc = await battleDoc.reference.get();
      final updatedBattle = Battle.fromFirestore(battleId, updatedDoc.data()!);

      if (updatedBattle.challengerScore != null &&
          updatedBattle.opponentScore != null) {
        await _completeBattle(battleId, updatedBattle);
      }

      return true;
    } catch (e) {
      print('Submit score error: $e');
      return false;
    }
  }

  /// 대전 완료 처리 (보상 지급)
  Future<void> _completeBattle(String battleId, Battle battle) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final battleRef = _firestore.collection('battles').doc(battleId);

        // 대전 완료 처리 (set + merge로 필드 없어도 안전)
        transaction.set(battleRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final winnerId = battle.winnerId;
        final totalReward = battle.betAmount * 2;

        if (winnerId != null) {
          // 승자에게 보상 지급 (set + merge로 필드 없어도 안전)
          final winnerRef = _firestore.collection('users').doc(winnerId);
          transaction.set(winnerRef, {
            'talants': FieldValue.increment(totalReward),
            'totalTalants': FieldValue.increment(totalReward),
            'battleWins': FieldValue.increment(1),
          }, SetOptions(merge: true));

          // 패자에서 베팅금 차감 (set + merge로 필드 없어도 안전)
          final loserId = winnerId == battle.challengerId
              ? battle.opponentId
              : battle.challengerId;
          final loserRef = _firestore.collection('users').doc(loserId);
          transaction.set(loserRef, {
            'talants': FieldValue.increment(-battle.betAmount),
            'battleLosses': FieldValue.increment(1),
          }, SetOptions(merge: true));
        } else {
          // 무승부 - 베팅금 반환 (변화 없음, set + merge 사용)
          final challengerRef = _firestore.collection('users').doc(battle.challengerId);
          final opponentRef = _firestore.collection('users').doc(battle.opponentId);
          transaction.set(challengerRef, {'battleDraws': FieldValue.increment(1)}, SetOptions(merge: true));
          transaction.set(opponentRef, {'battleDraws': FieldValue.increment(1)}, SetOptions(merge: true));
        }
      });
    } catch (e) {
      print('Complete battle error: $e');
    }
  }

  // ============================================================
  // 대전 조회
  // ============================================================

  /// 받은 대전 신청 목록 (대기중)
  Stream<List<Battle>> watchPendingBattles() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('battles')
        .where('opponentId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Battle.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// 진행 중인 대전 목록
  Stream<List<Battle>> watchActiveBattles() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('battles')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Battle.fromFirestore(doc.id, doc.data()))
            .where((b) => b.challengerId == userId || b.opponentId == userId)
            .toList());
  }

  /// 대전 기록 (완료된 대전)
  Future<List<Battle>> getBattleHistory({int limit = 20}) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      // 도전자로서의 대전
      final asChallenger = await _firestore
          .collection('battles')
          .where('challengerId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();

      // 상대로서의 대전
      final asOpponent = await _firestore
          .collection('battles')
          .where('opponentId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();

      final battles = [
        ...asChallenger.docs.map((d) => Battle.fromFirestore(d.id, d.data())),
        ...asOpponent.docs.map((d) => Battle.fromFirestore(d.id, d.data())),
      ];

      // 시간순 정렬
      battles.sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt));

      return battles.take(limit).toList();
    } catch (e) {
      print('Get battle history error: $e');
      return [];
    }
  }

  /// 대전 통계
  Future<BattleStats> getStats() async {
    final userId = currentUserId;
    if (userId == null) return const BattleStats();

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data() ?? {};

      return BattleStats(
        wins: data['battleWins'] ?? 0,
        losses: data['battleLosses'] ?? 0,
        draws: data['battleDraws'] ?? 0,
      );
    } catch (e) {
      print('Get battle stats error: $e');
      return const BattleStats();
    }
  }
}

/// 대전 생성 결과
class BattleCreateResult {
  final bool success;
  final String message;
  final String? battleId;

  const BattleCreateResult({
    required this.success,
    required this.message,
    this.battleId,
  });
}

/// 대전 통계
class BattleStats {
  final int wins;
  final int losses;
  final int draws;

  const BattleStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  int get total => wins + losses + draws;

  double get winRate => total > 0 ? wins / total : 0;

  int get winRatePercent => (winRate * 100).round();
}
