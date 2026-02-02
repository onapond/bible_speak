import 'package:flutter/material.dart';
import '../../models/user_stats.dart';
import '../../services/stats_service.dart';
import '../../widgets/ux_widgets.dart';

/// 통계 대시보드 화면
class StatsDashboardScreen extends StatefulWidget {
  const StatsDashboardScreen({super.key});

  @override
  State<StatsDashboardScreen> createState() => _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends State<StatsDashboardScreen> {
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final StatsService _statsService = StatsService();
  UserStats? _stats;
  bool _isLoading = true;
  int? _cachedMaxMinutes; // 주간 그래프 maxMinutes 캐시

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
        // maxMinutes 캐싱 (로드 시점에 한 번만 계산)
        if (stats != null) {
          _cachedMaxMinutes = stats.recentWeekActivity
              .fold<int>(0, (max, d) => d.minutes > max ? d.minutes : max);
        }
        _isLoading = false;
      });
    }
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
          '학습 통계',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
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
    );
  }

  Widget _buildSummaryCard() {
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
              color: Colors.white,
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
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.star,
                  label: '마스터',
                  value: '${_stats!.totalVersesMastered}',
                  color: Colors.amber,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.timer,
                  label: '학습 시간',
                  value: _stats!.formattedStudyTime,
                  color: Colors.green,
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
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
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
          // 현재 스트릭
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  '연속 학습',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 80,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // 최장 스트릭
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  '최장 기록',
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

  Widget _buildWeeklyActivityCard() {
    final weekData = _stats!.recentWeekActivity;
    // 캐시된 maxMinutes 사용 (반복 계산 방지)
    final maxMinutes = _cachedMaxMinutes ?? 0;

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
              color: Colors.white,
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
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: height.clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        color: data.minutes > 0
                            ? _accentColor
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.dayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '퀴즈 통계',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            '총 퀴즈 참여',
            '${_stats!.totalQuizzesTaken}회',
            Icons.quiz,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            '만점 횟수',
            '${_stats!.perfectQuizCount}회',
            Icons.emoji_events,
            Colors.amber,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            '만점 비율',
            '${(_stats!.perfectQuizRate * 100).toStringAsFixed(1)}%',
            Icons.percent,
            Colors.green,
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
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '소셜 통계',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
        color: _bgColor,
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
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
