import 'package:flutter/material.dart';
import '../../domain/models/bible/bible_models.dart';
import '../../services/auth_service.dart';
import '../../services/bible_data_service.dart';
import '../../services/progress_service.dart';
import '../../models/verse_progress.dart';
import '../practice/verse_practice_screen.dart';

/// 장 선택 화면 - Speak 스타일 로드맵 UI
class ChapterSelectionScreen extends StatefulWidget {
  final AuthService authService;
  final Book book;

  const ChapterSelectionScreen({
    super.key,
    required this.authService,
    required this.book,
  });

  @override
  State<ChapterSelectionScreen> createState() => _ChapterSelectionScreenState();
}

class _ChapterSelectionScreenState extends State<ChapterSelectionScreen> {
  final ProgressService _progress = ProgressService();
  final BibleDataService _bibleData = BibleDataService.instance;
  Map<int, ChapterProgress> _chapterProgress = {};
  Map<int, int> _verseCountCache = {}; // Cache verse counts
  bool _isLoading = true;
  int? _selectedChapter;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    await _progress.init();

    final progressMap = <int, ChapterProgress>{};
    final verseCountMap = <int, int>{};

    for (int ch = 1; ch <= widget.book.chapterCount; ch++) {
      final verseCount = await _bibleData.getVerseCount(widget.book.id, ch);
      verseCountMap[ch] = verseCount;
      progressMap[ch] = await _progress.getChapterProgress(
        book: widget.book.id,
        chapter: ch,
        totalVerses: verseCount,
      );
    }

    if (mounted) {
      setState(() {
        _chapterProgress = progressMap;
        _verseCountCache = verseCountMap;
        _isLoading = false;
      });
    }
  }

  int _getVerseCount(int chapter) {
    return _verseCountCache[chapter] ?? 0;
  }

  ChapterStatus _getChapterStatus(int chapter) {
    final progress = _chapterProgress[chapter];
    if (progress == null) return ChapterStatus.notStarted;

    // 이전 챕터가 완료되지 않으면 잠금
    if (chapter > 1) {
      final prevProgress = _chapterProgress[chapter - 1];
      if (prevProgress == null || prevProgress.status != ChapterStatus.completed) {
        // 단, 현재 챕터에서 학습 시작한 경우는 잠금 해제
        if (progress.status == ChapterStatus.notStarted) {
          return ChapterStatus.notStarted; // 잠금 처리하지 않고 그냥 미시작으로
        }
      }
    }

    return progress.status;
  }

  @override
  Widget build(BuildContext context) {
    final totalProgress = _calculateTotalProgress();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.book.nameKo),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (totalProgress > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${(totalProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 전체 진행률 바
                _buildOverallProgress(),
                // 로드맵
                Expanded(child: _buildRoadmap()),
                // 선택된 챕터 정보 패널
                if (_selectedChapter != null) _buildChapterDetailPanel(),
              ],
            ),
    );
  }

  double _calculateTotalProgress() {
    if (_chapterProgress.isEmpty) return 0;
    int totalCompleted = 0;
    int totalVerses = 0;
    for (int ch = 1; ch <= widget.book.chapterCount; ch++) {
      final progress = _chapterProgress[ch];
      if (progress != null) {
        totalCompleted += progress.completedVerses;
        totalVerses += progress.totalVerses;
      }
    }
    return totalVerses > 0 ? totalCompleted / totalVerses : 0;
  }

  Widget _buildOverallProgress() {
    final totalProgress = _calculateTotalProgress();
    final completedChapters = _chapterProgress.values
        .where((p) => p.status == ChapterStatus.completed)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade400],
        ),
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$completedChapters / ${widget.book.chapterCount}장 완료',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Text(
                    '${(totalProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalProgress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmap() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < widget.book.chapterCount; i++) ...[
            _buildRoadmapNode(i + 1, i.isEven),
            if (i < widget.book.chapterCount - 1) _buildRoadmapConnector(i + 1, i.isEven),
          ],
        ],
      ),
    );
  }

  Widget _buildRoadmapNode(int chapter, bool isLeft) {
    final progress = _chapterProgress[chapter];
    final status = _getChapterStatus(chapter);
    final isSelected = _selectedChapter == chapter;
    final verseCount = _getVerseCount(chapter);

    Color nodeColor;
    IconData nodeIcon;

    switch (status) {
      case ChapterStatus.completed:
        nodeColor = Colors.green;
        nodeIcon = Icons.check_circle;
        break;
      case ChapterStatus.inProgress:
        nodeColor = Colors.blue;
        nodeIcon = Icons.play_circle;
        break;
      case ChapterStatus.notStarted:
        nodeColor = Colors.grey;
        nodeIcon = Icons.circle_outlined;
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChapter = _selectedChapter == chapter ? null : chapter;
        });
      },
      child: Row(
        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isLeft) const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 160 : 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? nodeColor.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: nodeColor,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: nodeColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: [
                // 상태 아이콘
                Icon(nodeIcon, color: nodeColor, size: 32),
                const SizedBox(height: 8),
                // 장 번호
                Text(
                  '$chapter장',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: nodeColor,
                  ),
                ),
                // 절 수
                Text(
                  '$verseCount절',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                // 진행률 표시
                if (progress != null && progress.progressPercent > 0)
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.progressRate,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(nodeColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${progress.progressPercent}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: nodeColor,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    status == ChapterStatus.notStarted ? '미시작' : '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          if (isLeft) const Spacer(),
        ],
      ),
    );
  }

  Widget _buildRoadmapConnector(int fromChapter, bool fromIsLeft) {
    final fromStatus = _getChapterStatus(fromChapter);
    final toStatus = _getChapterStatus(fromChapter + 1);

    Color lineColor;
    if (fromStatus == ChapterStatus.completed) {
      lineColor = Colors.green;
    } else if (fromStatus == ChapterStatus.inProgress) {
      lineColor = Colors.blue;
    } else {
      lineColor = Colors.grey.shade300;
    }

    return SizedBox(
      height: 40,
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: _ConnectorPainter(
          fromLeft: fromIsLeft,
          color: lineColor,
          isDashed: toStatus == ChapterStatus.notStarted,
        ),
      ),
    );
  }

  Widget _buildChapterDetailPanel() {
    final chapter = _selectedChapter!;
    final progress = _chapterProgress[chapter];
    final verseCount = _getVerseCount(chapter);
    final status = _getChapterStatus(chapter);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
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
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 챕터 정보
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '$chapter',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
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
                      '${widget.book.nameKo} $chapter장',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$verseCount절 | ${progress?.completedVerses ?? 0}절 완료',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 20),
          // 구절별 진행 상태 미리보기
          if (progress != null && progress.progressPercent > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '학습 진행 상태',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.progressRate,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(status)),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${progress.completedVerses}절 완료',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                    ),
                    Text(
                      '${progress.inProgressVerses}절 진행중',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                    ),
                    Text(
                      '${verseCount - progress.completedVerses - progress.inProgressVerses}절 미시작',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          // 학습 시작 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToPractice(chapter),
              icon: Icon(
                status == ChapterStatus.notStarted
                    ? Icons.play_arrow
                    : Icons.play_circle,
              ),
              label: Text(
                status == ChapterStatus.notStarted ? '학습 시작' : '이어서 학습',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getStatusColor(status),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ChapterStatus status) {
    String text;
    Color color;

    switch (status) {
      case ChapterStatus.completed:
        text = '완료';
        color = Colors.green;
        break;
      case ChapterStatus.inProgress:
        text = '진행중';
        color = Colors.blue;
        break;
      case ChapterStatus.notStarted:
        text = '미시작';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(ChapterStatus status) {
    switch (status) {
      case ChapterStatus.completed:
        return Colors.green;
      case ChapterStatus.inProgress:
        return Colors.blue;
      case ChapterStatus.notStarted:
        return Colors.grey;
    }
  }

  void _navigateToPractice(int chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VersePracticeScreen(
          authService: widget.authService,
          book: widget.book.id,
          chapter: chapter,
        ),
      ),
    ).then((_) {
      _loadProgress();
      setState(() => _selectedChapter = null);
    });
  }
}

/// 로드맵 연결선 페인터
class _ConnectorPainter extends CustomPainter {
  final bool fromLeft;
  final Color color;
  final bool isDashed;

  _ConnectorPainter({
    required this.fromLeft,
    required this.color,
    this.isDashed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();

    // 시작점과 끝점 계산
    final startX = fromLeft ? size.width * 0.3 : size.width * 0.7;
    final endX = fromLeft ? size.width * 0.7 : size.width * 0.3;
    const startY = 0.0;
    final endY = size.height;

    // 곡선 경로 생성
    path.moveTo(startX, startY);
    path.cubicTo(
      startX, size.height * 0.5, // 첫 번째 제어점
      endX, size.height * 0.5, // 두 번째 제어점
      endX, endY, // 끝점
    );

    if (isDashed) {
      // 점선으로 그리기
      final dashPath = _createDashedPath(path, 8, 4);
      canvas.drawPath(dashPath, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  Path _createDashedPath(Path source, double dashWidth, double dashGap) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = dashWidth;
        result.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashWidth + dashGap;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
