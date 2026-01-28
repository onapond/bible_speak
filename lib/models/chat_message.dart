import 'package:cloud_firestore/cloud_firestore.dart';

/// 채팅 메시지 타입
enum ChatMessageType {
  text,
  verse,
  achievement,
  system,
}

/// 채팅 메시지 모델
class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderEmoji;
  final ChatMessageType type;
  final String content;
  final String? verseReference;
  final DateTime createdAt;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderEmoji,
    required this.type,
    required this.content,
    this.verseReference,
    required this.createdAt,
    this.isDeleted = false,
  });

  factory ChatMessage.fromFirestore(String docId, Map<String, dynamic> data) {
    return ChatMessage(
      id: docId,
      groupId: data['groupId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderEmoji: data['senderEmoji'],
      type: ChatMessageType.values[data['type'] ?? 0],
      content: data['content'] ?? '',
      verseReference: data['verseReference'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'senderId': senderId,
        'senderName': senderName,
        'senderEmoji': senderEmoji,
        'type': type.index,
        'content': content,
        'verseReference': verseReference,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': isDeleted,
      };

  /// 시스템 메시지 여부
  bool get isSystemMessage => type == ChatMessageType.system;

  /// 구절 공유 메시지 여부
  bool get isVerseMessage => type == ChatMessageType.verse;

  /// 시간 포맷팅
  String get formattedTime {
    final hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final amPm = hour < 12 ? '오전' : '오후';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$amPm $displayHour:$minute';
  }

  /// 날짜 포맷팅
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (messageDate == today) {
      return '오늘';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return '어제';
    } else {
      return '${createdAt.month}월 ${createdAt.day}일';
    }
  }
}

/// 채팅방 정보
class ChatRoom {
  final String id;
  final String groupId;
  final String? lastMessage;
  final String? lastSenderName;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChatRoom({
    required this.id,
    required this.groupId,
    this.lastMessage,
    this.lastSenderName,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromFirestore(String docId, Map<String, dynamic> data) {
    return ChatRoom(
      id: docId,
      groupId: data['groupId'] ?? '',
      lastMessage: data['lastMessage'],
      lastSenderName: data['lastSenderName'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: data['unreadCount'] ?? 0,
    );
  }
}
