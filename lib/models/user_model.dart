/// 사용자 역할 정의
enum UserRole {
  admin,   // 전체 관리자
  leader,  // 그룹 리더
  member,  // 일반 멤버
}

/// 사용자 모델
class UserModel {
  final String uid;
  final String name;
  final String? email;
  final String groupId;
  final UserRole role;
  final int talants;
  final List<int> completedVerses;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    this.email,
    required this.groupId,
    this.role = UserRole.member,
    this.talants = 0,
    this.completedVerses = const [],
    this.createdAt,
  });

  /// Firestore 문서에서 생성
  factory UserModel.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '익명',
      email: data['email'],
      groupId: data['groupId'] ?? '',
      role: _parseRole(data['role']),
      talants: data['talants'] ?? 0,
      completedVerses: List<int>.from(data['completedVerses'] ?? []),
      createdAt: data['createdAt']?.toDate(),
    );
  }

  /// Firestore 저장용 Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'groupId': groupId,
      'role': role.name,
      'talants': talants,
      'completedVerses': completedVerses,
      'createdAt': createdAt,
    };
  }

  /// 역할 문자열 파싱
  static UserRole _parseRole(String? roleStr) {
    switch (roleStr) {
      case 'admin':
        return UserRole.admin;
      case 'leader':
        return UserRole.leader;
      default:
        return UserRole.member;
    }
  }

  /// 복사본 생성 (일부 필드 변경)
  UserModel copyWith({
    String? name,
    String? email,
    String? groupId,
    UserRole? role,
    int? talants,
    List<int>? completedVerses,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      groupId: groupId ?? this.groupId,
      role: role ?? this.role,
      talants: talants ?? this.talants,
      completedVerses: completedVerses ?? this.completedVerses,
      createdAt: createdAt,
    );
  }

  /// 관리자 여부
  bool get isAdmin => role == UserRole.admin;

  /// 리더 이상 권한
  bool get isLeaderOrAbove => role == UserRole.admin || role == UserRole.leader;
}
