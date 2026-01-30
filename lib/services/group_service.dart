import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';

/// 그룹 관리 서비스
/// - 그룹 목록/랭킹 조회
/// - 그룹별 멤버 관리
/// - 그룹 생성/가입
class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 혼동되는 문자 제외

  /// 그룹 목록 조회
  Future<List<GroupModel>> getGroups() async {
    try {
      // 인증 확인
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      final snapshot = await _firestore.collection('groups').get();

      final groups = snapshot.docs
          .map((doc) => GroupModel.fromFirestore(doc.id, doc.data()))
          .toList();

      // 달란트 순 정렬
      groups.sort((a, b) => b.totalTalants.compareTo(a.totalTalants));

      return groups;
    } catch (e) {
      print('❌ 그룹 조회 오류: $e');
      return [];
    }
  }

  /// 그룹 랭킹 실시간 스트림
  Stream<List<GroupModel>> watchGroupRanking() {
    return _firestore.collection('groups').snapshots().map((snapshot) {
      final groups = snapshot.docs
          .map((doc) => GroupModel.fromFirestore(doc.id, doc.data()))
          .toList();
      groups.sort((a, b) => b.totalTalants.compareTo(a.totalTalants));
      return groups;
    });
  }

  /// 그룹별 멤버 목록 실시간 스트림
  Stream<List<MemberInfo>> watchGroupMembers(String groupId, String? currentUserId) {
    return _firestore
        .collection('users')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      final members = snapshot.docs
          .map((doc) => MemberInfo.fromFirestore(doc.id, doc.data(), currentUserId))
          .toList();
      members.sort((a, b) => b.talants.compareTo(a.talants));
      return members;
    });
  }

  /// 그룹 상세 정보 조회
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        return GroupModel.fromFirestore(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ 그룹 조회 오류: $e');
      return null;
    }
  }

  /// 그룹 생성 (관리자용)
  Future<bool> createGroup({
    required String id,
    required String name,
    String? leaderId,
  }) async {
    try {
      await _firestore.collection('groups').doc(id).set({
        'name': name,
        'totalTalants': 0,
        'memberCount': 0,
        'leaderId': leaderId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ 그룹 생성 완료: $name');
      return true;
    } catch (e) {
      print('❌ 그룹 생성 오류: $e');
      return false;
    }
  }

  // ============================================================
  // 그룹 생성/가입 (사용자용)
  // ============================================================

  /// 6자리 초대 코드 생성
  String _generateInviteCode() {
    final random = Random();
    return List.generate(6, (_) => _codeChars[random.nextInt(_codeChars.length)]).join();
  }

  /// 초대 코드 중복 확인
  Future<bool> _isCodeUnique(String code) async {
    final snapshot = await _firestore
        .collection('groups')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }

  /// 유니크한 초대 코드 생성
  Future<String> _generateUniqueCode() async {
    String code;
    int attempts = 0;
    do {
      code = _generateInviteCode();
      attempts++;
    } while (!await _isCodeUnique(code) && attempts < 10);
    return code;
  }

  /// 사용자가 새 그룹 생성
  Future<GroupCreateResult> createGroupByUser({
    required String name,
    String? description,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return GroupCreateResult(success: false, message: '로그인이 필요합니다');
    }

    // 이름 검증
    if (name.trim().isEmpty) {
      return GroupCreateResult(success: false, message: '그룹 이름을 입력해주세요');
    }

    if (name.length > 20) {
      return GroupCreateResult(success: false, message: '그룹 이름은 20자 이내로 입력해주세요');
    }

    try {
      // 유니크한 초대 코드 생성
      final inviteCode = await _generateUniqueCode();

      // 그룹 ID 생성 (영문 소문자 + 숫자)
      final groupId = 'grp_${DateTime.now().millisecondsSinceEpoch}';

      // 그룹 생성
      await _firestore.collection('groups').doc(groupId).set({
        'name': name.trim(),
        'description': description?.trim() ?? '',
        'inviteCode': inviteCode,
        'totalTalants': 0,
        'memberCount': 0,
        'leaderId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': true,
      });

      print('✅ 사용자 그룹 생성 완료: $name (코드: $inviteCode)');
      return GroupCreateResult(
        success: true,
        message: '그룹이 생성되었습니다',
        groupId: groupId,
        inviteCode: inviteCode,
      );
    } catch (e) {
      print('❌ 그룹 생성 오류: $e');
      return GroupCreateResult(success: false, message: '그룹 생성 중 오류가 발생했습니다');
    }
  }

  /// 초대 코드로 그룹 찾기
  Future<GroupModel?> findGroupByCode(String code) async {
    try {
      final normalizedCode = code.trim().toUpperCase();
      if (normalizedCode.length != 6) return null;

      final snapshot = await _firestore
          .collection('groups')
          .where('inviteCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return GroupModel.fromFirestore(doc.id, doc.data());
    } catch (e) {
      print('❌ 코드로 그룹 찾기 오류: $e');
      return null;
    }
  }

  /// 그룹 멤버 수 증가
  Future<void> incrementMemberCount(String groupId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('❌ 멤버 수 증가 오류: $e');
    }
  }

  /// 그룹 검색 (이름으로)
  Future<List<GroupModel>> searchGroups(String query) async {
    try {
      final normalizedQuery = query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) return [];

      // Firestore는 부분 문자열 검색을 지원하지 않으므로
      // 클라이언트 측에서 필터링
      final allGroups = await getGroups();
      return allGroups
          .where((g) => g.name.toLowerCase().contains(normalizedQuery))
          .toList();
    } catch (e) {
      print('❌ 그룹 검색 오류: $e');
      return [];
    }
  }

  /// 공개 그룹만 가져오기
  Future<List<GroupModel>> getPublicGroups() async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .where('isPublic', isEqualTo: true)
          .orderBy('memberCount', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => GroupModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('❌ 공개 그룹 조회 오류: $e');
      // 쿼리 실패 시 기본 getGroups() 사용
      return getGroups();
    }
  }

  /// 현재 사용자가 참여한 그룹 목록 조회
  Future<List<GroupModel>> getMyGroups() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      // 사용자 문서에서 groupId 가져오기
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final groupId = userDoc.data()?['groupId'] as String?;
      if (groupId == null || groupId.isEmpty) return [];

      // 해당 그룹 조회
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return [];

      return [GroupModel.fromFirestore(groupDoc.id, groupDoc.data()!)];
    } catch (e) {
      print('❌ 내 그룹 조회 오류: $e');
      return [];
    }
  }

  /// 그룹 참여하기
  Future<GroupJoinResult> joinGroup(String groupId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return GroupJoinResult(success: false, message: '로그인이 필요합니다');
    }

    try {
      // 그룹 존재 확인
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        return GroupJoinResult(success: false, message: '그룹을 찾을 수 없습니다');
      }

      // 사용자 문서 업데이트
      await _firestore.collection('users').doc(userId).update({
        'groupId': groupId,
      });

      // 그룹 멤버 수 증가
      await incrementMemberCount(groupId);

      return GroupJoinResult(success: true, message: '그룹에 참여했습니다');
    } catch (e) {
      print('❌ 그룹 참여 오류: $e');
      return GroupJoinResult(success: false, message: '그룹 참여 중 오류가 발생했습니다');
    }
  }
}

/// 그룹 참여 결과
class GroupJoinResult {
  final bool success;
  final String message;

  const GroupJoinResult({
    required this.success,
    required this.message,
  });
}

/// 그룹 생성 결과
class GroupCreateResult {
  final bool success;
  final String message;
  final String? groupId;
  final String? inviteCode;

  const GroupCreateResult({
    required this.success,
    required this.message,
    this.groupId,
    this.inviteCode,
  });
}
