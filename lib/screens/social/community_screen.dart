import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_model.dart';
import '../../models/chat_message.dart';
import '../../models/friend.dart';
import '../../services/group_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/social/group_activity_service.dart';
import '../../services/social/friend_service.dart';
import '../../services/social/battle_service.dart';
import '../../widgets/ux_widgets.dart';
import '../group/widgets/group_stats_card.dart';
import '../group/widgets/leaderboard_card.dart';
import '../group/widgets/activity_feed_card.dart';
import '../group/widgets/member_list_card.dart';
import '../../styles/parchment_theme.dart';

/// 통합 커뮤니티 화면
/// - 그룹 선택 (드롭다운)
/// - 대시보드/채팅/멤버 탭
/// - 그룹 참여/생성 FAB
class CommunityScreen extends StatefulWidget {
  final AuthService authService;
  final String? initialGroupId;

  const CommunityScreen({
    super.key,
    required this.authService,
    this.initialGroupId,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final GroupService _groupService = GroupService();
  final GroupActivityService _activityService = GroupActivityService();
  final ChatService _chatService = ChatService();
  final FriendService _friendService = FriendService();
  final BattleService _battleService = BattleService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _friendSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late TabController _tabController;

  // 그룹 관련 상태
  List<GroupModel> _myGroups = [];
  GroupModel? _selectedGroup;
  List<MemberInfo> _members = [];
  bool _isLoading = true;
  bool _isSendingMessage = false;

  // 친구 관련 상태
  List<Friend> _friends = [];
  List<FriendRequest> _friendRequests = [];
  List<UserSearchResult> _friendSearchResults = [];
  BattleStats? _battleStats;
  bool _isFriendSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadMyGroups();
    _loadFriendsData();
    _listenToFriendRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _friendSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendsData() async {
    final friends = await _friendService.getFriends();
    final stats = await _battleService.getStats();

    if (mounted) {
      setState(() {
        _friends = friends;
        _battleStats = stats;
      });
    }
  }

  void _listenToFriendRequests() {
    _friendService.watchPendingRequests().listen((requests) {
      if (mounted) {
        setState(() => _friendRequests = requests);
      }
    });
  }

  Future<void> _searchFriends() async {
    final query = _friendSearchController.text.trim();
    if (query.length < 2) {
      setState(() => _friendSearchResults = []);
      return;
    }

    setState(() => _isFriendSearching = true);
    final results = await _friendService.searchUsers(query);
    setState(() {
      _friendSearchResults = results;
      _isFriendSearching = false;
    });
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    final result = await _friendService.sendFriendRequest(toUserId);
    if (mounted) {
      _showSnackBar(result.message, isError: !result.success);
      if (result.success) await _searchFriends();
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    final success = await _friendService.acceptFriendRequest(requestId);
    if (success) {
      await _loadFriendsData();
      if (mounted) _showSnackBar('친구가 되었습니다!');
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    await _friendService.rejectFriendRequest(requestId);
  }

  Future<void> _loadMyGroups() async {
    setState(() => _isLoading = true);

    try {
      final groups = await _groupService.getMyGroups();
      _myGroups = groups;

      // 초기 그룹 선택
      if (_myGroups.isNotEmpty) {
        if (widget.initialGroupId != null) {
          _selectedGroup = _myGroups.firstWhere(
            (g) => g.id == widget.initialGroupId,
            orElse: () => _myGroups.first,
          );
        } else {
          _selectedGroup = _myGroups.first;
        }
        await _loadGroupData();
      }
    } catch (e) {
      debugPrint('Load groups error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadGroupData() async {
    if (_selectedGroup == null) return;

    try {
      // 멤버 목록 로드
      final membersSnapshot = await _firestore
          .collection('users')
          .where('groupId', isEqualTo: _selectedGroup!.id)
          .orderBy('talants', descending: true)
          .limit(50)
          .get();

      _members = membersSnapshot.docs
          .map((doc) => MemberInfo.fromFirestore(
                doc.id,
                doc.data(),
                widget.authService.currentUser?.uid,
              ))
          .toList();

      // 읽음 처리
      _chatService.markAsRead(_selectedGroup!.id);
    } catch (e) {
      debugPrint('Load group data error: $e');
    }

    if (mounted) setState(() {});
  }

  void _onGroupChanged(GroupModel? group) {
    if (group == null || group.id == _selectedGroup?.id) return;
    setState(() {
      _selectedGroup = group;
      _members = [];
    });
    _loadGroupData();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage || _selectedGroup == null) return;

    final user = widget.authService.currentUser;
    if (user == null) return;

    setState(() => _isSendingMessage = true);
    _messageController.clear();

    await _chatService.sendMessage(
      groupId: _selectedGroup!.id,
      content: text,
      senderName: user.name,
    );

    setState(() => _isSendingMessage = false);
  }

  void _showGroupOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _GroupOptionsSheet(
        onJoinByCode: _showJoinByCodeDialog,
        onCreateGroup: _showCreateGroupDialog,
        onBrowseGroups: _showBrowseGroupsDialog,
      ),
    );
  }

  void _showJoinByCodeDialog() {
    Navigator.pop(context);
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '초대 코드로 참여',
          style: TextStyle(color: ParchmentTheme.ancientInk, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: codeController,
          style: const TextStyle(
            color: ParchmentTheme.ancientInk,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: 'XXXXXX',
            hintStyle: TextStyle(
              color: ParchmentTheme.fadedScript.withValues(alpha: 0.5),
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: ParchmentTheme.fadedScript),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.length != 6) {
                  _showSnackBar('6자리 코드를 입력해주세요', isError: true);
                  return;
                }
                Navigator.pop(context);
                await _joinGroupByCode(code);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: ParchmentTheme.softPapyrus,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('참여하기'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGroupByCode(String code) async {
    final group = await _groupService.findGroupByCode(code);
    if (group == null) {
      _showSnackBar('해당 코드의 그룹을 찾을 수 없습니다', isError: true);
      return;
    }

    final result = await _groupService.joinGroup(group.id);
    if (result.success) {
      _showSnackBar('${group.name} 그룹에 참여했습니다!');
      await _loadMyGroups();
      _onGroupChanged(group);
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  void _showCreateGroupDialog() {
    Navigator.pop(context);
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '새 그룹 만들기',
          style: TextStyle(color: ParchmentTheme.ancientInk, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: ParchmentTheme.ancientInk),
              decoration: InputDecoration(
                hintText: '그룹 이름 (최대 20자)',
                hintStyle: const TextStyle(color: ParchmentTheme.fadedScript),
                filled: true,
                fillColor: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.group, color: _accentColor),
              ),
              maxLength: 20,
            ),
            const SizedBox(height: 8),
            const Text(
              '그룹을 만들면 초대 코드가 생성됩니다.\n코드를 공유하여 멤버를 초대하세요.',
              style: TextStyle(
                fontSize: 12,
                color: ParchmentTheme.fadedScript,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: ParchmentTheme.fadedScript),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context);
                await _createGroup(name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: ParchmentTheme.softPapyrus,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('만들기'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup(String name) async {
    setState(() => _isLoading = true);

    final result = await _groupService.createGroupByUser(name: name);

    if (result.success && result.groupId != null) {
      _showSnackBar('그룹이 생성되었습니다!');
      _showInviteCodeDialog(name, result.inviteCode!);
      await _loadMyGroups();
    } else {
      _showSnackBar(result.message, isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showInviteCodeDialog(String groupName, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber),
            SizedBox(width: 8),
            Text('그룹 생성 완료!', style: TextStyle(color: ParchmentTheme.ancientInk)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              groupName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '초대 코드',
              style: TextStyle(
                fontSize: 12,
                color: ParchmentTheme.fadedScript,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      _showSnackBar('코드가 복사되었습니다');
                    },
                    icon: const Icon(Icons.copy, color: _accentColor),
                    tooltip: '복사',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '이 코드를 멤버들에게 공유하세요',
              style: TextStyle(
                fontSize: 12,
                color: ParchmentTheme.fadedScript,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: ParchmentTheme.softPapyrus,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }

  void _showBrowseGroupsDialog() {
    Navigator.pop(context);
    // 전체 그룹 목록 다이얼로그
    showDialog(
      context: context,
      builder: (context) => _BrowseGroupsDialog(
        groupService: _groupService,
        onGroupSelected: (group) async {
          Navigator.pop(context);
          final result = await _groupService.joinGroup(group.id);
          if (result.success) {
            _showSnackBar('${group.name} 그룹에 참여했습니다!');
            await _loadMyGroups();
            _onGroupChanged(group);
          } else {
            _showSnackBar(result.message, isError: true);
          }
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ParchmentTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      color: ParchmentTheme.ancientInk,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(child: _buildGroupDropdown()),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      color: ParchmentTheme.ancientInk,
                      onPressed: () {
                        _loadMyGroups();
                        _loadGroupData();
                      },
                    ),
                  ],
                ),
              ),
              // TabBar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  indicator: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: ParchmentTheme.softPapyrus,
                  unselectedLabelColor: ParchmentTheme.fadedScript,
                  tabs: [
                    const Tab(icon: Icon(Icons.dashboard, size: 20)),
                    const Tab(icon: Icon(Icons.chat, size: 20)),
                    const Tab(icon: Icon(Icons.people, size: 20)),
                    Tab(
                      icon: Badge(
                        isLabelVisible: _friendRequests.isNotEmpty,
                        label: Text('${_friendRequests.length}'),
                        child: const Icon(Icons.person_add, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _accentColor))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _selectedGroup == null ? _buildNoGroupState() : _buildDashboardTab(),
                          _selectedGroup == null ? _buildNoGroupState() : _buildChatTab(),
                          _selectedGroup == null ? _buildNoGroupState() : _buildMembersTab(),
                          _buildFriendsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: ParchmentTheme.goldButtonGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: ParchmentTheme.buttonShadow,
        ),
        child: FloatingActionButton.extended(
          onPressed: _showGroupOptions,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.group_add, color: ParchmentTheme.softPapyrus),
          label: const Text('그룹', style: TextStyle(color: ParchmentTheme.softPapyrus)),
        ),
      ),
    );
  }

  Widget _buildGroupDropdown() {
    if (_myGroups.isEmpty) {
      return const Text(
        '커뮤니티',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: ParchmentTheme.ancientInk,
        ),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<GroupModel>(
        value: _selectedGroup,
        dropdownColor: _cardColor,
        icon: const Icon(Icons.arrow_drop_down, color: ParchmentTheme.ancientInk),
        items: _myGroups.map((group) {
          return DropdownMenuItem<GroupModel>(
            value: group,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      group.name.isNotEmpty ? group.name[0] : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  group.name,
                  style: const TextStyle(
                    color: ParchmentTheme.ancientInk,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: _onGroupChanged,
      ),
    );
  }

  Widget _buildNoGroupState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 64,
                color: _accentColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '아직 참여한 그룹이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '그룹에 참여하여 함께 성경 암송을 해보세요!',
              style: TextStyle(
                fontSize: 14,
                color: ParchmentTheme.fadedScript,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: ParchmentTheme.goldButtonGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ParchmentTheme.buttonShadow,
              ),
              child: ElevatedButton.icon(
                onPressed: _showGroupOptions,
                icon: const Icon(Icons.group_add),
                label: const Text('그룹 참여하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: ParchmentTheme.softPapyrus,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      color: _accentColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 그룹 통계 카드
          GroupStatsCard(
            group: _selectedGroup,
            memberCount: _members.length,
          ),
          const SizedBox(height: 16),

          // 활동 피드
          ActivityFeedCard(
            groupId: _selectedGroup!.id,
            activityService: _activityService,
          ),
          const SizedBox(height: 16),

          // 랭킹 프리뷰 (상위 3명)
          _buildRankingPreview(),
        ],
      ),
    );
  }

  Widget _buildRankingPreview() {
    if (_members.isEmpty) return const SizedBox.shrink();

    final topMembers = _members.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🏆 랭킹',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: Text(
                  '전체 보기',
                  style: TextStyle(color: _accentColor, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...topMembers.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            final medals = ['🥇', '🥈', '🥉'];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(medals[index], style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      member.name,
                      style: const TextStyle(color: ParchmentTheme.ancientInk),
                    ),
                  ),
                  Text(
                    '${member.talants} 탈란트',
                    style: const TextStyle(
                      color: ParchmentTheme.fadedScript,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // 메시지 목록
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _chatService.getMessagesStream(_selectedGroup!.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _accentColor),
                );
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return _buildEmptyChatState();
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: messages.length,
                addRepaintBoundaries: true,
                addAutomaticKeepAlives: true,
                cacheExtent: 500.0,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final previousMessage =
                      index < messages.length - 1 ? messages[index + 1] : null;

                  final showDateDivider = previousMessage == null ||
                      _shouldShowDateDivider(message, previousMessage);

                  return RepaintBoundary(
                    child: Column(
                      children: [
                        if (showDateDivider)
                          _buildDateDivider(message.formattedDate),
                        _buildMessageBubble(message),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // 메시지 입력창
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: ParchmentTheme.warmVellum,
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 메시지가 없습니다',
            style: TextStyle(
              color: ParchmentTheme.fadedScript,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '첫 번째 메시지를 보내보세요!',
            style: TextStyle(
              color: ParchmentTheme.weatheredGray,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateDivider(ChatMessage current, ChatMessage previous) {
    final currentDate = DateTime(
      current.createdAt.year,
      current.createdAt.month,
      current.createdAt.day,
    );
    final previousDate = DateTime(
      previous.createdAt.year,
      previous.createdAt.month,
      previous.createdAt.day,
    );
    return currentDate != previousDate;
  }

  Widget _buildDateDivider(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: ParchmentTheme.warmVellum,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 12,
                color: ParchmentTheme.fadedScript,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: ParchmentTheme.warmVellum,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == _chatService.currentUserId;
    final isSystem = message.isSystemMessage;

    if (isSystem) {
      return _buildSystemMessage(message);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  message.senderEmoji ?? '👤',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    message.senderName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ParchmentTheme.fadedScript,
                    ),
                  ),
                ),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? _accentColor : _cardColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),
                  border: isMe ? null : Border.all(color: _accentColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? ParchmentTheme.softPapyrus : ParchmentTheme.ancientInk,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: Text(
                  message.formattedTime,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ParchmentTheme.weatheredGray,
                  ),
                ),
              ),
            ],
          ),
          if (isMe) const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              fontSize: 12,
              color: ParchmentTheme.fadedScript,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          top: BorderSide(color: _accentColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: ParchmentTheme.ancientInk),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                hintStyle: const TextStyle(color: ParchmentTheme.fadedScript),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSendingMessage ? null : _sendMessage,
            icon: _isSendingMessage
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accentColor,
                    ),
                  )
                : Icon(Icons.send, color: _accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      color: _accentColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 랭킹 보드
          LeaderboardCard(
            members: _members,
            currentUserId: widget.authService.currentUser?.uid,
          ),
          const SizedBox(height: 16),

          // 멤버 목록
          MemberListCard(
            members: _members,
            groupId: _selectedGroup!.id,
            currentUserId: widget.authService.currentUser?.uid,
            onNudgeSent: () {
              _showSnackBar('격려 메시지를 보냈습니다');
            },
          ),
        ],
      ),
    );
  }

  // ============ 친구 탭 ============
  Widget _buildFriendsTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // 서브 탭바
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              indicator: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: ParchmentTheme.softPapyrus,
              unselectedLabelColor: ParchmentTheme.fadedScript,
              tabs: const [
                Tab(text: '친구'),
                Tab(text: '요청'),
                Tab(text: '찾기'),
              ],
            ),
          ),
          // 대전 통계
          if (_battleStats != null) _buildBattleStats(),
          // 탭 콘텐츠
          Expanded(
            child: TabBarView(
              children: [
                _buildFriendsListTab(),
                _buildFriendRequestsTab(),
                _buildFriendSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sports_esports, color: _accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1:1 대전 기록',
                  style: TextStyle(fontWeight: FontWeight.bold, color: ParchmentTheme.ancientInk),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatChip('승', _battleStats!.wins, ParchmentTheme.success),
                    const SizedBox(width: 8),
                    _buildStatChip('패', _battleStats!.losses, ParchmentTheme.error),
                    const SizedBox(width: 8),
                    _buildStatChip('무', _battleStats!.draws, ParchmentTheme.weatheredGray),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${_battleStats!.winRatePercent}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildFriendsListTab() {
    if (_friends.isEmpty) {
      return EmptyStateWidget.noFriends(
        onSearchFriends: () {},
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriendsData,
      color: _accentColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        addRepaintBoundaries: true,
        addAutomaticKeepAlives: true,
        cacheExtent: 500.0,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return RepaintBoundary(
            child: _buildFriendCard(friend),
          );
        },
      ),
    );
  }

  Widget _buildFriendCard(Friend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _accentColor.withValues(alpha: 0.15),
                child: Text(
                  friend.name.isNotEmpty ? friend.name[0] : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ),
              if (friend.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: ParchmentTheme.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: _cardColor, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: ParchmentTheme.ancientInk),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.toll, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${friend.talants}',
                      style: const TextStyle(fontSize: 12, color: ParchmentTheme.fadedScript),
                    ),
                    if (friend.streak > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '${friend.streak}일',
                        style: const TextStyle(fontSize: 12, color: ParchmentTheme.fadedScript),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showChallengeDialog(friend),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.sports_esports, color: _accentColor),
            ),
            tooltip: '대전 신청',
          ),
        ],
      ),
    );
  }

  void _showChallengeDialog(Friend friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => _ChallengeSheet(
        friend: friend,
        battleService: _battleService,
        onResult: (message, success) {
          _showSnackBar(message, isError: !success);
        },
      ),
    );
  }

  Widget _buildFriendRequestsTab() {
    if (_friendRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: ParchmentTheme.warmVellum),
            const SizedBox(height: 16),
            const Text(
              '받은 요청이 없습니다',
              style: TextStyle(fontSize: 16, color: ParchmentTheme.fadedScript),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _friendRequests.length,
      addRepaintBoundaries: true,
      cacheExtent: 300.0,
      itemBuilder: (context, index) {
        final request = _friendRequests[index];
        return RepaintBoundary(
          child: _buildFriendRequestCard(request),
        );
      },
    );
  }

  Widget _buildFriendRequestCard(FriendRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _accentColor.withValues(alpha: 0.15),
            child: Text(
              request.fromUserName.isNotEmpty ? request.fromUserName[0] : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromUserName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: ParchmentTheme.ancientInk),
                ),
                const SizedBox(height: 4),
                const Text(
                  '친구 요청을 보냈습니다',
                  style: TextStyle(fontSize: 12, color: ParchmentTheme.fadedScript),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _rejectFriendRequest(request.id),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ParchmentTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: ParchmentTheme.error, size: 20),
            ),
          ),
          IconButton(
            onPressed: () => _acceptFriendRequest(request.id),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ParchmentTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check, color: ParchmentTheme.success, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _friendSearchController,
            style: const TextStyle(color: ParchmentTheme.ancientInk),
            decoration: InputDecoration(
              hintText: '이름으로 검색 (2자 이상)',
              hintStyle: const TextStyle(color: ParchmentTheme.fadedScript),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor),
              ),
              prefixIcon: const Icon(Icons.search, color: ParchmentTheme.fadedScript),
              suffixIcon: _isFriendSearching
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
                      ),
                    )
                  : IconButton(
                      onPressed: _searchFriends,
                      icon: Icon(Icons.search, color: _accentColor),
                    ),
            ),
            onSubmitted: (_) => _searchFriends(),
          ),
        ),
        Expanded(
          child: _friendSearchResults.isEmpty
              ? (_friendSearchController.text.isEmpty
                  ? const EmptyStateWidget(
                      emoji: '🔍',
                      title: '사용자를 검색하세요',
                      description: '이름으로 친구를 찾을 수 있습니다',
                    )
                  : EmptyStateWidget.noSearchResults(
                      searchTerm: _friendSearchController.text,
                    ))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _friendSearchResults.length,
                  addRepaintBoundaries: true,
                  cacheExtent: 300.0,
                  itemBuilder: (context, index) {
                    final user = _friendSearchResults[index];
                    return RepaintBoundary(
                      child: _buildSearchResultCard(user),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(UserSearchResult user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _accentColor.withValues(alpha: 0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0] : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: ParchmentTheme.ancientInk),
                ),
                if (user.groupName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.groupName!,
                    style: const TextStyle(fontSize: 12, color: ParchmentTheme.fadedScript),
                  ),
                ],
              ],
            ),
          ),
          if (user.isFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ParchmentTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '친구',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParchmentTheme.success),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _sendFriendRequest(user.odId),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: ParchmentTheme.softPapyrus,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('추가'),
            ),
        ],
      ),
    );
  }
}

/// 그룹 옵션 바텀시트
class _GroupOptionsSheet extends StatelessWidget {
  final VoidCallback onJoinByCode;
  final VoidCallback onCreateGroup;
  final VoidCallback onBrowseGroups;

  const _GroupOptionsSheet({
    required this.onJoinByCode,
    required this.onCreateGroup,
    required this.onBrowseGroups,
  });

  static const _accentColor = ParchmentTheme.manuscriptGold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ParchmentTheme.warmVellum,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '그룹 참여하기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 20),
          _buildOptionTile(
            icon: Icons.qr_code,
            title: '초대 코드로 참여',
            subtitle: '6자리 코드를 입력하세요',
            onTap: onJoinByCode,
          ),
          const SizedBox(height: 12),
          _buildOptionTile(
            icon: Icons.search,
            title: '그룹 찾아보기',
            subtitle: '공개 그룹 목록 보기',
            onTap: onBrowseGroups,
          ),
          const SizedBox(height: 12),
          _buildOptionTile(
            icon: Icons.add_circle_outline,
            title: '새 그룹 만들기',
            subtitle: '직접 그룹을 만들고 초대하기',
            onTap: onCreateGroup,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _accentColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ParchmentTheme.ancientInk,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ParchmentTheme.fadedScript,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: ParchmentTheme.fadedScript,
            ),
          ],
        ),
      ),
    );
  }
}

/// 대전 신청 시트
class _ChallengeSheet extends StatefulWidget {
  final Friend friend;
  final BattleService battleService;
  final Function(String message, bool success) onResult;

  const _ChallengeSheet({
    required this.friend,
    required this.battleService,
    required this.onResult,
  });

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final _verseController = TextEditingController(text: 'John 3:16');
  int _betAmount = 10;

  @override
  void dispose() {
    _verseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ParchmentTheme.warmVellum,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.sports_esports, color: _accentColor),
              const SizedBox(width: 12),
              Text(
                '${widget.friend.name}에게 대전 신청',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _verseController,
            style: const TextStyle(color: ParchmentTheme.ancientInk),
            decoration: InputDecoration(
              labelText: '대전 구절',
              labelStyle: const TextStyle(color: ParchmentTheme.fadedScript),
              hintText: 'e.g., John 3:16',
              hintStyle: const TextStyle(color: ParchmentTheme.weatheredGray),
              filled: true,
              fillColor: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                '베팅 탈란트',
                style: TextStyle(color: ParchmentTheme.fadedScript),
              ),
              const Spacer(),
              IconButton(
                onPressed: _betAmount > 5
                    ? () => setState(() => _betAmount -= 5)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: _accentColor,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.toll, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$_betAmount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ParchmentTheme.ancientInk,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _betAmount < 100
                    ? () => setState(() => _betAmount += 5)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: _accentColor,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: ParchmentTheme.goldButtonGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: ParchmentTheme.buttonShadow,
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final verse = _verseController.text.trim();
                  if (verse.isNotEmpty) {
                    Navigator.pop(context);
                    final result = await widget.battleService.createBattle(
                      opponentId: widget.friend.odId,
                      verseReference: verse,
                      betAmount: _betAmount,
                    );
                    widget.onResult(result.message, result.success);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: ParchmentTheme.softPapyrus,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '대전 신청',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 그룹 찾아보기 다이얼로그
class _BrowseGroupsDialog extends StatefulWidget {
  final GroupService groupService;
  final Function(GroupModel) onGroupSelected;

  const _BrowseGroupsDialog({
    required this.groupService,
    required this.onGroupSelected,
  });

  @override
  State<_BrowseGroupsDialog> createState() => _BrowseGroupsDialogState();
}

class _BrowseGroupsDialogState extends State<_BrowseGroupsDialog> {
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  List<GroupModel> _groups = [];
  List<GroupModel> _filteredGroups = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _searchController.addListener(_filterGroups);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await widget.groupService.getGroups();
    setState(() {
      _groups = groups;
      _filteredGroups = groups;
      _isLoading = false;
    });
  }

  void _filterGroups() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = _groups;
      } else {
        _filteredGroups = _groups
            .where((g) => g.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              '그룹 찾아보기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: ParchmentTheme.ancientInk),
              decoration: InputDecoration(
                hintText: '그룹 검색...',
                hintStyle: const TextStyle(color: ParchmentTheme.fadedScript),
                filled: true,
                fillColor: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: ParchmentTheme.fadedScript,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: _accentColor),
                    )
                  : _filteredGroups.isEmpty
                      ? const Center(
                          child: Text(
                            '검색 결과가 없습니다',
                            style: TextStyle(
                              color: ParchmentTheme.fadedScript,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredGroups.length,
                          itemBuilder: (context, index) {
                            final group = _filteredGroups[index];
                            return InkWell(
                              onTap: () => widget.onGroupSelected(group),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _accentColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          group.name.isNotEmpty
                                              ? group.name[0]
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _accentColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: ParchmentTheme.ancientInk,
                                            ),
                                          ),
                                          Text(
                                            '${group.memberCount}명',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: ParchmentTheme.fadedScript,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: _accentColor,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '닫기',
                style: TextStyle(color: ParchmentTheme.fadedScript),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
