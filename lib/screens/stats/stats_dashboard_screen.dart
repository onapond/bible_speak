import 'package:flutter/material.dart';
import '../../models/user_stats.dart';
import '../../services/stats_service.dart';
import '../../styles/parchment_theme.dart';
import '../../widgets/ux_widgets.dart';

/// 통계 대시보드 화면
class StatsDashboardScreen extends StatefulWidget {
  const StatsDashboardScreen({super.key});

  @override
  State<StatsDashboardScreen> createState() => _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends State<StatsDashboardScreen> {
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final StatsService _statsService = StatsService();
  UserStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final stats = await _statsService.getUserStats();

    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
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
                        '학습 통계',
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
              Expanded(
                child: _isLoading
                    ? LoadingStateWidget.syncing()
                    : RefreshIndicator(
                        onRefresh: _loadStats,
                        color: _accentColor,
                        child: _stats == null
                            ? EmptyStateWidget.noLearningHistory(
                                onStartLearning: () => Navigator.pop(context),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  // 요약 카드
                                  _buildSummaryCard(),
                                  const SizedBox(height: 16),

                                  // 스트릭 카드
                                  _buildStreakCard(),
                                  const SizedBox(height: 16),

                                  // 주간 활동 그래프
                                  _buildWeeklyActivityCard(),
                                  const SizedBox(height: 16),

                                  // 상세 통계
                                  _buildDetailStatsCard(),
                                  const SizedBox(height: 16),

                                  // 소셜 통계
                                  _buildSocialStatsCard(),
                                ],
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
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
                child: _buildStatItem(
                  icon: Icons.menu_book,
                  label: '학습 구절',
                  value: '${_stats!.totalVersesLearned}',
                  color: ParchmentTheme.categoryStudy,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.star,
                  label: '마스터',
                  value: '${_stats!.totalVersesMastered}',
                  color: _accentColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
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

  Widget _buildStatItem({
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
            color: ParchmentTheme.fadedScript,
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
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          // 현재 스트릭
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ParchmentTheme.warning.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '🔥',
                    style: TextStyle(
                      fontSize: 32,
                      color: _stats!.currentStreak > 0 ? null : Colors.grey,
                    ),
                  ),
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
                    color: ParchmentTheme.fadedScript,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 80,
            color: ParchmentTheme.warmVellum,
          ),
          // 최장 스트릭
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '👑',
                    style: TextStyle(fontSize: 32),
                  ),
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

  Widget _buildWeeklyActivityCard() {
    final weekData = _stats!.recentWeekActivity;
    final maxMinutes = weekData.fold<int>(
        0, (max, data) => data.minutes > max ? data.minutes : max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
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
                          color: ParchmentTheme.fadedScript,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: height.clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        color: data.minutes > 0
                            ? _accentColor
                            : ParchmentTheme.warmVellum,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.dayLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ParchmentTheme.fadedScript,
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

  Widget _buildDetailStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
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
          _buildDetailRow(
            '총 퀴즈 참여',
            '${_stats!.totalQuizzesTaken}회',
            Icons.quiz,
            ParchmentTheme.categoryStudy,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            '만점 횟수',
            '${_stats!.perfectQuizCount}회',
            Icons.emoji_events,
            _accentColor,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            '만점 비율',
            '${(_stats!.perfectQuizRate * 100).toStringAsFixed(1)}%',
            Icons.percent,
            ParchmentTheme.success,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
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

  Widget _buildSocialStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '소셜 통계',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSocialStat(
                  '💰',
                  '총 탈란트',
                  '${_stats!.totalTalants}',
                ),
              ),
              Expanded(
                child: _buildSocialStat(
                  '❤️',
                  '받은 반응',
                  '${_stats!.totalReactionsReceived}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSocialStat(
                  '👋',
                  '보낸 넛지',
                  '${_stats!.totalNudgesSent}',
                ),
              ),
              Expanded(
                child: _buildSocialStat(
                  '🔔',
                  '받은 넛지',
                  '${_stats!.totalNudgesReceived}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialStat(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
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
              fontSize: 11,
              color: ParchmentTheme.fadedScript,
            ),
          ),
        ],
      ),
    );
  }
}
