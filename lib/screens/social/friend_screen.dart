import 'package:flutter/material.dart';
import '../../models/friend.dart';
import '../../services/social/friend_service.dart';
import '../../services/social/battle_service.dart';
import '../../widgets/ux_widgets.dart';

/// 친구 화면
class FriendScreen extends StatefulWidget {
  const FriendScreen({super.key});

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen>
    with SingleTickerProviderStateMixin {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final FriendService _friendService = FriendService();
  final BattleService _battleService = BattleService();
  final _searchController = TextEditingController();

  late TabController _tabController;
  List<Friend> _friends = [];
  List<FriendRequest> _requests = [];
  List<UserSearchResult> _searchResults = [];
  BattleStats? _battleStats;
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _listenToRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final friends = await _friendService.getFriends();
    final stats = await _battleService.getStats();

    setState(() {
      _friends = friends;
      _battleStats = stats;
      _isLoading = false;
    });
  }

  void _listenToRequests() {
    _friendService.watchPendingRequests().listen((requests) {
      if (mounted) {
        setState(() => _requests = requests);
      }
    });
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    final results = await _friendService.searchUsers(query);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    final result = await _friendService.sendFriendRequest(toUserId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.success ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      if (result.success) {
        await _searchUsers(); // 검색 결과 갱신
      }
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    final success = await _friendService.acceptFriendRequest(requestId);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('친구가 되었습니다!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    await _friendService.rejectFriendRequest(requestId);
  }

  void _showChallengeDialog(Friend friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ChallengeSheet(
        friend: friend,
        onChallenge: (verseRef, betAmount) async {
          Navigator.pop(context);
          final result = await _battleService.createBattle(
            opponentId: friend.odId,
            verseReference: verseRef,
            betAmount: betAmount,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor:
                    result.success ? Colors.green.shade700 : Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '친구',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_requests.isNotEmpty)
            Badge(
              label: Text('${_requests.length}'),
              child: IconButton(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.notifications),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: '친구 목록'),
            Tab(text: '요청'),
            Tab(text: '찾기'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(),
                _buildRequestsTab(),
                _buildSearchTab(),
              ],
            ),
    );
  }

  Widget _buildFriendsTab() {
    return Column(
      children: [
        // 대전 통계
        if (_battleStats != null) _buildBattleStats(),

        // 친구 목록
        Expanded(
          child: _friends.isEmpty
              ? EmptyStateWidget.noFriends(
                  onSearchFriends: () => _tabController.animateTo(2),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: _accentColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      return _FriendCard(
                        friend: friend,
                        onChallenge: () => _showChallengeDialog(friend),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBattleStats() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_esports, color: _accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1:1 대전 기록',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatChip('승', _battleStats!.wins, Colors.green),
                    const SizedBox(width: 8),
                    _buildStatChip('패', _battleStats!.losses, Colors.red),
                    const SizedBox(width: 8),
                    _buildStatChip('무', _battleStats!.draws, Colors.grey),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${_battleStats!.winRatePercent}%',
            style: const TextStyle(
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_requests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mail_outline,
        title: '받은 요청이 없습니다',
        subtitle: '새 친구 요청을 기다려보세요',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _RequestCard(
          request: request,
          onAccept: () => _acceptRequest(request.id),
          onReject: () => _rejectRequest(request.id),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // 검색바
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '이름으로 검색 (2자 이상)',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search,
                  color: Colors.white.withValues(alpha: 0.5)),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accentColor,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _searchUsers,
                      icon: const Icon(Icons.search, color: _accentColor),
                    ),
            ),
            onSubmitted: (_) => _searchUsers(),
          ),
        ),

        // 검색 결과
        Expanded(
          child: _searchResults.isEmpty
              ? (_searchController.text.isEmpty
                  ? const EmptyStateWidget(
                      emoji: '🔍',
                      title: '사용자를 검색하세요',
                      description: '이름으로 친구를 찾을 수 있습니다',
                    )
                  : EmptyStateWidget.noSearchResults(
                      searchTerm: _searchController.text,
                    ))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return _SearchResultCard(
                      user: user,
                      onAddFriend: () => _sendFriendRequest(user.odId),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// 친구 카드
class _FriendCard extends StatelessWidget {
  final Friend friend;
  final VoidCallback onChallenge;

  const _FriendCard({
    required this.friend,
    required this.onChallenge,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 아바타
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _accentColor.withValues(alpha: 0.2),
                child: Text(
                  friend.name.isNotEmpty ? friend.name[0] : '?',
                  style: const TextStyle(
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
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: _cardColor, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.toll, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${friend.talants}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    if (friend.streak > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.local_fire_department,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '${friend.streak}일',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 대전 버튼
          IconButton(
            onPressed: onChallenge,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sports_esports, color: _accentColor),
            ),
            tooltip: '대전 신청',
          ),
        ],
      ),
    );
  }
}

/// 요청 카드
class _RequestCard extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _accentColor.withValues(alpha: 0.2),
            child: Text(
              request.fromUserName.isNotEmpty ? request.fromUserName[0] : '?',
              style: const TextStyle(
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '친구 요청을 보냈습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onReject,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 20),
            ),
          ),
          IconButton(
            onPressed: onAccept,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check, color: Colors.green, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// 검색 결과 카드
class _SearchResultCard extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback onAddFriend;

  const _SearchResultCard({
    required this.user,
    required this.onAddFriend,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _accentColor.withValues(alpha: 0.2),
            child: Text(
              user.name.isNotEmpty ? user.name[0] : '?',
              style: const TextStyle(
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (user.groupName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.groupName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (user.isFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '친구',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: onAddFriend,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('추가'),
            ),
        ],
      ),
    );
  }
}

/// 대전 신청 시트
class _ChallengeSheet extends StatefulWidget {
  final Friend friend;
  final Function(String verseRef, int betAmount) onChallenge;

  const _ChallengeSheet({
    required this.friend,
    required this.onChallenge,
  });

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  static const _bgColor = Color(0xFF0F0F1A);
  static const _accentColor = Color(0xFF6C63FF);

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
          // 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 상대방
          Row(
            children: [
              const Icon(Icons.sports_esports, color: _accentColor),
              const SizedBox(width: 12),
              Text(
                '${widget.friend.name}에게 대전 신청',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 구절 선택
          TextField(
            controller: _verseController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '대전 구절',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              hintText: 'e.g., John 3:16',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: _bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 베팅 금액
          Row(
            children: [
              Text(
                '베팅 탈란트',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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
                  color: _bgColor,
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
                        color: Colors.white,
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

          // 설명
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '승자가 베팅금의 2배를 가져갑니다. 무승부시 반환됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 신청 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final verse = _verseController.text.trim();
                if (verse.isNotEmpty) {
                  widget.onChallenge(verse, _betAmount);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '대전 신청',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
