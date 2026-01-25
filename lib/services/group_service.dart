import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';

/// 그룹 관리 서비스
/// - 그룹 목록/랭킹 조회
/// - 그룹별 멤버 관리
class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
}
