import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/social/group_activity_service.dart';
import '../../services/social/group_challenge_service.dart';
import '../../widgets/social/activity_ticker.dart';
import '../../widgets/social/group_goal_widget.dart';
import '../study/book_selection_screen.dart';
import '../ranking/ranking_screen.dart';
import '../word_study/word_study_home_screen.dart';
import '../admin/migration_screen.dart';

/// 메인 메뉴 화면
/// - 각 기능으로 이동하는 허브
class MainMenuScreen extends StatefulWidget {
  final AuthService authService;

  const MainMenuScreen({
    super.key,
    required this.authService,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final _groupService = GroupService();
  final _challengeService = GroupChallengeService();

  String? _groupName;
  WeeklyChallenge? _challenge;
  int _myContribution = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSocialData();
  }

  Future<void> _loadSocialData() async {
    final user = widget.authService.currentUser;
    if (user == null || user.groupId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        _groupService.getGroup(user.groupId),
        _challengeService.getCurrentChallenge(user.groupId),
        _challengeService.getMyContribution(user.groupId),
      ]);

      if (mounted) {
        setState(() {
          _groupName = (results[0] as dynamic)?.name;
          _challenge = results[1] as WeeklyChallenge?;
          _myContribution = results[2] as int;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final hasGroup = user != null && user.groupId.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 헤더
            SliverToBoxAdapter(
              child: _buildHeader(user?.name ?? '사용자', user?.talants ?? 0),
            ),

            // 소셜 섹션 (그룹 있을 때만)
            if (hasGroup && !_isLoading) ...[
              // 그룹 활동 피드
              if (_groupName != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: ActivityTicker(
                      groupId: user!.groupId,
                      groupName: _groupName!,
                      onTapMore: () => _navigateToRanking(),
                    ),
                  ),
                ),

              // 주간 챌린지
              if (_challenge != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GroupGoalWidget(
                      challenge: _challenge!,
                      myContribution: _myContribution,
                      onTapContribute: () => _navigateToPractice(),
                    ),
                  ),
                ),
            ],

            // 메뉴 그리드
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate([
                  _buildMenuCard(
                    icon: Icons.menu_book,
                    title: '암송 연습',
                    subtitle: '영어 성경 암송',
                    color: Colors.blue,
                    onTap: () => _navigateToPractice(),
                  ),
                  _buildMenuCard(
                    icon: Icons.abc,
                    title: '단어 공부',
                    subtitle: '성경 영단어',
                    color: Colors.green,
                    onTap: () => _navigateToWordStudy(),
                  ),
                  _buildMenuCard(
                    icon: Icons.leaderboard,
                    title: '랭킹',
                    subtitle: '그룹별 달란트',
                    color: Colors.amber,
                    onTap: () => _navigateToRanking(),
                  ),
                  _buildMenuCard(
                    icon: Icons.settings,
                    title: '설정',
                    subtitle: '앱 설정',
                    color: Colors.grey,
                    onTap: () => _showSettingsSheet(),
                  ),
                ]),
              ),
            ),

            // 하단 여백
            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String userName, int talants) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          // 로고 & 타이틀
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '바이블 스픽',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '안녕하세요, $userName님!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // 달란트 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 6),
                Text(
                  '$talants',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPractice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookSelectionScreen(authService: widget.authService),
      ),
    );
  }

  void _navigateToRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RankingScreen(authService: widget.authService),
      ),
    );
  }

  void _navigateToWordStudy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordStudyHomeScreen(authService: widget.authService),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 기능은 준비 중입니다.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text('${widget.authService.currentUser?.name ?? "사용자"}'),
              subtitle: Text('그룹: ${widget.authService.currentUser?.groupId ?? ""}'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('TTS 캐시 삭제'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('캐시 삭제');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.deepPurple),
              title: const Text('Firestore 마이그레이션'),
              subtitle: const Text('관리자용 - 데이터 업로드'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MigrationScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () async {
                Navigator.pop(context);
                await widget.authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
