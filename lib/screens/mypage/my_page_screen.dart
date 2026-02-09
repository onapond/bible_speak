import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/user_stats.dart';
import '../../models/achievement.dart';
import '../../models/shop_item.dart';
import '../../services/auth_service.dart';
import '../../services/stats_service.dart';
import '../../services/achievement_service.dart';
import '../../services/shop_service.dart';
import '../../styles/parchment_theme.dart';
import '../../widgets/ux_widgets.dart';
import '../shop/shop_screen.dart';
import '../shop/inventory_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../settings/accessibility_settings_screen.dart';
import '../settings/texture_settings_screen.dart';
import '../admin/migration_screen.dart';
import '../admin/screenshot_helper_screen.dart';
import '../splash_screen.dart';

/// 통합 마이페이지 화면
/// - 프로필, 통계, 업적을 탭으로 통합
class MyPageScreen extends StatefulWidget {
  final AuthService authService;

  const MyPageScreen({
    super.key,
    required this.authService,
  });

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen>
    with SingleTickerProviderStateMixin {
  // Parchment Theme 색상
  static const _bgColor = ParchmentTheme.agedParchment;
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StatsService _statsService = StatsService();
  final AchievementService _achievementService = AchievementService();
  final ShopService _shopService = ShopService();

  UserModel? _user;
  Map<String, dynamic> _profileStats = {};
  UserStats? _stats;
  List<UserAchievement> _achievements = [];
  AchievementStats? _achievementStats;
  List<InventoryItem> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      _user = widget.authService.currentUser;

      if (_user != null) {
        // 모든 데이터 병렬 로드
        await Future.wait([
          _loadProfileStats(),
          _loadStats(),
          _loadAchievements(),
          _loadBadges(),
        ]);
      }
    } catch (e) {
      print('Load my page data error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileStats() async {
    if (_user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      final data = userDoc.data() ?? {};
      final streakData = data['streak'] as Map<String, dynamic>? ?? {};

      _profileStats = {
        'currentStreak': streakData['currentStreak'] ?? 0,
        'longestStreak': streakData['longestStreak'] ?? 0,
        'totalStudyDays': streakData['totalStudyDays'] ?? 0,
        'completedVerses': (_user!.completedVerses).length,
        'totalTalants': _user!.talants,
      };
    } catch (e) {
      print('Load profile stats error: $e');
    }
  }

  Future<void> _loadStats() async {
    _stats = await _statsService.getUserStats();
  }

  Future<void> _loadAchievements() async {
    _achievements = await _achievementService.getUserAchievements();
    _achievementStats = await _achievementService.getStats();
  }

  Future<void> _loadBadges() async {
    _badges = await _shopService.getInventoryByCategory(ShopCategory.badge);
  }

  Future<void> _claimReward(UserAchievement userAch) async {
    if (!userAch.isUnlocked || userAch.isRewardClaimed) return;

    final achievement = userAch.achievement;
    if (achievement == null) return;

    final success = await _achievementService.claimReward(userAch.achievementId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.toll, color: ParchmentTheme.manuscriptGold),
              const SizedBox(width: 8),
              Text('+${achievement.talantReward} 탈란트를 받았습니다!'),
            ],
          ),
          backgroundColor: ParchmentTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ParchmentTheme.backgroundGradient,
        ),
        child: Column(
          children: [
            // 커스텀 AppBar
            SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          color: ParchmentTheme.ancientInk,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            '마이페이지',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ParchmentTheme.ancientInk,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: ParchmentTheme.ancientInk),
                          onPressed: () => _showSettingsSheet(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // TabBar
                    Container(
                      decoration: BoxDecoration(
                        color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: _accentColor,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelColor: ParchmentTheme.ancientInk,
                        unselectedLabelColor: ParchmentTheme.weatheredGray,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: '프로필'),
                          Tab(text: '통계'),
                          Tab(text: '업적'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // TabBarView
            Expanded(
              child: _isLoading
                  ? LoadingStateWidget.general()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProfileTab(),
                        _buildStatsTab(),
                        _buildAchievementsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 프로필 탭 ============
  Widget _buildProfileTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: _accentColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildLevelCard(),
          const SizedBox(height: 16),
          _buildQuickStatsCard(),
          const SizedBox(height: 16),
          _buildBadgesCard(),
          const SizedBox(height: 16),
          _buildMenuCard(),
          if (_user?.role == UserRole.admin) ...[
            const SizedBox(height: 16),
            _buildAdminMenuCard(),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _user?.name.isNotEmpty == true ? _user!.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.softPapyrus,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.name ?? '사용자',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getRoleLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.toll, color: ParchmentTheme.manuscriptGold, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${_user?.talants ?? 0} 탈란트',
                      style: const TextStyle(
                        fontSize: 14,
                        color: ParchmentTheme.fadedScript,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard() {
    final level = _calculateLevel();
    final xpForCurrentLevel = _getXPForLevel(level);
    final xpForNextLevel = _getXPForLevel(level + 1);
    final currentXP = _calculateTotalXP();
    final progress = (currentXP - xpForCurrentLevel) / (xpForNextLevel - xpForCurrentLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _getLevelEmoji(level),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lv. $level',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                      Text(
                        _getLevelTitle(level),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ParchmentTheme.weatheredGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '$currentXP / $xpForNextLevel XP',
                style: const TextStyle(
                  fontSize: 12,
                  color: ParchmentTheme.weatheredGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: ParchmentTheme.warmVellum,
              valueColor: const AlwaysStoppedAnimation<Color>(ParchmentTheme.manuscriptGold),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: _accentColor, size: 20),
              SizedBox(width: 8),
              Text(
                '학습 요약',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatBox(
                icon: Icons.local_fire_department,
                iconColor: ParchmentTheme.warning,
                value: '${_profileStats['currentStreak'] ?? 0}일',
                label: '연속 학습',
              ),
              const SizedBox(width: 12),
              _buildStatBox(
                icon: Icons.check_circle,
                iconColor: ParchmentTheme.info,
                value: '${_profileStats['completedVerses'] ?? 0}',
                label: '완료 구절',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ParchmentTheme.weatheredGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech, color: ParchmentTheme.manuscriptGold, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '뱃지',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ParchmentTheme.ancientInk,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_badges.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryScreen()),
                  );
                },
                child: const Text('전체보기', style: TextStyle(color: ParchmentTheme.manuscriptGold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_badges.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 40,
                      color: ParchmentTheme.weatheredGray,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '아직 획득한 뱃지가 없습니다',
                      style: TextStyle(
                        color: ParchmentTheme.weatheredGray,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _badges.take(6).map((badge) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: badge.isActive
                        ? _accentColor.withValues(alpha: 0.15)
                        : ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: badge.isActive
                        ? Border.all(color: _accentColor.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(badge.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        badge.itemName,
                        style: TextStyle(
                          fontSize: 10,
                          color: badge.isActive ? _accentColor : ParchmentTheme.fadedScript,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.shopping_bag,
            iconColor: Colors.pink,
            title: '탈란트 샵',
            subtitle: '아이템 구매하기',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              );
            },
          ),
          const Divider(color: ParchmentTheme.warmVellum, height: 1, indent: 60),
          _buildMenuItem(
            icon: Icons.inventory_2,
            iconColor: ParchmentTheme.categoryMyPage,
            title: '내 아이템',
            subtitle: '구매한 아이템 관리',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: ParchmentTheme.ancientInk,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: ParchmentTheme.weatheredGray,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: ParchmentTheme.weatheredGray,
      ),
    );
  }

  Widget _buildAdminMenuCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParchmentTheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings,
                    color: ParchmentTheme.error.withValues(alpha: 0.7), size: 16),
                const SizedBox(width: 8),
                Text(
                  '관리자 도구',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.error.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: ParchmentTheme.warmVellum.withValues(alpha: 0.5), height: 1),
          _buildMenuItem(
            icon: Icons.camera_alt,
            iconColor: ParchmentTheme.error,
            title: '스크린샷 도우미',
            subtitle: '스토어 배포용 스크린샷',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ScreenshotHelperScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============ 통계 탭 ============
  Widget _buildStatsTab() {
    if (_stats == null) {
      return EmptyStateWidget.noLearningHistory(
        onStartLearning: () => Navigator.pop(context),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: _accentColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsSummaryCard(),
          const SizedBox(height: 16),
          _buildStreakCard(),
          const SizedBox(height: 16),
          _buildWeeklyActivityCard(),
          const SizedBox(height: 16),
          _buildQuizStatsCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatsSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withValues(alpha: 0.3),
            _accentColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '전체 요약',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.menu_book,
                  label: '학습 구절',
                  value: '${_stats!.totalVersesLearned}',
                  color: ParchmentTheme.categoryStudy,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.star,
                  label: '마스터',
                  value: '${_stats!.totalVersesMastered}',
                  color: ParchmentTheme.categoryQuiz,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.timer,
                  label: '학습 시간',
                  value: _stats!.formattedStudyTime,
                  color: ParchmentTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ParchmentTheme.ancientInk,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: ParchmentTheme.weatheredGray,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ParchmentTheme.warning.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_stats!.currentStreak}일',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const Text(
                  '연속 학습',
                  style: TextStyle(
                    fontSize: 12,
                    color: ParchmentTheme.weatheredGray,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 80,
            color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ParchmentTheme.categorySocial.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('👑', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_stats!.longestStreak}일',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const Text(
                  '최장 기록',
                  style: TextStyle(
                    fontSize: 12,
                    color: ParchmentTheme.weatheredGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityCard() {
    final weekData = _stats!.recentWeekActivity;
    final maxMinutes = weekData.fold<int>(
        0, (max, data) => data.minutes > max ? data.minutes : max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주간 활동',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekData.map((data) {
                final height = maxMinutes > 0
                    ? (data.minutes / maxMinutes) * 80
                    : 4.0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (data.minutes > 0)
                      Text(
                        '${data.minutes}분',
                        style: const TextStyle(
                          fontSize: 10,
                          color: ParchmentTheme.weatheredGray,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: height.clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        color: data.minutes > 0
                            ? _accentColor
                            : ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.dayLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ParchmentTheme.weatheredGray,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '퀴즈 통계',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuizStatRow(
            '총 퀴즈 참여',
            '${_stats!.totalQuizzesTaken}회',
            Icons.quiz,
            ParchmentTheme.categoryStudy,
          ),
          const SizedBox(height: 12),
          _buildQuizStatRow(
            '만점 횟수',
            '${_stats!.perfectQuizCount}회',
            Icons.emoji_events,
            ParchmentTheme.categoryQuiz,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStatRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: ParchmentTheme.fadedScript,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: ParchmentTheme.ancientInk,
          ),
        ),
      ],
    );
  }

  // ============ 업적 탭 ============
  Widget _buildAchievementsTab() {
    if (_achievements.isEmpty) {
      return EmptyStateWidget.noAchievements(
        onStartLearning: () => Navigator.pop(context),
      );
    }

    // 정렬: 해금된 것 우선, 그 다음 진행률 순
    final sorted = List<UserAchievement>.from(_achievements);
    sorted.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) {
        return a.isUnlocked ? -1 : 1;
      }
      return b.progressRate.compareTo(a.progressRate);
    });

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: _accentColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_achievementStats != null) _buildAchievementStatsHeader(),
          const SizedBox(height: 16),
          ...sorted.map((userAch) => _buildAchievementCard(userAch)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAchievementStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: _achievementStats!.progressRate,
                  backgroundColor: _bgColor,
                  valueColor: const AlwaysStoppedAnimation(_accentColor),
                  strokeWidth: 6,
                ),
                Center(
                  child: Text(
                    '${_achievementStats!.progressPercent}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ParchmentTheme.ancientInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_achievementStats!.unlockedCount}/${_achievementStats!.totalAchievements} 업적 달성',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const SizedBox(height: 4),
                if (_achievementStats!.unclaimedRewards > 0)
                  Row(
                    children: [
                      const Icon(Icons.card_giftcard,
                          color: ParchmentTheme.manuscriptGold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_achievementStats!.unclaimedRewards}개 보상 수령 가능',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ParchmentTheme.manuscriptGold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(UserAchievement userAch) {
    final achievement = userAch.achievement;
    if (achievement == null) return const SizedBox.shrink();

    final isUnlocked = userAch.isUnlocked;
    final canClaim = isUnlocked && !userAch.isRewardClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? achievement.tier.color.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? achievement.tier.color.withValues(alpha: 0.2)
                  : _bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                achievement.emoji,
                style: TextStyle(
                  fontSize: 24,
                  color: isUnlocked ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        achievement.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? ParchmentTheme.ancientInk : ParchmentTheme.weatheredGray,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? achievement.tier.color.withValues(alpha: 0.2)
                            : _bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        achievement.tier.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? achievement.tier.color
                              : ParchmentTheme.weatheredGray.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (!isUnlocked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: userAch.progressRate,
                      backgroundColor: _bgColor,
                      valueColor: AlwaysStoppedAnimation(
                        _accentColor.withValues(alpha: 0.7),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${userAch.progress}/${achievement.requirement}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: ParchmentTheme.weatheredGray,
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      const Icon(Icons.toll, color: ParchmentTheme.manuscriptGold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '+${achievement.talantReward}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.manuscriptGold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (canClaim)
            IconButton(
              onPressed: () => _claimReward(userAch),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ParchmentTheme.manuscriptGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            )
          else if (isUnlocked)
            const Icon(Icons.check_circle, color: ParchmentTheme.success, size: 24),
        ],
      ),
    );
  }

  // ============ 설정 바텀시트 ============
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
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
              '설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParchmentTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications, color: ParchmentTheme.warning, size: 22),
              ),
              title: const Text('알림 설정', style: TextStyle(color: ParchmentTheme.ancientInk)),
              subtitle: const Text('푸시 알림 관리',
                  style: TextStyle(color: ParchmentTheme.weatheredGray, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: ParchmentTheme.weatheredGray.withValues(alpha: 0.6)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParchmentTheme.categorySocial.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette, color: ParchmentTheme.categorySocial, size: 22),
              ),
              title: const Text('테마 설정', style: TextStyle(color: ParchmentTheme.ancientInk)),
              subtitle: const Text('앱 테마 변경',
                  style: TextStyle(color: ParchmentTheme.weatheredGray, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: ParchmentTheme.weatheredGray.withValues(alpha: 0.6)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParchmentTheme.categoryMyPage.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.accessibility_new, color: ParchmentTheme.categoryMyPage, size: 22),
              ),
              title: const Text('접근성 설정', style: TextStyle(color: ParchmentTheme.ancientInk)),
              subtitle: const Text('글꼴 크기, TTS 속도',
                  style: TextStyle(color: ParchmentTheme.weatheredGray, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: ParchmentTheme.weatheredGray.withValues(alpha: 0.6)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccessibilitySettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.brown.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.layers, color: Colors.brown, size: 22),
              ),
              title: const Text('텍스처 설정', style: TextStyle(color: ParchmentTheme.ancientInk)),
              subtitle: const Text('양피지 질감 효과 조절',
                  style: TextStyle(color: ParchmentTheme.weatheredGray, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: ParchmentTheme.weatheredGray.withValues(alpha: 0.6)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TextureSettingsScreen()),
                );
              },
            ),
            if (_user?.role == UserRole.admin)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_upload, color: Colors.deepPurple, size: 22),
                ),
                title: const Text('데이터 마이그레이션', style: TextStyle(color: ParchmentTheme.ancientInk)),
                subtitle: const Text('관리자용',
                    style: TextStyle(color: ParchmentTheme.weatheredGray, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: ParchmentTheme.weatheredGray.withValues(alpha: 0.6)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MigrationScreen()),
                  );
                },
              ),
            Divider(color: ParchmentTheme.warmVellum.withValues(alpha: 0.5)),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline, color: Colors.blueGrey, size: 22),
              ),
              title: const Text('앱 정보', style: TextStyle(color: ParchmentTheme.ancientInk)),
              subtitle: const Text('v1.0.0',
                  style: TextStyle(color: ParchmentTheme.weatheredGray, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: ParchmentTheme.weatheredGray.withValues(alpha: 0.6)),
              onTap: () {
                Navigator.pop(context);
                _showAppInfoDialog();
              },
            ),
            Divider(color: ParchmentTheme.warmVellum.withValues(alpha: 0.5)),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParchmentTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout, color: ParchmentTheme.error, size: 22),
              ),
              title: const Text('로그아웃', style: TextStyle(color: ParchmentTheme.error)),
              subtitle: const Text('계정에서 로그아웃',
                  style: TextStyle(color: ParchmentTheme.weatheredGray, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: ParchmentTheme.weatheredGray.withValues(alpha: 0.6)),
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============ 앱 정보 다이얼로그 ============
  void _showAppInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('📖', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            const Text(
              '바이블스픽',
              style: TextStyle(
                color: ParchmentTheme.ancientInk,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('버전', '1.0.0'),
            const SizedBox(height: 12),
            _buildInfoRow('개발', 'Onapond'),
            const SizedBox(height: 12),
            _buildInfoRow('이메일', 'support@onapond.com'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: 개인정보처리방침 URL 열기
                    },
                    child: const Text(
                      '개인정보처리방침',
                      style: TextStyle(color: ParchmentTheme.fadedScript, fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: 이용약관 URL 열기
                    },
                    child: const Text(
                      '이용약관',
                      style: TextStyle(color: ParchmentTheme.fadedScript, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: ParchmentTheme.fadedScript)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: ParchmentTheme.weatheredGray, fontSize: 14)),
        Text(value, style: const TextStyle(color: ParchmentTheme.ancientInk, fontSize: 14)),
      ],
    );
  }

  // ============ 로그아웃 확인 다이얼로그 ============
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: ParchmentTheme.error, size: 28),
            SizedBox(width: 12),
            Text(
              '로그아웃',
              style: TextStyle(
                color: ParchmentTheme.ancientInk,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          '정말 로그아웃 하시겠습니까?',
          style: TextStyle(color: ParchmentTheme.fadedScript),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: ParchmentTheme.weatheredGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.authService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (_) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ParchmentTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  // ============ Helper Methods ============
  Color _getRoleColor() {
    switch (_user?.role) {
      case UserRole.admin:
        return ParchmentTheme.error;
      case UserRole.leader:
        return ParchmentTheme.manuscriptGold;
      default:
        return _accentColor;
    }
  }

  String _getRoleLabel() {
    switch (_user?.role) {
      case UserRole.admin:
        return '관리자';
      case UserRole.leader:
        return '그룹 리더';
      default:
        return '멤버';
    }
  }

  int _calculateLevel() {
    final xp = _calculateTotalXP();
    if (xp < 100) return 1;
    if (xp < 300) return 2;
    if (xp < 600) return 3;
    if (xp < 1000) return 4;
    if (xp < 1500) return 5;
    if (xp < 2100) return 6;
    if (xp < 2800) return 7;
    if (xp < 3600) return 8;
    if (xp < 4500) return 9;
    return 10;
  }

  int _getXPForLevel(int level) {
    const xpTable = [0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 5500];
    if (level <= 0) return 0;
    if (level >= xpTable.length) return xpTable.last;
    return xpTable[level];
  }

  int _calculateTotalXP() {
    final studyDays = _profileStats['totalStudyDays'] ?? 0;
    final completedVerses = _profileStats['completedVerses'] ?? 0;
    final longestStreak = _profileStats['longestStreak'] ?? 0;

    return (studyDays * 10) + (completedVerses * 5) + (longestStreak * 3);
  }

  String _getLevelEmoji(int level) {
    const emojis = ['🌱', '🌿', '🌳', '🌸', '🌺', '🌻', '⭐', '💫', '🌟', '👑'];
    return emojis[(level - 1).clamp(0, emojis.length - 1)];
  }

  String _getLevelTitle(int level) {
    const titles = ['새싹', '풀잎', '나무', '꽃봉오리', '꽃', '해바라기', '별', '유성', '빛나는 별', '왕관'];
    return titles[(level - 1).clamp(0, titles.length - 1)];
  }
}
