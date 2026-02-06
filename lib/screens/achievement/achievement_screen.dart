import 'package:flutter/material.dart';
import '../../models/achievement.dart';
import '../../services/achievement_service.dart';
import '../../styles/parchment_theme.dart';
import '../../widgets/ux_widgets.dart';

/// 업적 화면
class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen>
    with SingleTickerProviderStateMixin {
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final AchievementService _achievementService = AchievementService();

  late TabController _tabController;
  List<UserAchievement> _achievements = [];
  AchievementStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AchievementCategory.values.length + 1,
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final achievements = await _achievementService.getUserAchievements();
    final stats = await _achievementService.getStats();

    setState(() {
      _achievements = achievements;
      _stats = stats;
      _isLoading = false;
    });
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
              const Icon(Icons.toll, color: Colors.amber),
              const SizedBox(width: 8),
              Text('+${achievement.talantReward} 탈란트를 받았습니다!'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await _loadData();
    }
  }

  void _showAchievementDetail(UserAchievement userAch) {
    final achievement = userAch.achievement;
    if (achievement == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AchievementDetailSheet(
        userAchievement: userAch,
        onClaimReward: () {
          Navigator.pop(context);
          _claimReward(userAch);
        },
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
                    const Expanded(
                      child: Text(
                        '업적',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // TabBar
              Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  border: Border(
                    bottom: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: _accentColor,
                  labelColor: ParchmentTheme.ancientInk,
                  unselectedLabelColor: ParchmentTheme.fadedScript,
                  tabs: [
                    const Tab(text: '전체'),
                    ...AchievementCategory.values.map((c) => Tab(text: c.label)),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? LoadingStateWidget.general()
                    : Column(
                        children: [
                          // 통계 헤더
                          if (_stats != null) _buildStatsHeader(),

                          // 탭 컨텐츠
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildAchievementList(null),
                                ...AchievementCategory.values.map(
                                  (c) => _buildAchievementList(c),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          // 진행률 원형
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: _stats!.progressRate,
                  backgroundColor: ParchmentTheme.warmVellum,
                  valueColor: const AlwaysStoppedAnimation(_accentColor),
                  strokeWidth: 6,
                ),
                Center(
                  child: Text(
                    '${_stats!.progressPercent}%',
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

          // 통계
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_stats!.unlockedCount}/${_stats!.totalAchievements} 업적 달성',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const SizedBox(height: 4),
                if (_stats!.unclaimedRewards > 0)
                  Row(
                    children: [
                      const Icon(Icons.card_giftcard,
                          color: _accentColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_stats!.unclaimedRewards}개 보상 수령 가능',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    '계속 도전하세요!',
                    style: TextStyle(
                      fontSize: 12,
                      color: ParchmentTheme.fadedScript,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementList(AchievementCategory? category) {
    var filtered = _achievements;

    if (category != null) {
      filtered = _achievements
          .where((ua) => ua.achievement?.category == category)
          .toList();
    }

    // 해금된 것 우선, 그 다음 진행률 순
    filtered.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) {
        return a.isUnlocked ? -1 : 1;
      }
      return b.progressRate.compareTo(a.progressRate);
    });

    if (filtered.isEmpty) {
      return EmptyStateWidget.noAchievements(
        onStartLearning: () => Navigator.pop(context),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _accentColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final userAch = filtered[index];
          return _AchievementCard(
            key: ValueKey(userAch.achievementId),
            userAchievement: userAch,
            onTap: () => _showAchievementDetail(userAch),
            onClaimReward: () => _claimReward(userAch),
          );
        },
      ),
    );
  }
}

/// 업적 카드
class _AchievementCard extends StatelessWidget {
  final UserAchievement userAchievement;
  final VoidCallback onTap;
  final VoidCallback onClaimReward;

  const _AchievementCard({
    super.key,
    required this.userAchievement,
    required this.onTap,
    required this.onClaimReward,
  });

  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  @override
  Widget build(BuildContext context) {
    final achievement = userAchievement.achievement;
    if (achievement == null) return const SizedBox.shrink();

    final isUnlocked = userAchievement.isUnlocked;
    final canClaim = isUnlocked && !userAchievement.isRewardClaimed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? achievement.tier.color.withValues(alpha: 0.5)
                : _accentColor.withValues(alpha: 0.2),
            width: isUnlocked ? 2 : 1,
          ),
          boxShadow: ParchmentTheme.cardShadow,
        ),
        child: Row(
          children: [
            // 이모지/아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? achievement.tier.color.withValues(alpha: 0.2)
                    : ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  achievement.emoji,
                  style: TextStyle(
                    fontSize: 28,
                    color: isUnlocked ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // 정보
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
                      // 등급 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? achievement.tier.color.withValues(alpha: 0.2)
                              : ParchmentTheme.warmVellum,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          achievement.tier.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked
                                ? achievement.tier.color
                                : ParchmentTheme.weatheredGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isUnlocked
                          ? ParchmentTheme.fadedScript
                          : ParchmentTheme.weatheredGray,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 진행바 또는 보상
                  if (!isUnlocked)
                    _buildProgressBar(achievement)
                  else
                    Row(
                      children: [
                        const Icon(Icons.toll, color: _accentColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+${achievement.talantReward}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _accentColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // 보상 버튼
            if (canClaim)
              IconButton(
                onPressed: onClaimReward,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: ParchmentTheme.softPapyrus,
                    size: 20,
                  ),
                ),
              )
            else if (isUnlocked)
              const Icon(Icons.check_circle, color: ParchmentTheme.success),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Achievement achievement) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: userAchievement.progressRate,
            backgroundColor: ParchmentTheme.warmVellum,
            valueColor: AlwaysStoppedAnimation(
              _accentColor.withValues(alpha: 0.7),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${userAchievement.progress}/${achievement.requirement}',
          style: const TextStyle(
            fontSize: 10,
            color: ParchmentTheme.weatheredGray,
          ),
        ),
      ],
    );
  }
}

/// 업적 상세 시트
class _AchievementDetailSheet extends StatelessWidget {
  final UserAchievement userAchievement;
  final VoidCallback onClaimReward;

  const _AchievementDetailSheet({
    required this.userAchievement,
    required this.onClaimReward,
  });

  static const _accentColor = ParchmentTheme.manuscriptGold;

  @override
  Widget build(BuildContext context) {
    final achievement = userAchievement.achievement;
    if (achievement == null) return const SizedBox.shrink();

    final isUnlocked = userAchievement.isUnlocked;
    final canClaim = isUnlocked && !userAchievement.isRewardClaimed;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ParchmentTheme.warmVellum,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 이모지
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? achievement.tier.color.withValues(alpha: 0.2)
                  : ParchmentTheme.warmVellum.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              achievement.emoji,
              style: const TextStyle(fontSize: 48),
            ),
          ),
          const SizedBox(height: 16),

          // 이름
          Text(
            achievement.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 4),

          // 등급
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: achievement.tier.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              achievement.tier.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: achievement.tier.color,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 설명
          Text(
            achievement.description,
            style: const TextStyle(
              fontSize: 16,
              color: ParchmentTheme.fadedScript,
            ),
          ),
          const SizedBox(height: 24),

          // 진행 상태
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '진행 상태',
                      style: TextStyle(color: ParchmentTheme.fadedScript),
                    ),
                    Text(
                      '${userAchievement.progress}/${achievement.requirement}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ParchmentTheme.ancientInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: userAchievement.progressRate,
                    backgroundColor: ParchmentTheme.warmVellum,
                    valueColor: AlwaysStoppedAnimation(
                      isUnlocked ? ParchmentTheme.success : _accentColor,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '보상',
                      style: TextStyle(color: ParchmentTheme.fadedScript),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.toll, color: _accentColor, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '+${achievement.talantReward}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _accentColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 버튼
          SizedBox(
            width: double.infinity,
            child: canClaim
                ? Container(
                    decoration: BoxDecoration(
                      gradient: ParchmentTheme.goldButtonGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: ParchmentTheme.buttonShadow,
                    ),
                    child: ElevatedButton(
                      onPressed: onClaimReward,
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
                        '보상 받기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParchmentTheme.warmVellum,
                      foregroundColor: ParchmentTheme.fadedScript,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isUnlocked ? '보상 수령 완료' : '미달성',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
