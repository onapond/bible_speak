import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';

/// 랭킹 화면
/// - 그룹별 달란트 순위
/// - 그룹 내 멤버 순위
class RankingScreen extends StatefulWidget {
  final AuthService authService;

  const RankingScreen({
    super.key,
    required this.authService,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GroupService _groupService = GroupService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('달란트 현황'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.groups), text: '그룹 순위'),
            Tab(icon: Icon(Icons.person), text: '우리 그룹'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupRanking(),
          _buildMemberRanking(),
        ],
      ),
    );
  }

  Widget _buildGroupRanking() {
    return StreamBuilder<List<GroupModel>>(
      stream: _groupService.watchGroupRanking(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return const Center(child: Text('그룹 정보가 없습니다.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          addRepaintBoundaries: true,
          cacheExtent: 400.0,
          itemBuilder: (context, index) {
            final group = groups[index];
            final isMyGroup = group.id == widget.authService.currentUser?.groupId;
            final rank = index + 1;

            return RepaintBoundary(
              key: ValueKey(group.id),
              child: Card(
              color: isMyGroup ? Colors.indigo.shade50 : null,
              child: ListTile(
                leading: _buildRankBadge(rank),
                title: Row(
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMyGroup ? Colors.indigo : null,
                      ),
                    ),
                    if (isMyGroup)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'MY',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                subtitle: Text('${group.memberCount}명 참여중'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${group.totalTalants}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ));
          },
        );
      },
    );
  }

  Widget _buildMemberRanking() {
    final groupId = widget.authService.currentUser?.groupId;
    final userId = widget.authService.currentUser?.uid;

    if (groupId == null) {
      return const Center(child: Text('그룹 정보가 없습니다.'));
    }

    return StreamBuilder<List<MemberInfo>>(
      stream: _groupService.watchGroupMembers(groupId, userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return const Center(child: Text('멤버 정보가 없습니다.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          addRepaintBoundaries: true,
          cacheExtent: 400.0,
          itemBuilder: (context, index) {
            final member = members[index];
            final rank = index + 1;

            return RepaintBoundary(
              key: ValueKey(member.id),
              child: Card(
              color: member.isMe ? Colors.indigo.shade50 : null,
              child: ListTile(
                leading: _buildRankBadge(rank),
                title: Row(
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: member.isMe ? Colors.indigo : null,
                      ),
                    ),
                    if (member.isMe)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'ME',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${member.talants}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ));
          },
        );
      },
    );
  }

  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    IconData? icon;

    switch (rank) {
      case 1:
        badgeColor = Colors.amber;
        icon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = Colors.grey.shade400;
        icon = Icons.emoji_events;
        break;
      case 3:
        badgeColor = Colors.brown.shade300;
        icon = Icons.emoji_events;
        break;
      default:
        badgeColor = Colors.grey.shade200;
        icon = null;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: 20)
            : Text(
                '$rank',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
