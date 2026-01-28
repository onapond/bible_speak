import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_model.dart';
import '../../services/social/group_activity_service.dart';
import '../../services/auth_service.dart';
import 'widgets/group_stats_card.dart';
import 'widgets/leaderboard_card.dart';
import 'widgets/activity_feed_card.dart';
import 'widgets/member_list_card.dart';

/// 그룹 대시보드 화면
class GroupDashboardScreen extends StatefulWidget {
  final String groupId;

  const GroupDashboardScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen>
    with SingleTickerProviderStateMixin {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final GroupActivityService _activityService = GroupActivityService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  GroupModel? _group;
  List<MemberInfo> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 그룹 정보 로드
      final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
      if (groupDoc.exists) {
        _group = GroupModel.fromFirestore(groupDoc.id, groupDoc.data()!);
      }

      // 멤버 목록 로드
      final membersSnapshot = await _firestore
          .collection('users')
          .where('groupId', isEqualTo: widget.groupId)
          .orderBy('talants', descending: true)
          .limit(50)
          .get();

      _members = membersSnapshot.docs
          .map((doc) => MemberInfo.fromFirestore(
                doc.id,
                doc.data(),
                _authService.currentUser?.uid,
              ))
          .toList();
    } catch (e) {
      print('Load group data error: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _group?.name ?? '그룹',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: '활동'),
            Tab(text: '랭킹'),
            Tab(text: '멤버'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _accentColor,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActivityTab(),
                  _buildRankingTab(),
                  _buildMembersTab(),
                ],
              ),
            ),
    );
  }

  /// 활동 탭
  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 그룹 통계 카드
        GroupStatsCard(
          group: _group,
          memberCount: _members.length,
        ),
        const SizedBox(height: 16),

        // 활동 피드
        ActivityFeedCard(
          groupId: widget.groupId,
          activityService: _activityService,
        ),
      ],
    );
  }

  /// 랭킹 탭
  Widget _buildRankingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LeaderboardCard(
          members: _members,
          currentUserId: _authService.currentUser?.uid,
        ),
      ],
    );
  }

  /// 멤버 탭
  Widget _buildMembersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MemberListCard(
          members: _members,
          groupId: widget.groupId,
          currentUserId: _authService.currentUser?.uid,
          onNudgeSent: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('격려 메시지를 보냈습니다'),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
      ],
    );
  }
}
