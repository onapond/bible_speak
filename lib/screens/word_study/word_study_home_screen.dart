import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/word_service.dart';
import '../../services/word_progress_service.dart';
import '../../services/daily_goal_service.dart';
import '../../models/daily_goal.dart';
import '../../data/bible_data.dart';
import '../../styles/parchment_theme.dart';
import '../../widgets/word_study/daily_goal_card.dart';
import 'word_list_screen.dart';
import 'flashcard_screen.dart';

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
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;
  static const _successColor = ParchmentTheme.success;

  final WordService _wordService = WordService();
  final WordProgressService _progressService = WordProgressService();

  String _selectedBook = 'malachi';
  int _selectedChapter = 1;
  WordStudyStats? _stats;
  int _todayReviewCount = 0;

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

    // 전체 단어에서 오늘 복습할 단어 수 계산
    final allWords = _wordService.getAllWords();
    final allWordIds = allWords.map((w) => w.id).toList();
    final todayReview = await _progressService.getTodayReviewWords(allWordIds);

    if (mounted) {
      setState(() {
        _stats = stats;
        _todayReviewCount = todayReview.length;
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
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ParchmentTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
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
                        '단어 공부',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 헤더 카드
                      _buildHeaderCard(),
                      const SizedBox(height: 20),

                      // 일일 학습 목표 카드
                      DailyGoalCard(
                        onSettingsTap: _showGoalSettingsDialog,
                      ),
                      const SizedBox(height: 20),

                      // 오늘의 복습 카드 (SRS)
                      if (_todayReviewCount > 0) ...[
                        _buildTodayReviewCard(),
                        const SizedBox(height: 20),
                      ],

                      // 선택 카드
                      _buildSelectionCard(book, chaptersWithWords),
                      const SizedBox(height: 20),

                      // 진행률 카드
                      if (_stats != null && hasWords) _buildProgressCard(),
                      const SizedBox(height: 20),

                      // 시작 버튼
                      _buildStartButton(hasWords),
                      const SizedBox(height: 20),
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

  void _startTodayReview() async {
    final allWords = _wordService.getAllWords();
    final allWordIds = allWords.map((w) => w.id).toList();
    final todayReviewIds = await _progressService.getTodayReviewWords(allWordIds);

    if (todayReviewIds.isEmpty) return;

    // 복습할 단어들 필터링
    final reviewWords = allWords.where((w) => todayReviewIds.contains(w.id)).toList();

    if (mounted && reviewWords.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlashcardScreen(
            words: reviewWords,
            bookName: '오늘의 복습',
            chapter: 0,
          ),
        ),
      ).then((_) => _loadStats());
    }
  }

  void _showGoalSettingsDialog() {
    final goalService = DailyGoalService();
    goalService.init().then((_) {
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _GoalSettingsSheet(
          currentPreset: goalService.currentPreset,
          onPresetSelected: (preset) async {
            await goalService.setPreset(preset);
            if (mounted) setState(() {});
          },
        ),
      );
    });
  }

  Widget _buildTodayReviewCard() {
    return GestureDetector(
      onTap: _startTodayReview,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
          boxShadow: ParchmentTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '오늘의 복습',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ParchmentTheme.ancientInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_todayReviewCount개의 단어가 복습을 기다리고 있어요!',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ParchmentTheme.fadedScript,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: ParchmentTheme.weatheredGray,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.abc,
              size: 48,
              color: ParchmentTheme.softPapyrus,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '성경 영단어 학습',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '암송 전에 핵심 단어를 익혀보세요',
            style: TextStyle(
              fontSize: 14,
              color: ParchmentTheme.fadedScript,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(BibleBook? book, List<int> chaptersWithWords) {
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
            '학습할 범위 선택',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 16),

          // 책 선택
          Row(
            children: [
              const Icon(Icons.menu_book, color: _accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBook,
                  dropdownColor: _cardColor,
                  style: const TextStyle(color: ParchmentTheme.ancientInk),
                  decoration: InputDecoration(
                    labelText: '성경',
                    labelStyle: const TextStyle(color: ParchmentTheme.fadedScript),
                    filled: true,
                    fillColor: ParchmentTheme.warmVellum.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accentColor),
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
              const Icon(Icons.format_list_numbered, color: _accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedChapter,
                  dropdownColor: _cardColor,
                  style: const TextStyle(color: ParchmentTheme.ancientInk),
                  decoration: InputDecoration(
                    labelText: '장',
                    labelStyle: const TextStyle(color: ParchmentTheme.fadedScript),
                    filled: true,
                    fillColor: ParchmentTheme.warmVellum.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accentColor),
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
                                color: ParchmentTheme.warmVellum,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '준비중',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ParchmentTheme.weatheredGray,
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
    );
  }

  Widget _buildProgressCard() {
    final stats = _stats!;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '학습 진행률',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _successColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${stats.mastered} / ${stats.total}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _successColor,
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
              backgroundColor: ParchmentTheme.warmVellum,
              valueColor: AlwaysStoppedAnimation<Color>(
                stats.progressPercent >= 1.0 ? _accentColor : _successColor,
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
                ParchmentTheme.weatheredGray,
              ),
              _buildStatItem(
                '학습중',
                stats.learning,
                ParchmentTheme.warning,
              ),
              _buildStatItem(
                '암기완료',
                stats.mastered,
                _successColor,
              ),
            ],
          ),
        ],
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
            color: color.withValues(alpha: 0.15),
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
          style: const TextStyle(
            fontSize: 12,
            color: ParchmentTheme.fadedScript,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(bool hasWords) {
    return Container(
      width: double.infinity,
      decoration: hasWords
          ? BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ParchmentTheme.buttonShadow,
            )
          : null,
      child: ElevatedButton(
        onPressed: hasWords ? _navigateToWordList : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasWords ? Colors.transparent : ParchmentTheme.warmVellum,
          shadowColor: Colors.transparent,
          foregroundColor: hasWords ? ParchmentTheme.softPapyrus : ParchmentTheme.weatheredGray,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
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

/// 목표 설정 바텀시트
class _GoalSettingsSheet extends StatelessWidget {
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final DailyGoalPreset currentPreset;
  final Function(DailyGoalPreset) onPresetSelected;

  const _GoalSettingsSheet({
    required this.currentPreset,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                color: ParchmentTheme.warmVellum,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '일일 학습 목표 설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.ancientInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '목표를 달성하면 +3 달란트 보너스!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 24),
            ...DailyGoalPreset.values
                .where((p) => p != DailyGoalPreset.custom)
                .map((preset) => _buildPresetOption(context, preset)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetOption(BuildContext context, DailyGoalPreset preset) {
    final isSelected = preset == currentPreset;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: isSelected
            ? _accentColor.withValues(alpha: 0.1)
            : ParchmentTheme.warmVellum.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            onPresetSelected(preset);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: _accentColor, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _accentColor
                        : ParchmentTheme.warmVellum,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.flag,
                    color: isSelected
                        ? ParchmentTheme.softPapyrus
                        : ParchmentTheme.weatheredGray,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? _accentColor : ParchmentTheme.ancientInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ParchmentTheme.fadedScript,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
