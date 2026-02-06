import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/friend.dart';

/// 친구 관리 서비스
class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 친구 요청
  // ============================================================

  /// 친구 요청 보내기
  Future<FriendRequestResult> sendFriendRequest(String toUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      return const FriendRequestResult(success: false, message: '로그인이 필요합니다');
    }

    if (userId == toUserId) {
      return const FriendRequestResult(success: false, message: '자신에게 요청할 수 없습니다');
    }

    try {
      // 이미 친구인지 확인
      final existingFriend = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(toUserId)
          .get();

      if (existingFriend.exists) {
        return const FriendRequestResult(success: false, message: '이미 친구입니다');
      }

      // 이미 요청을 보냈는지 확인
      final existingRequest = await _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: userId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        return const FriendRequestResult(success: false, message: '이미 요청을 보냈습니다');
      }

      // 상대방이 나에게 요청을 보냈는지 확인 (자동 수락)
      final reverseRequest = await _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: toUserId)
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (reverseRequest.docs.isNotEmpty) {
        // 상대방 요청 수락
        await acceptFriendRequest(reverseRequest.docs.first.id);
        return const FriendRequestResult(success: true, message: '친구가 되었습니다!');
      }

      // 사용자 이름 가져오기
      final fromUser = await _firestore.collection('users').doc(userId).get();
      final toUser = await _firestore.collection('users').doc(toUserId).get();

      if (!toUser.exists) {
        return const FriendRequestResult(success: false, message: '사용자를 찾을 수 없습니다');
      }

      final fromUserName = fromUser.data()?['name'] ?? '익명';
      final toUserName = toUser.data()?['name'] ?? '익명';

      // 친구 요청 생성
      await _firestore.collection('friendRequests').add({
        'fromUserId': userId,
        'fromUserName': fromUserName,
        'toUserId': toUserId,
        'toUserName': toUserName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return const FriendRequestResult(success: true, message: '친구 요청을 보냈습니다');
    } catch (e) {
      print('Send friend request error: $e');
      return const FriendRequestResult(success: false, message: '요청 중 오류가 발생했습니다');
    }
  }

  /// 친구 요청 수락
  Future<bool> acceptFriendRequest(String requestId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final requestDoc = await _firestore
          .collection('friendRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) return false;

      final request = FriendRequest.fromFirestore(requestId, requestDoc.data()!);

      if (request.toUserId != userId) return false;
      if (request.status != FriendRequestStatus.pending) return false;

      // 트랜잭션으로 처리
      await _firestore.runTransaction((transaction) async {
        // 요청 상태 업데이트 (set + merge로 안전)
        transaction.set(requestDoc.reference, {'status': 'accepted'}, SetOptions(merge: true));

        // 양쪽에 친구 추가
        final fromUserRef = _firestore
            .collection('users')
            .doc(request.fromUserId)
            .collection('friends')
            .doc(request.toUserId);

        final toUserRef = _firestore
            .collection('users')
            .doc(request.toUserId)
            .collection('friends')
            .doc(request.fromUserId);

        // 상대방 정보 가져오기
        final fromUserDoc = await transaction.get(
            _firestore.collection('users').doc(request.fromUserId));
        final toUserDoc = await transaction.get(
            _firestore.collection('users').doc(request.toUserId));

        final fromUserData = fromUserDoc.data() ?? {};
        final toUserData = toUserDoc.data() ?? {};

        // 친구 추가
        transaction.set(fromUserRef, {
          'odId': request.toUserId,
          'name': toUserData['name'] ?? '',
          'groupId': toUserData['groupId'],
          'groupName': toUserData['groupName'],
          'talants': toUserData['talants'] ?? 0,
          'streak': toUserData['streak'] ?? 0,
          'addedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(toUserRef, {
          'odId': request.fromUserId,
          'name': fromUserData['name'] ?? '',
          'groupId': fromUserData['groupId'],
          'groupName': fromUserData['groupName'],
          'talants': fromUserData['talants'] ?? 0,
          'streak': fromUserData['streak'] ?? 0,
          'addedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      print('Accept friend request error: $e');
      return false;
    }
  }

  /// 친구 요청 거절
  Future<bool> rejectFriendRequest(String requestId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final requestDoc = await _firestore
          .collection('friendRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) return false;

      final request = FriendRequest.fromFirestore(requestId, requestDoc.data()!);

      if (request.toUserId != userId) return false;

      // set + merge로 안전하게 업데이트
      await requestDoc.reference.set({'status': 'rejected'}, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Reject friend request error: $e');
      return false;
    }
  }

  /// 받은 친구 요청 목록
  Stream<List<FriendRequest>> watchPendingRequests() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('friendRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // ============================================================
  // 친구 목록
  // ============================================================

  /// 친구 목록 가져오기
  Future<List<Friend>> getFriends() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Friend.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Get friends error: $e');
      return [];
    }
  }

  /// 친구 목록 실시간 스트림
  Stream<List<Friend>> watchFriends() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Friend.fromFirestore(doc.data()))
            .toList());
  }

  /// 친구 삭제
  Future<bool> removeFriend(String friendId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      // 양쪽에서 삭제
      final batch = _firestore.batch();

      batch.delete(_firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendId));

      batch.delete(_firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(userId));

      await batch.commit();
      return true;
    } catch (e) {
      print('Remove friend error: $e');
      return false;
    }
  }

  // ============================================================
  // 사용자 검색
  // ============================================================

  /// 사용자 검색 (이름으로)
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final userId = currentUserId;
    if (userId == null) return [];
    if (query.trim().length < 2) return [];

    try {
      // Firestore는 부분 문자열 검색을 지원하지 않으므로
      // 시작 문자로 검색
      final normalizedQuery = query.trim();

      final snapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: normalizedQuery)
          .where('name', isLessThan: '${normalizedQuery}z')
          .limit(20)
          .get();

      // 친구 목록 가져오기
      final friends = await getFriends();
      final friendIds = friends.map((f) => f.odId).toSet();

      return snapshot.docs
          .where((doc) => doc.id != userId) // 자신 제외
          .map((doc) {
            final data = doc.data();
            return UserSearchResult(
              odId: doc.id,
              name: data['name'] ?? '',
              groupName: data['groupName'],
              talants: data['talants'] ?? 0,
              isFriend: friendIds.contains(doc.id),
            );
          })
          .toList();
    } catch (e) {
      print('Search users error: $e');
      return [];
    }
  }
}

/// 친구 요청 결과
class FriendRequestResult {
  final bool success;
  final String message;

  const FriendRequestResult({
    required this.success,
    required this.message,
  });
}

/// 사용자 검색 결과
class UserSearchResult {
  final String odId;
  final String name;
  final String? groupName;
  final int talants;
  final bool isFriend;

  const UserSearchResult({
    required this.odId,
    required this.name,
    this.groupName,
    this.talants = 0,
    this.isFriend = false,
  });
}
