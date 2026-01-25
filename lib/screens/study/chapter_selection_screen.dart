import 'package:flutter/material.dart';
import '../../data/bible_data.dart';
import '../../services/auth_service.dart';
import '../../services/progress_service.dart';
import '../practice/verse_practice_screen.dart';

/// 장 선택 화면
class ChapterSelectionScreen extends StatefulWidget {
  final AuthService authService;
  final BibleBook book;

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
  Map<int, double> _chapterProgress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    await _progress.init();

    final progress = <int, double>{};
    for (int ch = 1; ch <= widget.book.chapters; ch++) {
      final verseCount = BibleData.getVerseCount(widget.book.id, ch);
      int masteredCount = 0;

      for (int v = 1; v <= verseCount; v++) {
        final score = await _progress.getScore(
          book: widget.book.id,
          chapter: ch,
          verse: v,
        );
        if (score >= ProgressService.masteryThreshold) {
          masteredCount++;
        }
      }

      progress[ch] = masteredCount / verseCount;
    }

    if (mounted) {
      setState(() {
        _chapterProgress = progress;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.book.nameKo} - 장 선택'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: widget.book.chapters,
              itemBuilder: (context, index) {
                final chapter = index + 1;
                return _buildChapterCard(chapter);
              },
            ),
    );
  }

  Widget _buildChapterCard(int chapter) {
    final progress = _chapterProgress[chapter] ?? 0.0;
    final isCompleted = progress >= 1.0;
    final verseCount = BibleData.getVerseCount(widget.book.id, chapter);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCompleted
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _navigateToPractice(chapter),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isCompleted
                ? LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 완료 표시
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.green, size: 24)
              else
                const SizedBox(height: 24),

              // 장 번호
              Text(
                '$chapter장',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green.shade700 : Colors.indigo,
                ),
              ),

              const SizedBox(height: 4),

              // 절 수
              Text(
                '$verseCount절',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 8),

              // 진행률 바
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.green : Colors.indigo,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // 진행률 텍스트
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    ).then((_) => _loadProgress()); // 돌아올 때 진행률 새로고침
  }
}
