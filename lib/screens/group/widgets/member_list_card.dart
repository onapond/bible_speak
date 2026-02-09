import 'package:flutter/material.dart';
import '../../../models/group_model.dart';
import '../../../models/nudge.dart';
import '../../../services/social/nudge_service.dart';
import '../../../services/auth_service.dart';
import '../../../styles/parchment_theme.dart';

/// 멤버 목록 카드
class MemberListCard extends StatefulWidget {
  final List<MemberInfo> members;
  final String groupId;
  final String? currentUserId;
  final VoidCallback? onNudgeSent;

  const MemberListCard({
    super.key,
    required this.members,
    required this.groupId,
    this.currentUserId,
    this.onNudgeSent,
  });

  @override
  State<MemberListCard> createState() => _MemberListCardState();
}

class _MemberListCardState extends State<MemberListCard> {
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final NudgeService _nudgeService = NudgeService();
  final AuthService _authService = AuthService();
  List<InactiveMember> _inactiveMembers = [];

  @override
  void initState() {
    super.initState();
    _loadInactiveMembers();
  }

  Future<void> _loadInactiveMembers() async {
    try {
      final members = await _nudgeService.getInactiveMembers(widget.groupId);
      if (mounted) {
        setState(() => _inactiveMembers = members);
      }
    } catch (e) {
      debugPrint('Load inactive members error: $e');
    }
  }

  Future<void> _sendNudge(MemberInfo member) async {
    final userName = _authService.currentUser?.name ?? '멤버';

    // 기본 격려 메시지
    final messages = [
      '${member.name}님, 오늘 함께 암송해요! 💪',
      '${member.name}님이 그립습니다! 같이 말씀 암송해요 🙏',
      '${member.name}님, 잠깐만 시간 내서 말씀 암송해봐요!',
    ];

    final result = await _nudgeService.sendNudge(
      toUserId: member.id,
      toUserName: member.name,
      message: messages[DateTime.now().second % messages.length],
      groupId: widget.groupId,
      fromUserName: userName,
    );

    if (result && widget.onNudgeSent != null) {
      widget.onNudgeSent!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.people, color: _accentColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '멤버',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.members.length}명',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 비활성 멤버 섹션
          if (_inactiveMembers.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParchmentTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParchmentTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notification_important, color: ParchmentTheme.warning, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '응원이 필요한 멤버 ${_inactiveMembers.length}명',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '3일 이상 접속하지 않은 멤버들입니다',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          const Divider(color: Colors.white12, height: 1),

          // 멤버 목록
          if (widget.members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.group_add,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '아직 멤버가 없습니다',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.members.length,
              separatorBuilder: (_, __) => const Divider(
                color: Colors.white12,
                height: 1,
                indent: 70,
              ),
              itemBuilder: (context, index) {
                final member = widget.members[index];
                final inactiveInfo = _inactiveMembers
                    .cast<InactiveMember?>()
                    .firstWhere((m) => m?.odId == member.id, orElse: () => null);
                final isInactive = inactiveInfo != null;

                return _buildMemberItem(member, isInactive, inactiveInfo);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(MemberInfo member, bool isInactive, InactiveMember? inactiveInfo) {
    final isMe = member.id == widget.currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 프로필 아바타
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isMe
                    ? _accentColor.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                child: Text(
                  member.name.isNotEmpty ? member.name[0] : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMe ? _accentColor : Colors.white70,
                  ),
                ),
              ),
              if (isInactive)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: ParchmentTheme.warning,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.schedule, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // 이름 + 상태
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                          color: isMe ? _accentColor : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '나',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.toll, size: 12, color: ParchmentTheme.manuscriptGold),
                    const SizedBox(width: 4),
                    Text(
                      '${member.talants}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    if (isInactive && inactiveInfo != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ParchmentTheme.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${inactiveInfo.daysSinceActive}일 전',
                          style: const TextStyle(
                            fontSize: 10,
                            color: ParchmentTheme.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 찌르기 버튼 (자신 제외, 비활성 멤버 우선)
          if (!isMe)
            IconButton(
              onPressed: () => _sendNudge(member),
              icon: Icon(
                Icons.notifications_active,
                color: isInactive ? ParchmentTheme.warning : Colors.white30,
                size: 22,
              ),
              tooltip: '격려 보내기',
            ),
        ],
      ),
    );
  }
}
