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
import '../ranking/ranking_screen.dart';
import '../word_study/word_study_home_screen.dart';
import '../practice/verse_practice_screen.dart';
import '../social/community_screen.dart';
import '../study/learning_center_screen.dart';
import '../mypage/my_page_screen.dart';

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
    // 모든 데이터 병렬 로드 (성능 최적화)
    _loadAllData();
  }

  /// 모든 데이터 병렬 로드 (타임아웃 적용)
  Future<void> _loadAllData() async {
    final user = widget.authService.currentUser;

    // 스트릭과 만나 데이터 병렬 로드 (그룹 무관)
    await Future.wait([
      _loadStreakData(),
      _loadMorningManna(),
      if (user != null && user.groupId.isNotEmpty) _loadGroupData(user),
    ]);
  }

  Future<void> _loadStreakData() async {
    try {
      // 타임아웃 적용
      await _streakService.checkAndResetStreak().timeout(const Duration(seconds: 3));
      final streak = await _streakService.getStreak().timeout(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _streak = streak);
      }
    } catch (e) {
      // 타임아웃 또는 오류 시 기본값 유지
      print('⚠️ 스트릭 로드 실패: $e');
    }
  }

  Future<void> _loadGroupData(dynamic user) async {
    try {
      // 그룹 데이터 병렬 로드 (5초 타임아웃)
      final results = await Future.wait([
        _groupService.getGroup(user.groupId),
        _challengeService.getCurrentChallenge(user.groupId),
        _challengeService.getMyContribution(user.groupId),
        _nudgeService.getInactiveMembers(user.groupId),
        _nudgeService.getDailyStats(isLeader: user.isAdmin),
      ]).timeout(const Duration(seconds: 5));

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
      print('⚠️ 그룹 데이터 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorningManna() async {
    try {
      // 타임아웃 적용 (3초)
      final results = await Future.wait([
        _morningMannaService.getDailyVerse(),
        _morningMannaService.hasClaimedEarlyBirdToday(),
      ]).timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _dailyVerse = results[0] as DailyVerse?;
          _hasClaimedEarlyBird = results[1] as bool;
          _earlyBirdBonus = _morningMannaService.getEarlyBirdBonus();
          _isLoadingManna = false;
        });
      }
    } catch (e) {
      print('⚠️ 만나 로드 실패: $e');
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
            if (hasGroup && user != null)
              SliverToBoxAdapter(
                child: LiveActivityTicker(
                  groupId: user.groupId,
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
            if (hasGroup && !_isLoading && user != null) ...[
              // 그룹 활동 피드
              if (_groupName != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ActivityTicker(
                      groupId: user.groupId,
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
                      onTapContribute: () => _navigateToLearningCenter(),
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

            // 오늘의 학습 CTA 버튼
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildMainCTAButton(),
              ),
            ),

            // 4개 핵심 메뉴
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                delegate: SliverChildListDelegate([
                  _buildMenuCard(
                    icon: Icons.menu_book,
                    title: '학습',
                    subtitle: '암송 · 복습 · 퀴즈',
                    color: Colors.blue,
                    onTap: () => _showLearningSheet(),
                  ),
                  _buildMenuCard(
                    icon: Icons.abc,
                    title: '단어',
                    subtitle: '성경 영단어',
                    color: Colors.green,
                    onTap: () => _navigateToWordStudy(),
                  ),
                  _buildMenuCard(
                    icon: Icons.groups,
                    title: '커뮤니티',
                    subtitle: '그룹 · 친구 · 채팅',
                    color: Colors.purple,
                    onTap: () => _navigateToGroupDashboard(),
                  ),
                  _buildMenuCard(
                    icon: Icons.person,
                    title: '마이',
                    subtitle: '프로필 · 통계 · 설정',
                    color: Colors.teal,
                    onTap: () => _navigateToMyPage(),
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

  void _navigateToDailyVerse() async {
    if (_dailyVerse == null) {
      _navigateToLearningCenter();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityScreen(
          authService: widget.authService,
          initialGroupId: user?.groupId.isNotEmpty == true ? user!.groupId : null,
        ),
      ),
    );
  }

  /// 학습센터로 이동
  void _navigateToLearningCenter({int tabIndex = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LearningCenterScreen(
          authService: widget.authService,
          initialTabIndex: tabIndex,
        ),
      ),
    );
  }

  /// 오늘의 학습 CTA 버튼
  Widget _buildMainCTAButton() {
    return GestureDetector(
      onTap: () => _navigateToDailyVerse(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.purple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '오늘의 학습 시작',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dailyVerse != null
                        ? _dailyVerse!.reference
                        : '새로운 구절을 시작해보세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 학습센터로 이동 (학습 카드 클릭)
  void _showLearningSheet() {
    _navigateToLearningCenter();
  }

  /// 마이페이지로 이동
  void _navigateToMyPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyPageScreen(authService: widget.authService),
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
              isLeader: user.isAdmin,
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
            content: Text('🛡️ 연속 학습 보호권을 사용했습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        // 스트릭 데이터 새로고침
        final streak = await _streakService.getStreak();
        setState(() => _streak = streak);
      }
    }
  }

}
