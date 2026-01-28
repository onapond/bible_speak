import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/social/group_challenge_service.dart';
import '../../services/social/streak_service.dart';
import '../../services/social/morning_manna_service.dart';
import '../../services/social/nudge_service.dart';
import '../../widgets/social/activity_ticker.dart';
import '../../widgets/social/live_activity_ticker.dart';
import '../../widgets/social/group_goal_widget.dart';
import '../../widgets/social/streak_widget.dart';
import '../../widgets/social/morning_manna_widget.dart';
import '../../widgets/social/nudge_widget.dart';
import '../../models/user_streak.dart';
import '../../models/daily_verse.dart';
import '../../models/nudge.dart';
import '../study/book_selection_screen.dart';
import '../ranking/ranking_screen.dart';
import '../word_study/word_study_home_screen.dart';
import '../practice/verse_practice_screen.dart';
import '../admin/migration_screen.dart';
import '../splash_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../group/group_dashboard_screen.dart';
import '../shop/shop_screen.dart';
import '../profile/profile_screen.dart';
import '../achievement/achievement_screen.dart';
import '../social/friend_screen.dart';
import '../quiz/daily_quiz_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../stats/stats_dashboard_screen.dart';

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
  final _streakService = StreakService();
  final _morningMannaService = MorningMannaService();
  final _nudgeService = NudgeService();

  String? _groupName;
  WeeklyChallenge? _challenge;
  int _myContribution = 0;
  UserStreak _streak = const UserStreak();
  DailyVerse? _dailyVerse;
  EarlyBirdBonus _earlyBirdBonus = EarlyBirdBonus.calculate(DateTime.now());
  bool _hasClaimedEarlyBird = false;
  List<InactiveMember> _inactiveMembers = [];
  NudgeDailyStats _nudgeStats = const NudgeDailyStats(nudgesSent: 0, nudgesTo: {}, dailyLimit: 3);
  bool _isLoading = true;
  bool _isLoadingManna = true;

  @override
  void initState() {
    super.initState();
    _loadSocialData();
    _loadMorningManna();
  }

  Future<void> _loadSocialData() async {
    final user = widget.authService.currentUser;

    // 스트릭 체크 및 로드 (그룹 없어도)
    await _streakService.checkAndResetStreak();
    final streak = await _streakService.getStreak();
    if (mounted) {
      setState(() => _streak = streak);
    }

    if (user == null || user.groupId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        _groupService.getGroup(user.groupId),
        _challengeService.getCurrentChallenge(user.groupId),
        _challengeService.getMyContribution(user.groupId),
        _nudgeService.getInactiveMembers(user.groupId),
        _nudgeService.getDailyStats(isLeader: user.role.name == 'admin'),
      ]);

      if (mounted) {
        setState(() {
          _groupName = (results[0] as dynamic)?.name;
          _challenge = results[1] as WeeklyChallenge?;
          _myContribution = results[2] as int;
          _inactiveMembers = results[3] as List<InactiveMember>;
          _nudgeStats = results[4] as NudgeDailyStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorningManna() async {
    try {
      final results = await Future.wait([
        _morningMannaService.getDailyVerse(),
        _morningMannaService.hasClaimedEarlyBirdToday(),
      ]);

      if (mounted) {
        setState(() {
          _dailyVerse = results[0] as DailyVerse?;
          _hasClaimedEarlyBird = results[1] as bool;
          _earlyBirdBonus = _morningMannaService.getEarlyBirdBonus();
          _isLoadingManna = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingManna = false);
      }
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

            // 라이브 활동 티커 (그룹 있을 때만)
            if (hasGroup)
              SliverToBoxAdapter(
                child: LiveActivityTicker(
                  groupId: user!.groupId,
                  onTap: () => _navigateToRanking(),
                ),
              ),

            // 스트릭 위젯
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: StreakWidget(
                  streak: _streak,
                  onTapProtection: _streak.isAtRisk && _streak.canUseProtection
                      ? () => _showProtectionDialog()
                      : null,
                ),
              ),
            ),

            // 아침 만나 (오늘의 구절)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: MorningMannaWidget(
                  dailyVerse: _dailyVerse,
                  earlyBirdBonus: _earlyBirdBonus,
                  hasClaimedBonus: _hasClaimedEarlyBird,
                  onTapStudy: () => _navigateToDailyVerse(),
                  isLoading: _isLoadingManna,
                ),
              ),
            ),

            // 소셜 섹션 (그룹 있을 때만)
            if (hasGroup && !_isLoading) ...[
              // 그룹 활동 피드
              if (_groupName != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: GroupGoalWidget(
                      challenge: _challenge!,
                      myContribution: _myContribution,
                      onTapContribute: () => _navigateToPractice(),
                    ),
                  ),
                ),

              // 비활성 멤버 (찌르기)
              if (_inactiveMembers.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: InactiveMembersWidget(
                      members: _inactiveMembers,
                      stats: _nudgeStats,
                      onNudge: (member) => _showNudgeDialog(member),
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
                    icon: Icons.quiz,
                    title: '오늘의 퀴즈',
                    subtitle: '매일 도전',
                    color: Colors.orange,
                    onTap: () => _navigateToDailyQuiz(),
                  ),
                  _buildMenuCard(
                    icon: Icons.groups,
                    title: '그룹',
                    subtitle: '활동 및 랭킹',
                    color: Colors.purple,
                    onTap: () => _navigateToGroupDashboard(),
                  ),
                  _buildMenuCard(
                    icon: Icons.shopping_bag,
                    title: '샵',
                    subtitle: '아이템 구매',
                    color: Colors.pink,
                    onTap: () => _navigateToShop(),
                  ),
                  _buildMenuCard(
                    icon: Icons.emoji_events,
                    title: '업적',
                    subtitle: '도전과 보상',
                    color: Colors.amber,
                    onTap: () => _navigateToAchievements(),
                  ),
                  _buildMenuCard(
                    icon: Icons.people,
                    title: '친구',
                    subtitle: '친구 및 1:1 대전',
                    color: Colors.cyan,
                    onTap: () => _navigateToFriends(),
                  ),
                  _buildMenuCard(
                    icon: Icons.bar_chart,
                    title: '통계',
                    subtitle: '학습 현황',
                    color: Colors.indigo,
                    onTap: () => _navigateToStats(),
                  ),
                  _buildMenuCard(
                    icon: Icons.person,
                    title: '프로필',
                    subtitle: '내 정보 및 통계',
                    color: Colors.teal,
                    onTap: () => _navigateToProfile(),
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

  void _navigateToDailyVerse() async {
    if (_dailyVerse == null) {
      _navigateToPractice();
      return;
    }

    // Early Bird 보너스 클레임 시도
    if (_earlyBirdBonus.isEligible && !_hasClaimedEarlyBird) {
      final bonusAmount = await _morningMannaService.claimEarlyBirdBonus();
      if (bonusAmount > 0 && mounted) {
        setState(() => _hasClaimedEarlyBird = true);
        // 보너스 획득 다이얼로그 표시
        showDialog(
          context: context,
          builder: (context) => EarlyBirdBonusDialog(
            bonusAmount: bonusAmount,
            message: _earlyBirdBonus.message,
            emoji: _earlyBirdBonus.emoji,
            onDismiss: () {
              Navigator.pop(context);
              // 오늘의 구절로 이동
              _goToDailyVersePractice();
            },
          ),
        );
        // 유저 달란트 새로고침
        await widget.authService.refreshUser();
        return;
      }
    }

    // 바로 구절로 이동
    _goToDailyVersePractice();
  }

  void _goToDailyVersePractice() {
    if (_dailyVerse == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VersePracticeScreen(
          authService: widget.authService,
          book: _dailyVerse!.bookId,
          chapter: _dailyVerse!.chapter,
          initialVerse: _dailyVerse!.verse,
        ),
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

  void _navigateToGroupDashboard() {
    final user = widget.authService.currentUser;
    if (user == null || user.groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('그룹에 가입해야 이용할 수 있습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDashboardScreen(groupId: user.groupId),
      ),
    );
  }

  void _navigateToShop() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ShopScreen(),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  void _navigateToAchievements() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AchievementScreen(),
      ),
    );
  }

  void _navigateToFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FriendScreen(),
      ),
    );
  }

  void _navigateToDailyQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DailyQuizScreen(),
      ),
    );
  }

  void _navigateToStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StatsDashboardScreen(),
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

  void _showNudgeDialog(InactiveMember member) {
    final user = widget.authService.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => NudgeMessageDialog(
        targetName: member.name,
        onSend: (message, templateId) async {
          final success = await _nudgeService.sendNudge(
            toUserId: member.odId,
            toUserName: member.name,
            message: message,
            templateId: templateId,
            groupId: user.groupId,
            fromUserName: user.name,
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Text('💌', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text('${member.name}님에게 찌르기를 보냈어요!'),
                  ],
                ),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            // 통계 새로고침
            final stats = await _nudgeService.getDailyStats(
              isLeader: user.role.name == 'admin',
            );
            setState(() => _nudgeStats = stats);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('찌르기 전송에 실패했습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _showProtectionDialog() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StreakProtectionDialog(
        streak: _streak,
        dalantBalance: user.talants,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (result == true) {
      // 달란트 차감
      final deducted = await widget.authService.deductTalant(100);
      if (!deducted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('달란트가 부족합니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 스트릭 보호 사용
      final success = await _streakService.useProtection();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🛡️ 스트릭 보호권을 사용했습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        // 스트릭 데이터 새로고침
        final streak = await _streakService.getStreak();
        setState(() => _streak = streak);
      }
    }
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
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('알림 설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('테마 설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
                );
              },
            ),
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
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (_) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
