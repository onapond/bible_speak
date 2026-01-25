import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/word_service.dart';
import '../../services/word_progress_service.dart';
import '../../data/bible_data.dart';
import 'word_list_screen.dart';

/// 단어 공부 홈 화면
/// - 책/장 선택
/// - 학습 진행률 표시
class WordStudyHomeScreen extends StatefulWidget {
  final AuthService authService;

  const WordStudyHomeScreen({
    super.key,
    required this.authService,
  });

  @override
  State<WordStudyHomeScreen> createState() => _WordStudyHomeScreenState();
}

class _WordStudyHomeScreenState extends State<WordStudyHomeScreen> {
  final WordService _wordService = WordService();
  final WordProgressService _progressService = WordProgressService();

  String _selectedBook = 'malachi';
  int _selectedChapter = 1;
  WordStudyStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await _progressService.init();
    final words = _wordService.getChapterWords(_selectedBook, _selectedChapter);
    final wordIds = words.map((w) => w.id).toList();
    final stats = await _progressService.getChapterStats(wordIds);

    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  void _onBookChanged(String? bookId) {
    if (bookId != null && bookId != _selectedBook) {
      setState(() {
        _selectedBook = bookId;
        _selectedChapter = 1;
      });
      _loadStats();
    }
  }

  void _onChapterChanged(int? chapter) {
    if (chapter != null && chapter != _selectedChapter) {
      setState(() => _selectedChapter = chapter);
      _loadStats();
    }
  }

  void _navigateToWordList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordListScreen(
          authService: widget.authService,
          bookId: _selectedBook,
          chapter: _selectedChapter,
        ),
      ),
    ).then((_) => _loadStats()); // 돌아왔을 때 통계 새로고침
  }

  @override
  Widget build(BuildContext context) {
    final book = BibleData.getBook(_selectedBook);
    final chaptersWithWords = _wordService.getChaptersWithWords(_selectedBook);
    final hasWords = chaptersWithWords.contains(_selectedChapter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('단어 공부'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade600, Colors.green.shade400],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    kToolbarHeight -
                    40, // padding
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      // 헤더 카드
                      _buildHeaderCard(),
                      const SizedBox(height: 20),

                      // 선택 카드
                      _buildSelectionCard(book, chaptersWithWords),
                      const SizedBox(height: 20),

                      // 진행률 카드
                      if (_stats != null && hasWords) _buildProgressCard(),
                    ],
                  ),

                  // 시작 버튼
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildStartButton(hasWords),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.abc,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '성경 영단어 학습',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '암송 전에 핵심 단어를 익혀보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(BibleBook? book, List<int> chaptersWithWords) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '학습할 범위 선택',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 책 선택
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBook,
                    decoration: InputDecoration(
                      labelText: '성경',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: _wordService.supportedBooks.map((bookId) {
                      final b = BibleData.getBook(bookId);
                      return DropdownMenuItem(
                        value: bookId,
                        child: Text(b?.nameKo ?? bookId),
                      );
                    }).toList(),
                    onChanged: _onBookChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 장 선택
            Row(
              children: [
                const Icon(Icons.format_list_numbered, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedChapter,
                    decoration: InputDecoration(
                      labelText: '장',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: List.generate(book?.chapters ?? 1, (i) => i + 1)
                        .map((ch) {
                      final hasData = chaptersWithWords.contains(ch);
                      return DropdownMenuItem(
                        value: ch,
                        child: Row(
                          children: [
                            Text('$ch장'),
                            if (!hasData) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '준비중',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _onChapterChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final stats = _stats!;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '학습 진행률',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${stats.mastered} / ${stats.total}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 진행률 바
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stats.progressPercent,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  stats.progressPercent >= 1.0
                      ? Colors.amber
                      : Colors.green.shade600,
                ),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 16),

            // 상태별 카운트
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '미학습',
                  stats.notStarted,
                  Colors.grey,
                ),
                _buildStatItem(
                  '학습중',
                  stats.learning,
                  Colors.orange,
                ),
                _buildStatItem(
                  '암기완료',
                  stats.mastered,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(bool hasWords) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasWords ? _navigateToWordList : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.green.shade700,
          disabledBackgroundColor: Colors.white.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasWords ? Icons.play_arrow : Icons.hourglass_empty),
            const SizedBox(width: 8),
            Text(
              hasWords ? '단어 학습 시작' : '단어 데이터 준비중',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
