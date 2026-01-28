import 'package:cloud_firestore/cloud_firestore.dart';

/// 친구 요청 상태
enum FriendRequestStatus {
  pending('대기중'),
  accepted('수락됨'),
  rejected('거절됨');

  final String label;
  const FriendRequestStatus(this.label);
}

/// 친구 요청 모델
class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromFirestore(String id, Map<String, dynamic> data) {
    return FriendRequest(
      id: id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserName: data['toUserName'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// 친구 정보
class Friend {
  final String odId;
  final String name;
  final String? groupId;
  final String? groupName;
  final int talants;
  final int streak;
  final DateTime? lastActive;
  final DateTime addedAt;

  const Friend({
    required this.odId,
    required this.name,
    this.groupId,
    this.groupName,
    this.talants = 0,
    this.streak = 0,
    this.lastActive,
    required this.addedAt,
  });

  factory Friend.fromFirestore(Map<String, dynamic> data) {
    return Friend(
      odId: data['odId'] ?? '',
      name: data['name'] ?? '',
      groupId: data['groupId'],
      groupName: data['groupName'],
      talants: data['talants'] ?? 0,
      streak: data['streak'] ?? 0,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'odId': odId,
      'name': name,
      'groupId': groupId,
      'groupName': groupName,
      'talants': talants,
      'streak': streak,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  /// 온라인 여부 (30분 이내 활동)
  bool get isOnline {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive!).inMinutes < 30;
  }
}

/// 1:1 대전 상태
enum BattleStatus {
  pending('대기중'),
  active('진행중'),
  completed('완료'),
  declined('거절됨'),
  expired('만료됨');

  final String label;
  const BattleStatus(this.label);
}

/// 1:1 대전 모델
class Battle {
  final String id;
  final String challengerId;
  final String challengerName;
  final String opponentId;
  final String opponentName;
  final String verseReference; // e.g., "John 3:16"
  final BattleStatus status;
  final int? challengerScore;
  final int? opponentScore;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int betAmount; // 베팅 탈란트

  const Battle({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.opponentId,
    required this.opponentName,
    required this.verseReference,
    required this.status,
    this.challengerScore,
    this.opponentScore,
    required this.createdAt,
    this.completedAt,
    this.betAmount = 10,
  });

  factory Battle.fromFirestore(String id, Map<String, dynamic> data) {
    return Battle(
      id: id,
      challengerId: data['challengerId'] ?? '',
      challengerName: data['challengerName'] ?? '',
      opponentId: data['opponentId'] ?? '',
      opponentName: data['opponentName'] ?? '',
      verseReference: data['verseReference'] ?? '',
      status: BattleStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => BattleStatus.pending,
      ),
      challengerScore: data['challengerScore'],
      opponentScore: data['opponentScore'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      betAmount: data['betAmount'] ?? 10,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'challengerId': challengerId,
      'challengerName': challengerName,
      'opponentId': opponentId,
      'opponentName': opponentName,
      'verseReference': verseReference,
      'status': status.name,
      'challengerScore': challengerScore,
      'opponentScore': opponentScore,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'betAmount': betAmount,
    };
  }

  /// 사용자가 도전자인지 확인
  bool isChallenger(String odId) => challengerId == odId;

  /// 사용자가 상대인지 확인
  bool isOpponent(String odId) => opponentId == odId;

  /// 승자 ID
  String? get winnerId {
    if (status != BattleStatus.completed) return null;
    if (challengerScore == null || opponentScore == null) return null;
    if (challengerScore! > opponentScore!) return challengerId;
    if (opponentScore! > challengerScore!) return opponentId;
    return null; // 무승부
  }

  /// 사용자가 승자인지 확인
  bool isWinner(String odId) => winnerId == odId;

  /// 무승부 여부
  bool get isDraw =>
      status == BattleStatus.completed &&
      challengerScore != null &&
      opponentScore != null &&
      challengerScore == opponentScore;
}
