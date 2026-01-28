import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../models/word_progress.dart';
import '../../models/quiz_type.dart';
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
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);
  static const _successColor = Color(0xFF4CAF50);

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
    _showQuizTypeSelector();
  }

  void _showQuizTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '퀴즈 유형 선택',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '원하는 퀴즈 유형을 선택하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              ...QuizType.values.map((type) => _buildQuizTypeOption(type)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizTypeOption(QuizType type) {
    final isAvailable = type.isAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: isAvailable ? _accentColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isAvailable
              ? () {
                  Navigator.pop(context);
                  _startQuiz(type);
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  type.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isAvailable
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '준비중',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: _accentColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startQuiz(QuizType quizType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          words: _words,
          bookName: BibleData.getBookName(widget.bookId),
          chapter: widget.chapter,
          quizType: quizType,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final bookName = BibleData.getBookName(widget.bookId);
    final stats = _calculateStats();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text('$bookName ${widget.chapter}장 단어'),
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 진행률 헤더
          _buildProgressHeader(stats),

          // 단어 목록
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _accentColor))
                : _words.isEmpty
                    ? Center(
                        child: Text(
                          '단어 데이터가 없습니다.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      )
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
        color: _cardColor,
        border: Border(
          top: BorderSide(color: _accentColor.withValues(alpha: 0.2)),
        ),
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
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
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
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
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
        color: _cardColor,
        border: Border(
          bottom: BorderSide(color: _accentColor.withValues(alpha: 0.2)),
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
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
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
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                stats.progressPercent >= 1.0 ? Colors.amber : _successColor,
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
        statusColor = _successColor;
        statusIcon = Icons.check_circle;
        statusText = '암기완료';
        break;
      case WordStatus.reviewing:
        statusColor = Colors.blue;
        statusIcon = Icons.replay;
        statusText = '복습중';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: status == WordStatus.mastered
            ? Border.all(color: _successColor.withValues(alpha: 0.5), width: 2)
            : null,
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
                  color: statusColor.withValues(alpha: 0.2),
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            word.partOfSpeechKo,
                            style: TextStyle(
                              fontSize: 10,
                              color: _accentColor,
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
                        color: Colors.white.withValues(alpha: 0.7),
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
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accentColor,
                        ),
                      )
                    : Icon(
                        Icons.volume_up,
                        color: _accentColor,
                      ),
                tooltip: '발음 듣기',
              ),

              // 화살표
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
