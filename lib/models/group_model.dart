/// 그룹 모델
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? inviteCode;
  final int totalTalants;
  final int memberCount;
  final String? leaderId;
  final DateTime? createdAt;
  final bool isPublic;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.inviteCode,
    this.totalTalants = 0,
    this.memberCount = 0,
    this.leaderId,
    this.createdAt,
    this.isPublic = true,
  });

  /// Firestore 문서에서 생성
  factory GroupModel.fromFirestore(String id, Map<String, dynamic> data) {
    return GroupModel(
      id: id,
      name: data['name'] ?? id,
      description: data['description'],
      inviteCode: data['inviteCode'],
      totalTalants: data['totalTalants'] ?? 0,
      memberCount: data['memberCount'] ?? 0,
      leaderId: data['leaderId'],
      createdAt: data['createdAt']?.toDate(),
      isPublic: data['isPublic'] ?? true,
    );
  }

  /// Firestore 저장용 Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'totalTalants': totalTalants,
      'memberCount': memberCount,
      'leaderId': leaderId,
      'createdAt': createdAt,
      'isPublic': isPublic,
    };
  }

  /// 복사본 생성
  GroupModel copyWith({
    String? name,
    String? description,
    String? inviteCode,
    int? totalTalants,
    int? memberCount,
    String? leaderId,
    bool? isPublic,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      totalTalants: totalTalants ?? this.totalTalants,
      memberCount: memberCount ?? this.memberCount,
      leaderId: leaderId ?? this.leaderId,
      createdAt: createdAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

/// 그룹 멤버 정보 (랭킹용)
class MemberInfo {
  final String id;
  final String name;
  final int talants;
  final bool isMe;

  const MemberInfo({
    required this.id,
    required this.name,
    required this.talants,
    this.isMe = false,
  });

  factory MemberInfo.fromFirestore(String id, Map<String, dynamic> data, String? currentUserId) {
    return MemberInfo(
      id: id,
      name: data['name'] ?? '익명',
      talants: data['talants'] ?? 0,
      isMe: id == currentUserId,
    );
  }
}
