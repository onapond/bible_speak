import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

/// 채팅 서비스
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// 메시지 스트림 (실시간)
  Stream<List<ChatMessage>> getMessagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// 메시지 전송
  Future<ChatMessage?> sendMessage({
    required String groupId,
    required String content,
    required String senderName,
    String? senderEmoji,
    ChatMessageType type = ChatMessageType.text,
    String? verseReference,
  }) async {
    final odId = currentUserId;
    if (odId == null) return null;

    try {
      final messageRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc();

      final message = ChatMessage(
        id: messageRef.id,
        groupId: groupId,
        senderId: odId,
        senderName: senderName,
        senderEmoji: senderEmoji,
        type: type,
        content: content,
        verseReference: verseReference,
        createdAt: DateTime.now(),
      );

      await _firestore.runTransaction((transaction) async {
        // 메시지 저장
        transaction.set(messageRef, message.toFirestore());

        // 채팅방 마지막 메시지 업데이트
        final roomRef = _firestore.collection('groups').doc(groupId);
        transaction.update(roomRef, {
          'lastMessage': content,
          'lastSenderName': senderName,
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      });

      return message;
    } catch (e) {
      print('Send message error: $e');
      return null;
    }
  }

  /// 시스템 메시지 전송
  Future<void> sendSystemMessage(String groupId, String content) async {
    try {
      final messageRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'groupId': groupId,
        'senderId': 'system',
        'senderName': '시스템',
        'type': ChatMessageType.system.index,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      });
    } catch (e) {
      print('Send system message error: $e');
    }
  }

  /// 구절 공유
  Future<ChatMessage?> shareVerse({
    required String groupId,
    required String verseReference,
    required String verseText,
    required String senderName,
    String? senderEmoji,
  }) async {
    return sendMessage(
      groupId: groupId,
      content: verseText,
      senderName: senderName,
      senderEmoji: senderEmoji,
      type: ChatMessageType.verse,
      verseReference: verseReference,
    );
  }

  /// 메시지 삭제 (소프트 삭제)
  Future<bool> deleteMessage(String groupId, String messageId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .update({'isDeleted': true});
      return true;
    } catch (e) {
      print('Delete message error: $e');
      return false;
    }
  }

  /// 채팅 읽음 처리
  Future<void> markAsRead(String groupId) async {
    final odId = currentUserId;
    if (odId == null) return;

    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(odId)
          .update({
        'lastReadAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Mark as read error: $e');
    }
  }
}
