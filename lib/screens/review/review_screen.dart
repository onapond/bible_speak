import 'package:flutter/material.dart';
import '../../models/review_item.dart';
import '../../services/review_service.dart';
import '../../styles/parchment_theme.dart';
import '../../widgets/ux_widgets.dart';

/// 복습 화면
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final ReviewService _reviewService = ReviewService();

  List<ReviewItem> _dueItems = [];
  ReviewStats _stats = const ReviewStats();
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _showAnswer = false;
  DateTime? _sessionStart;
  int _sessionCorrect = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final items = await _reviewService.getDueItems();
    final stats = await _reviewService.getStats();

    setState(() {
      _dueItems = items;
      _stats = stats;
      _isLoading = false;
      _currentIndex = 0;
      _showAnswer = false;
      _sessionStart = DateTime.now();
      _sessionCorrect = 0;
    });
  }

  void _showAnswerCard() {
    setState(() => _showAnswer = true);
  }

  Future<void> _submitReview(ReviewQuality quality) async {
    if (_currentIndex >= _dueItems.length) return;

    final item = _dueItems[_currentIndex];
    await _reviewService.submitReview(item, quality);

    if (quality.index >= 3) {
      _sessionCorrect++;
    }

    setState(() {
      _currentIndex++;
      _showAnswer = false;
    });

    // 모든 복습 완료
    if (_currentIndex >= _dueItems.length) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final duration = DateTime.now().difference(_sessionStart!);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              '복습 완료!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
            ),
            const SizedBox(height: 24),
            _buildStatRow('복습한 구절', '${_dueItems.length}개'),
            _buildStatRow('정답', '$_sessionCorrect개'),
            _buildStatRow(
              '정답률',
              '${(_sessionCorrect / _dueItems.length * 100).toStringAsFixed(0)}%',
            ),
            _buildStatRow(
              '소요 시간',
              '${duration.inMinutes}분 ${duration.inSeconds % 60}초',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: _accentColor),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: ParchmentTheme.fadedScript),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
        ],
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
                        '오늘의 복습',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                    ),
                    if (_dueItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${_currentIndex + 1}/${_dueItems.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: ParchmentTheme.fadedScript,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
              // Body content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _accentColor))
                    : _dueItems.isEmpty
                        ? _buildEmptyState()
                        : _currentIndex >= _dueItems.length
                            ? _buildCompletedState()
                            : _buildReviewCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          EmptyStateWidget.noReviewItems(
            onStartLearning: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildStatsCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          const Text(
            '복습 현황',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('총 구절', '${_stats.totalItems}'),
              _buildMiniStat('마스터', '${_stats.masteredCount}'),
              _buildMiniStat('학습 중', '${_stats.learningCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _accentColor,
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

  Widget _buildCompletedState() {
    return const Center(
      child: Text(
        '모든 복습을 완료했습니다!',
        style: TextStyle(color: ParchmentTheme.ancientInk),
      ),
    );
  }

  Widget _buildReviewCard() {
    final item = _dueItems[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 진행 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _dueItems.length,
              backgroundColor: ParchmentTheme.warmVellum,
              valueColor: const AlwaysStoppedAnimation(_accentColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 24),

          // 레벨 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(item.levelColor).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${item.levelName} • ${item.interval}일 간격',
              style: TextStyle(
                color: Color(item.levelColor),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 구절 참조
          Text(
            item.verseReference,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 32),

          // 카드
          Expanded(
            child: GestureDetector(
              onTap: _showAnswer ? null : _showAnswerCard,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showAnswer
                    ? _buildAnswerSide(item)
                    : _buildQuestionSide(item),
              ),
            ),
          ),

          // 버튼들
          if (_showAnswer) _buildAnswerButtons(),
        ],
      ),
    );
  }

  Widget _buildQuestionSide(ReviewItem item) {
    return Container(
      key: const ValueKey('question'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.help_outline,
            size: 48,
            color: _accentColor,
          ),
          const SizedBox(height: 24),
          const Text(
            '이 구절을 기억하시나요?',
            style: TextStyle(
              fontSize: 18,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '탭하여 답 확인',
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSide(ReviewItem item) {
    return Container(
      key: const ValueKey('answer'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.verseText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                height: 1.6,
                color: ParchmentTheme.ancientInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Text(
            '얼마나 잘 기억했나요?',
            style: TextStyle(
              color: ParchmentTheme.fadedScript,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQualityButton(
                  ReviewQuality.forgot,
                  '다시',
                  ParchmentTheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQualityButton(
                  ReviewQuality.hard,
                  '어려움',
                  ParchmentTheme.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQualityButton(
                  ReviewQuality.normal,
                  '보통',
                  ParchmentTheme.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQualityButton(
                  ReviewQuality.easy,
                  '쉬움',
                  ParchmentTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityButton(
    ReviewQuality quality,
    String label,
    Color color,
  ) {
    return ElevatedButton(
      onPressed: () => _submitReview(quality),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
