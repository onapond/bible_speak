import 'package:flutter/material.dart';
import '../../models/achievement.dart';
import '../../services/achievement_service.dart';

/// 업적 화면
class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen>
    with SingleTickerProviderStateMixin {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

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
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '업적',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: _accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            const Tab(text: '전체'),
            ...AchievementCategory.values.map((c) => Tab(text: c.label)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
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
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
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
                  backgroundColor: _bgColor,
                  valueColor: const AlwaysStoppedAnimation(_accentColor),
                  strokeWidth: 6,
                ),
                Center(
                  child: Text(
                    '${_stats!.progressPercent}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (_stats!.unclaimedRewards > 0)
                  Row(
                    children: [
                      const Icon(Icons.card_giftcard,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_stats!.unclaimedRewards}개 보상 수령 가능',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '계속 도전하세요!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
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

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _accentColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final userAch = filtered[index];
          return _AchievementCard(
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
    required this.userAchievement,
    required this.onTap,
    required this.onClaimReward,
  });

  static const _cardColor = Color(0xFF1E1E2E);
  static const _bgColor = Color(0xFF0F0F1A);
  static const _accentColor = Color(0xFF6C63FF);

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
                : Colors.transparent,
            width: 2,
          ),
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
                    : _bgColor,
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
                            color: isUnlocked ? Colors.white : Colors.white54,
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
                              : _bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          achievement.tier.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked
                                ? achievement.tier.color
                                : Colors.white38,
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
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 진행바 또는 보상
                  if (!isUnlocked)
                    _buildProgressBar(achievement)
                  else
                    Row(
                      children: [
                        const Icon(Icons.toll, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+${achievement.talantReward}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
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
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              )
            else if (isUnlocked)
              const Icon(Icons.check_circle, color: Colors.green),
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
            backgroundColor: _bgColor,
            valueColor: AlwaysStoppedAnimation(
              _accentColor.withValues(alpha: 0.7),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${userAchievement.progress}/${achievement.requirement}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.5),
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

  static const _bgColor = Color(0xFF0F0F1A);
  static const _accentColor = Color(0xFF6C63FF);

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
              color: Colors.white.withValues(alpha: 0.3),
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
                  : _bgColor,
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
              color: Colors.white,
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
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          // 진행 상태
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '진행 상태',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '${userAchievement.progress}/${achievement.requirement}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: userAchievement.progressRate,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(
                      isUnlocked ? Colors.green : _accentColor,
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
                      style: TextStyle(color: Colors.white70),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.toll, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '+${achievement.talantReward}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
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
            child: ElevatedButton(
              onPressed: canClaim ? onClaimReward : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canClaim ? Colors.amber : Colors.grey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                canClaim
                    ? '보상 받기'
                    : isUnlocked
                        ? '보상 수령 완료'
                        : '미달성',
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
