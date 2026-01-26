import 'package:flutter/material.dart';
import '../../domain/models/bible/bible_models.dart';
import '../../services/auth_service.dart';
import '../../services/bible_data_service.dart';
import '../../services/progress_service.dart';
import '../../models/verse_progress.dart';
import '../../models/learning_stage.dart';
import '../practice/verse_practice_screen.dart';

/// 구절 로드맵 화면 - Speak 스타일 학습 경로
/// 각 구절을 노드로 표시하고 3단계 학습 진행을 시각화
class VerseRoadmapScreen extends StatefulWidget {
  final AuthService authService;
  final Book book;
  final int chapter;

  const VerseRoadmapScreen({
    super.key,
    required this.authService,
    required this.book,
    required this.chapter,
  });

  @override
  State<VerseRoadmapScreen> createState() => _VerseRoadmapScreenState();
}

class _VerseRoadmapScreenState extends State<VerseRoadmapScreen>
    with SingleTickerProviderStateMixin {
  final ProgressService _progress = ProgressService();
  final BibleDataService _bibleData = BibleDataService.instance;

  Map<int, VerseProgress> _verseProgress = {};
  int _verseCount = 0;
  bool _isLoading = true;
  int? _selectedVerse;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadProgress();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    await _progress.init();

    final verseCount = await _bibleData.getVerseCount(
      widget.book.id,
      widget.chapter,
    );

    final progressMap = <int, VerseProgress>{};
    for (int v = 1; v <= verseCount; v++) {
      progressMap[v] = await _progress.getVerseProgress(
        book: widget.book.id,
        chapter: widget.chapter,
        verse: v,
      );
    }

    if (mounted) {
      setState(() {
        _verseCount = verseCount;
        _verseProgress = progressMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildProgressHeader()),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _verseCount) return null;
                        final verse = index + 1;
                        return Column(
                          children: [
                            _buildVerseNode(verse),
                            if (verse < _verseCount) _buildConnector(verse),
                          ],
                        );
                      },
                      childCount: _verseCount,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
      bottomSheet: _selectedVerse != null ? _buildBottomPanel() : null,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF1a1a2e),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          '${widget.book.nameKo} ${widget.chapter}장',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.indigo.shade800,
                const Color(0xFF1a1a2e),
              ],
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildProgressHeader() {
    final completed = _verseProgress.values.where((p) => p.isCompleted).length;
    final inProgress = _verseProgress.values
        .where((p) => !p.isCompleted && p.stages.isNotEmpty)
        .length;
    final progressRate = _verseCount > 0 ? completed / _verseCount : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.purple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha:0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '학습 진행률',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completed / $_verseCount절 완료',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildCircularProgress(progressRate),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(Icons.check_circle, '$completed', '완료', Colors.green),
              const SizedBox(width: 12),
              _buildStatChip(Icons.play_circle, '$inProgress', '진행중', Colors.blue),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.lock_outline,
                '${_verseCount - completed - inProgress}',
                '미시작',
                Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(double progress) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          Center(
            child: Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseNode(int verse) {
    final progress = _verseProgress[verse] ?? VerseProgress.empty(
      bookId: widget.book.id,
      chapter: widget.chapter,
      verse: verse,
    );

    final isSelected = _selectedVerse == verse;
    final isCompleted = progress.isCompleted;
    final isInProgress = !isCompleted && progress.stages.isNotEmpty;

    // 이전 구절이 완료되지 않으면 잠금 (첫 번째 구절 제외)
    final prevProgress = verse > 1 ? _verseProgress[verse - 1] : null;
    final shouldLock = verse > 1 &&
        prevProgress != null &&
        !prevProgress.isCompleted &&
        progress.stages.isEmpty;

    Color nodeColor;
    IconData nodeIcon;

    if (isCompleted) {
      nodeColor = Colors.green;
      nodeIcon = Icons.star;
    } else if (isInProgress) {
      nodeColor = Colors.blue;
      nodeIcon = Icons.play_arrow;
    } else if (shouldLock) {
      nodeColor = Colors.grey.shade700;
      nodeIcon = Icons.lock;
    } else {
      nodeColor = Colors.grey;
      nodeIcon = Icons.circle_outlined;
    }

    // 현재 진행 중인 노드는 펄스 애니메이션
    final shouldPulse = isInProgress || (!shouldLock && !isCompleted && verse == 1);

    return GestureDetector(
      onTap: shouldLock ? null : () {
        setState(() {
          _selectedVerse = isSelected ? null : verse;
        });
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = shouldPulse ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: isSelected ? 1.1 : scale,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // 왼쪽: 구절 번호 노드
              _buildNodeCircle(verse, nodeColor, nodeIcon, isSelected, shouldLock),
              const SizedBox(width: 16),
              // 오른쪽: 3단계 진행 표시
              Expanded(
                child: _buildStageIndicators(progress, shouldLock),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeCircle(
    int verse,
    Color color,
    IconData icon,
    bool isSelected,
    bool isLocked,
  ) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLocked ? Colors.grey.shade800 : color.withValues(alpha:0.2),
        border: Border.all(
          color: isLocked ? Colors.grey.shade700 : color,
          width: isSelected ? 4 : 3,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha:0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: isLocked ? Colors.grey.shade600 : color, size: 28),
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey.shade800 : color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$verse',
                style: TextStyle(
                  color: isLocked ? Colors.grey.shade600 : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageIndicators(VerseProgress progress, bool isLocked) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLocked
            ? Colors.grey.shade900.withValues(alpha:0.5)
            : Colors.white.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked
              ? Colors.grey.shade800
              : Colors.white.withValues(alpha:0.1),
        ),
      ),
      child: Row(
        children: LearningStage.values.map((stage) {
          final stageProgress = progress.stages[stage];
          final isCurrent = progress.currentStage == stage && !progress.isCompleted;
          final isPassed = stageProgress != null && stage.isPassed(stageProgress.bestScore);
          final hasAttempt = stageProgress != null && stageProgress.attempts > 0;

          return Expanded(
            child: _buildStageChip(
              stage: stage,
              isPassed: isPassed,
              isCurrent: isCurrent,
              hasAttempt: hasAttempt,
              score: stageProgress?.bestScore,
              isLocked: isLocked,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStageChip({
    required LearningStage stage,
    required bool isPassed,
    required bool isCurrent,
    required bool hasAttempt,
    double? score,
    required bool isLocked,
  }) {
    Color bgColor;
    Color textColor;
    IconData icon;

    if (isLocked) {
      bgColor = Colors.grey.shade800;
      textColor = Colors.grey.shade600;
      icon = Icons.lock_outline;
    } else if (isPassed) {
      bgColor = Colors.green.withValues(alpha:0.3);
      textColor = Colors.green;
      icon = Icons.check;
    } else if (isCurrent) {
      bgColor = Colors.amber.withValues(alpha:0.3);
      textColor = Colors.amber;
      icon = Icons.play_arrow;
    } else if (hasAttempt) {
      bgColor = Colors.orange.withValues(alpha:0.2);
      textColor = Colors.orange;
      icon = Icons.refresh;
    } else {
      bgColor = Colors.grey.withValues(alpha:0.2);
      textColor = Colors.grey;
      icon = Icons.circle_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isCurrent ? Border.all(color: textColor, width: 2) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(height: 2),
          Text(
            'S${stage.stageNumber}',
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (score != null && !isLocked)
            Text(
              '${score.toInt()}%',
              style: TextStyle(
                color: textColor.withValues(alpha:0.8),
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnector(int fromVerse) {
    final fromProgress = _verseProgress[fromVerse];
    final isCompleted = fromProgress?.isCompleted ?? false;

    Color lineColor;
    if (isCompleted) {
      lineColor = Colors.green;
    } else if (fromProgress?.stages.isNotEmpty ?? false) {
      lineColor = Colors.blue;
    } else {
      lineColor = Colors.grey.shade700;
    }

    return Container(
      height: 30,
      width: 60,
      alignment: Alignment.centerLeft,
      child: Container(
        width: 4,
        margin: const EdgeInsets.only(left: 28),
        decoration: BoxDecoration(
          color: lineColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final verse = _selectedVerse!;
    final progress = _verseProgress[verse]!;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF2a2a4e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // 구절 정보
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getStageColor(progress).withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$verse',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _getStageColor(progress),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.book.nameKo} ${widget.chapter}:$verse',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.isCompleted
                          ? '암송 완료!'
                          : '현재 단계: ${progress.currentStage.koreanName}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress.overallBestScore > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${progress.overallBestScore.toInt()}%',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // 3단계 진행 상세
          _buildStageDetailRow(progress),
          const SizedBox(height: 20),
          // 학습 시작 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startPractice(verse),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getStageColor(progress),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    progress.isCompleted
                        ? Icons.replay
                        : Icons.play_arrow,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    progress.isCompleted
                        ? '다시 연습하기'
                        : progress.stages.isEmpty
                            ? '학습 시작'
                            : '이어서 학습',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageDetailRow(VerseProgress progress) {
    return Row(
      children: LearningStage.values.map((stage) {
        final stageProgress = progress.stages[stage];
        final isCurrent = progress.currentStage == stage && !progress.isCompleted;
        final isPassed = stageProgress != null && stage.isPassed(stageProgress.bestScore);

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrent
                  ? Colors.amber.withValues(alpha:0.2)
                  : isPassed
                      ? Colors.green.withValues(alpha:0.2)
                      : Colors.grey.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent
                    ? Colors.amber
                    : isPassed
                        ? Colors.green
                        : Colors.grey.shade700,
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isPassed
                      ? Icons.check_circle
                      : isCurrent
                          ? Icons.play_circle
                          : Icons.circle_outlined,
                  color: isCurrent
                      ? Colors.amber
                      : isPassed
                          ? Colors.green
                          : Colors.grey,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  stage.koreanName,
                  style: TextStyle(
                    color: isCurrent || isPassed ? Colors.white : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  stageProgress != null
                      ? '${stageProgress.bestScore.toInt()}%'
                      : '-',
                  style: TextStyle(
                    color: isPassed ? Colors.green : Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getStageColor(VerseProgress progress) {
    if (progress.isCompleted) return Colors.green;
    if (progress.stages.isNotEmpty) return Colors.blue;
    return Colors.amber;
  }

  void _startPractice(int verse) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VersePracticeScreen(
          authService: widget.authService,
          book: widget.book.id,
          chapter: widget.chapter,
          initialVerse: verse,
        ),
      ),
    ).then((_) {
      _loadProgress();
      setState(() => _selectedVerse = null);
    });
  }
}

/// 애니메이션 빌더 위젯
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder2({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
