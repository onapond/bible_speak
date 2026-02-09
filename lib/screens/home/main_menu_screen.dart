import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../services/social/group_challenge_service.dart';
import '../../services/social/streak_service.dart';
import '../../services/social/morning_manna_service.dart';
import '../../services/social/nudge_service.dart';
import '../../services/review_service.dart';
import '../../services/daily_quiz_service.dart';
import '../../services/daily_goal_service.dart';
import '../../services/stats_service.dart';
import '../../styles/parchment_theme.dart';
import '../../widgets/social/activity_ticker.dart';
import '../../widgets/social/live_activity_ticker.dart';
import '../../widgets/social/group_goal_widget.dart';
import '../../widgets/social/streak_widget.dart';
import '../../widgets/social/morning_manna_widget.dart';
import '../../widgets/social/nudge_widget.dart';
import '../../widgets/common/parchment_card.dart';
import '../../models/user_streak.dart';
import '../../models/daily_verse.dart';
import '../../models/nudge.dart';
import '../../models/daily_goal.dart';
import '../../models/user_stats.dart';
import '../../widgets/common/shimmer_loading.dart';
import '../../widgets/common/animated_transitions.dart';
import '../ranking/ranking_screen.dart';
import '../word_study/word_study_home_screen.dart';
import '../practice/verse_practice_redesigned.dart';
import '../social/community_screen.dart';
import '../study/learning_center_screen.dart';
import '../mypage/my_page_screen.dart';

/// 메인 메뉴 화면
/// - 각 기능으로 이동하는 허브
class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen> {
  final _groupService = GroupService();
  final _challengeService = GroupChallengeService();
  final _streakService = StreakService();
  final _morningMannaService = MorningMannaService();
  final _nudgeService = NudgeService();
  final _reviewService = ReviewService();
  final _quizService = DailyQuizService();
  final _dailyGoalService = DailyGoalService();
  final _statsService = StatsService();

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

  // Phase 3: 오늘의 할 일 상태
  int _dueReviewCount = 0;
  bool _hasCompletedQuiz = false;
  bool _isLoadingTasks = true;

  // Phase 4: 학습 성과 상태
  DailyGoal? _dailyGoal;
  UserStats? _userStats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    // 모든 데이터 병렬 로드 (성능 최적화)
    _loadAllData();
  }

  /// 모든 데이터 병렬 로드 (타임아웃 적용)
  Future<void> _loadAllData() async {
    final user = ref.read(currentUserProvider);

    // 스트릭과 만나 데이터 병렬 로드 (그룹 무관)
    await Future.wait([
      _loadStreakData(),
      _loadMorningManna(),
      _loadTodaysTasks(),
      _loadDailyGoalAndStats(),
      if (user != null && user.groupId.isNotEmpty) _loadGroupData(user),
    ]);
  }

  /// 일일 목표 및 통계 로드
  Future<void> _loadDailyGoalAndStats() async {
    try {
      await _dailyGoalService.init();
      final stats = await _statsService.getUserStats();

      if (mounted) {
        setState(() {
          _dailyGoal = _dailyGoalService.todayGoal;
          _userStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  /// 오늘의 할 일 로드 (복습, 퀴즈)
  Future<void> _loadTodaysTasks() async {
    try {
      final results = await Future.wait([
        _reviewService.getDueItems(),
        _quizService.hasCompletedToday(),
      ]).timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _dueReviewCount = (results[0] as List).length;
          _hasCompletedQuiz = results[1] as bool;
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
      }
    }
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
    final user = ref.watch(currentUserProvider);
    final talants = ref.watch(userTalantsProvider);
    final hasGroup = user != null && user.groupId.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ParchmentTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
            // 헤더
            SliverToBoxAdapter(
              child: _buildHeader(user?.name ?? '사용자', talants),
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

            // 오늘의 할 일 요약 카드 (로딩 중 스켈레톤)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingTasks
                      ? const TasksCardSkeleton()
                      : _buildTodaysTasksCard(),
                ),
              ),
            ),

            // 일일 목표 진행률 & 주간 통계 (로딩 중 스켈레톤)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingStats
                      ? const GoalCardSkeleton()
                      : _dailyGoal != null
                          ? _buildProgressStatsCard()
                          : const SizedBox.shrink(),
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

            // 오늘의 학습 CTA 버튼 (로딩 중 스켈레톤)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingTasks
                      ? const CTAButtonSkeleton()
                      : _buildMainCTAButton(),
                ),
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
                    color: ParchmentTheme.categoryStudy,
                    onTap: () => _showLearningSheet(),
                  ),
                  _buildMenuCard(
                    icon: Icons.abc,
                    title: '단어',
                    subtitle: '성경 영단어',
                    color: ParchmentTheme.categoryPractice,
                    onTap: () => _navigateToWordStudy(),
                  ),
                  _buildMenuCard(
                    icon: Icons.groups,
                    title: '커뮤니티',
                    subtitle: '그룹 · 친구 · 채팅',
                    color: ParchmentTheme.categorySocial,
                    onTap: () => _navigateToGroupDashboard(),
                  ),
                  _buildMenuCard(
                    icon: Icons.person,
                    title: '마이',
                    subtitle: '프로필 · 통계 · 설정',
                    color: ParchmentTheme.categoryMyPage,
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
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '안녕하세요, $userName님!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: ParchmentTheme.fadedScript,
                  ),
                ),
              ],
            ),
          ),
          // 달란트 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: ParchmentTheme.manuscriptGold, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$talants',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.manuscriptGold,
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
    return BounceOnTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ParchmentTheme.softPapyrus,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
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
                color: ParchmentTheme.ancientInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: ParchmentTheme.weatheredGray,
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
        await ref.read(authServiceProvider).refreshUser();
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
        builder: (_) => VersePracticeRedesigned(
          book: _dailyVerse!.bookId,
          chapter: _dailyVerse!.chapter,
          initialVerse: _dailyVerse!.verse,
          dailyVerseKoreanText: _dailyVerse!.textKo,
        ),
      ),
    );
  }

  void _navigateToRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RankingScreen(authService: ref.read(authServiceProvider)),
      ),
    );
  }

  void _navigateToWordStudy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordStudyHomeScreen(authService: ref.read(authServiceProvider)),
      ),
    );
  }

  void _navigateToGroupDashboard() {
    final user = ref.read(authServiceProvider).currentUser;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityScreen(
          authService: ref.read(authServiceProvider),
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
          authService: ref.read(authServiceProvider),
          initialTabIndex: tabIndex,
        ),
      ),
    );
  }

  /// 오늘의 할 일 요약 카드
  Widget _buildTodaysTasksCard() {
    final hasReview = _dueReviewCount > 0;
    final hasQuiz = !_hasCompletedQuiz;
    final totalTasks = (hasReview ? 1 : 0) + (hasQuiz ? 1 : 0);

    return ParchmentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.checklist,
                  color: ParchmentTheme.manuscriptGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '오늘의 할 일',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
              ),
              if (totalTasks > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ParchmentTheme.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalTasks개 남음',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ParchmentTheme.warning,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ParchmentTheme.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '완료!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ParchmentTheme.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 퀵 액션 칩들
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 복습 칩
              _buildQuickActionChip(
                icon: Icons.replay,
                label: hasReview ? '복습 $_dueReviewCount개' : '복습 완료',
                color: hasReview ? ParchmentTheme.info : ParchmentTheme.weatheredGray,
                isActive: hasReview,
                onTap: () => _navigateToLearningCenter(tabIndex: 1),
              ),
              // 퀴즈 칩
              _buildQuickActionChip(
                icon: Icons.quiz,
                label: hasQuiz ? '오늘의 퀴즈' : '퀴즈 완료',
                color: hasQuiz ? ParchmentTheme.warning : ParchmentTheme.weatheredGray,
                isActive: hasQuiz,
                onTap: () => _navigateToLearningCenter(tabIndex: 2),
              ),
              // 암송 칩
              _buildQuickActionChip(
                icon: Icons.menu_book,
                label: '암송 연습',
                color: ParchmentTheme.manuscriptGold,
                isActive: true,
                onTap: () => _navigateToLearningCenter(tabIndex: 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 퀵 액션 칩 위젯
  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return BounceOnTap(
      onTap: onTap,
      scaleFactor: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : ParchmentTheme.warmVellum.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.5) : ParchmentTheme.warmVellum,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? color : ParchmentTheme.weatheredGray,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? color : ParchmentTheme.weatheredGray,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: color.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 일일 목표 진행률 & 주간 통계 카드
  Widget _buildProgressStatsCard() {
    final goal = _dailyGoal!;
    final overallProgress = goal.overallProgress;
    final stats = _userStats;

    return ParchmentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: ParchmentTheme.manuscriptGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '오늘의 목표',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
              ),
              // 전체 진행률
              _buildCircularGoalProgress(overallProgress),
            ],
          ),
          const SizedBox(height: 16),

          // 3개 목표 진행 바
          _buildGoalProgressRow(
            icon: Icons.abc,
            label: '단어',
            current: goal.studiedWords,
            target: goal.targetWords,
            color: ParchmentTheme.info,
          ),
          const SizedBox(height: 10),
          _buildGoalProgressRow(
            icon: Icons.quiz,
            label: '퀴즈',
            current: goal.completedQuizzes,
            target: goal.targetQuizzes,
            color: ParchmentTheme.warning,
          ),
          const SizedBox(height: 10),
          _buildGoalProgressRow(
            icon: Icons.style,
            label: '플래시카드',
            current: goal.completedFlashcards,
            target: goal.targetFlashcards,
            color: ParchmentTheme.success,
          ),

          // 목표 달성 시 축하 메시지
          if (goal.isGoalMet) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParchmentTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParchmentTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal.bonusClaimed
                          ? '오늘 목표 달성! 보너스 달란트 획득 완료'
                          : '오늘 목표 달성! 보너스 달란트를 받으세요',
                      style: const TextStyle(
                        color: ParchmentTheme.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (!goal.bonusClaimed)
                    GestureDetector(
                      onTap: _claimDailyGoalBonus,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ParchmentTheme.success,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '받기',
                          style: TextStyle(
                            color: ParchmentTheme.softPapyrus,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // 주간 통계 (있을 경우)
          if (stats != null) ...[
            const SizedBox(height: 16),
            const Divider(color: ParchmentTheme.warmVellum),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStatItem(
                  label: '총 암송',
                  value: '${stats.totalVersesLearned}',
                  icon: Icons.menu_book,
                  color: ParchmentTheme.info,
                ),
                _buildMiniStatItem(
                  label: '마스터',
                  value: '${stats.totalVersesMastered}',
                  icon: Icons.star,
                  color: ParchmentTheme.manuscriptGold,
                ),
                _buildMiniStatItem(
                  label: '학습 시간',
                  value: '${stats.totalStudyMinutes}분',
                  icon: Icons.timer,
                  color: ParchmentTheme.success,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 원형 목표 진행률 위젯
  Widget _buildCircularGoalProgress(double progress) {
    final percent = (progress * 100).toInt();
    final isComplete = progress >= 1.0;

    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: ParchmentTheme.warmVellum,
              valueColor: AlwaysStoppedAnimation(
                isComplete ? ParchmentTheme.success : ParchmentTheme.manuscriptGold,
              ),
            ),
          ),
          Center(
            child: isComplete
                ? const Icon(Icons.check, color: ParchmentTheme.success, size: 22)
                : Text(
                    '$percent%',
                    style: const TextStyle(
                      color: ParchmentTheme.ancientInk,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 목표 진행 행
  Widget _buildGoalProgressRow({
    required IconData icon,
    required String label,
    required int current,
    required int target,
    required Color color,
  }) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final isComplete = current >= target;

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: ParchmentTheme.fadedScript,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: ParchmentTheme.warmVellum,
              valueColor: AlwaysStoppedAnimation(
                isComplete ? ParchmentTheme.success : color,
              ),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          child: Text(
            '$current/$target',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isComplete ? ParchmentTheme.success : ParchmentTheme.fadedScript,
            ),
          ),
        ),
      ],
    );
  }

  /// 미니 통계 아이템
  Widget _buildMiniStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: ParchmentTheme.weatheredGray,
          ),
        ),
      ],
    );
  }

  /// 일일 목표 보너스 수령
  Future<void> _claimDailyGoalBonus() async {
    final success = await _dailyGoalService.claimBonus();
    if (success && mounted) {
      // 달란트 새로고침
      await ref.read(authServiceProvider).refreshUser();
      setState(() {
        _dailyGoal = _dailyGoalService.todayGoal;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('🎁', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Text('목표 달성 보너스 10 달란트 획득!'),
            ],
          ),
          backgroundColor: ParchmentTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// 스마트 CTA 버튼 - 상황에 따라 다른 액션 추천
  Widget _buildMainCTAButton() {
    // 우선순위: 복습 > 퀴즈 > 새 학습
    final hasReview = _dueReviewCount > 0;
    final hasQuiz = !_hasCompletedQuiz;

    String title;
    String subtitle;
    IconData icon;
    VoidCallback onTap;

    if (hasReview) {
      // 복습 우선
      title = '복습하기';
      subtitle = '오늘 복습할 구절 $_dueReviewCount개';
      icon = Icons.replay;
      onTap = () => _navigateToLearningCenter(tabIndex: 1);
    } else if (hasQuiz) {
      // 퀴즈 다음
      title = '오늘의 퀴즈';
      subtitle = '매일 퀴즈로 실력 점검';
      icon = Icons.quiz;
      onTap = () => _navigateToLearningCenter(tabIndex: 2);
    } else {
      // 새 학습
      title = '오늘의 학습 시작';
      subtitle = _dailyVerse != null
          ? _dailyVerse!.reference
          : '새로운 구절을 시작해보세요';
      icon = Icons.play_arrow_rounded;
      onTap = () => _navigateToDailyVerse();
    }

    return BounceOnTap(
      onTap: onTap,
      scaleFactor: 0.97,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: ParchmentTheme.goldButtonGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3),
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
                color: ParchmentTheme.softPapyrus.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: ParchmentTheme.softPapyrus,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ParchmentTheme.softPapyrus,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ParchmentTheme.softPapyrus,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: ParchmentTheme.softPapyrus.withValues(alpha: 0.85),
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
        builder: (_) => MyPageScreen(authService: ref.read(authServiceProvider)),
      ),
    );
  }

  void _showNudgeDialog(InactiveMember member) {
    final user = ref.read(authServiceProvider).currentUser;
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
                backgroundColor: ParchmentTheme.success,
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
              SnackBar(
                content: const Text('찌르기 전송에 실패했습니다.'),
                backgroundColor: ParchmentTheme.error,
              ),
            );
          }
        },
      ),
    );
  }

  void _showProtectionDialog() async {
    final user = ref.read(authServiceProvider).currentUser;
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
      final deducted = await ref.read(authServiceProvider).deductTalant(100);
      if (!deducted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('달란트가 부족합니다.'),
              backgroundColor: ParchmentTheme.error,
            ),
          );
        }
        return;
      }

      // 스트릭 보호 사용
      final success = await _streakService.useProtection();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🛡️ 연속 학습 보호권을 사용했습니다!'),
            backgroundColor: ParchmentTheme.success,
          ),
        );
        // 스트릭 데이터 새로고침
        final streak = await _streakService.getStreak();
        setState(() => _streak = streak);
      }
    }
  }

}
