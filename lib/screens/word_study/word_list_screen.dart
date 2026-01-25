import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../models/word_progress.dart';
import '../../services/auth_service.dart';
import '../../services/word_service.dart';
import '../../services/word_progress_service.dart';
import '../../services/tts_service.dart';
import '../../data/bible_data.dart';
import 'word_detail_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

/// 단어 목록 화면
class WordListScreen extends StatefulWidget {
  final AuthService authService;
  final String bookId;
  final int chapter;

  const WordListScreen({
    super.key,
    required this.authService,
    required this.bookId,
    required this.chapter,
  });

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final WordService _wordService = WordService();
  final WordProgressService _progressService = WordProgressService();
  final TTSService _tts = TTSService();

  List<BibleWord> _words = [];
  Map<String, WordProgress> _progressMap = {};
  bool _isLoading = true;
  String? _playingWordId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _progressService.init();
    final words = _wordService.getChapterWords(widget.bookId, widget.chapter);
    final wordIds = words.map((w) => w.id).toList();
    final progressMap = await _progressService.getProgressBatch(wordIds);

    if (mounted) {
      setState(() {
        _words = words;
        _progressMap = progressMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _playWord(BibleWord word) async {
    if (_playingWordId == word.id) {
      await _tts.stop();
      setState(() => _playingWordId = null);
      return;
    }

    setState(() => _playingWordId = word.id);

    try {
      // TTS로 단어 발음 (단어만 발음)
      await _tts.speakText(word.word);
    } catch (e) {
      _showSnackBar('발음 재생 실패: $e', isError: true);
    }

    if (mounted) {
      setState(() => _playingWordId = null);
    }
  }

  void _navigateToDetail(BibleWord word) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordDetailScreen(
          word: word,
          progress: _progressMap[word.id],
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  void _navigateToFlashcard() {
    if (_words.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardScreen(
          words: _words,
          bookName: BibleData.getBookName(widget.bookId),
          chapter: widget.chapter,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToQuiz() {
    if (_words.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          words: _words,
          bookName: BibleData.getBookName(widget.bookId),
          chapter: widget.chapter,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final bookName = BibleData.getBookName(widget.bookId);
    final stats = _calculateStats();

    return Scaffold(
      appBar: AppBar(
        title: Text('$bookName ${widget.chapter}장 단어'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 진행률 헤더
          _buildProgressHeader(stats),

          // 단어 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _words.isEmpty
                    ? const Center(child: Text('단어 데이터가 없습니다.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _words.length,
                        itemBuilder: (context, index) {
                          final word = _words[index];
                          final progress = _progressMap[word.id];
                          return _buildWordCard(word, progress);
                        },
                      ),
          ),

          // 하단 학습 버튼
          if (!_isLoading && _words.isNotEmpty) _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToFlashcard,
                icon: const Icon(Icons.style),
                label: const Text('플래시카드'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToQuiz,
                icon: const Icon(Icons.quiz),
                label: const Text('퀴즈'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  WordStudyStats _calculateStats() {
    int mastered = 0;
    int learning = 0;
    int notStarted = 0;

    for (final word in _words) {
      final progress = _progressMap[word.id];
      if (progress == null || progress.status == WordStatus.notStarted) {
        notStarted++;
      } else if (progress.status == WordStatus.mastered) {
        mastered++;
      } else {
        learning++;
      }
    }

    return WordStudyStats(
      total: _words.length,
      notStarted: notStarted,
      learning: learning,
      mastered: mastered,
    );
  }

  Widget _buildProgressHeader(WordStudyStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade500],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '학습 진행률',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${stats.mastered} / ${stats.total} 단어 암기',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.progressPercent,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                stats.progressPercent >= 1.0
                    ? Colors.amber
                    : Colors.greenAccent,
              ),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(BibleWord word, WordProgress? progress) {
    final status = progress?.status ?? WordStatus.notStarted;
    final isPlaying = _playingWordId == word.id;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case WordStatus.mastered:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = '암기완료';
        break;
      case WordStatus.learning:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = '학습중';
        break;
      case WordStatus.notStarted:
        statusColor = Colors.grey;
        statusIcon = Icons.circle_outlined;
        statusText = '미학습';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: status == WordStatus.mastered
            ? BorderSide(color: Colors.green.shade200, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(word),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 상태 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 16),

              // 단어 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          word.word,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                          child: Text(
                            word.partOfSpeechKo,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.allMeanings,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (progress != null && progress.totalAttempts > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$statusText (${progress.correctCount}/${progress.totalAttempts})',
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 발음 버튼
              IconButton(
                onPressed: () => _playWord(word),
                icon: isPlaying
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.volume_up,
                        color: Colors.green.shade600,
                      ),
                tooltip: '발음 듣기',
              ),

              // 화살표
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
