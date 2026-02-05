import 'package:flutter/material.dart';
import '../../domain/models/bible/bible_models.dart';
import '../../models/review_item.dart';
import '../../models/daily_quiz.dart';
import '../../services/auth_service.dart';
import '../../services/bible_data_service.dart';
import '../../services/progress_service.dart';
import '../../services/review_service.dart';
import '../../services/daily_quiz_service.dart';
import '../../models/verse_progress.dart';
import '../../styles/parchment_theme.dart';
import '../practice/verse_practice_redesigned.dart';
import '../../widgets/common/animated_counter.dart';

/// 학습센터 통합 화면
/// - 암송 연습, 복습, 퀴즈를 하나의 탭 화면으로 통합
class LearningCenterScreen extends StatefulWidget {
  final AuthService authService;
  final int initialTabIndex;

  const LearningCenterScreen({
    super.key,
    required this.authService,
    this.initialTabIndex = 0,
  });

  @override
  State<LearningCenterScreen> createState() => _LearningCenterScreenState();
}

class _LearningCenterScreenState extends State<LearningCenterScreen>
    with SingleTickerProviderStateMixin {
  // Parchment Theme 색상
  static const _bgColor = ParchmentTheme.agedParchment;
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  late TabController _tabController;

  // 서비스
  final ReviewService _reviewService = ReviewService();
  final DailyQuizService _quizService = DailyQuizService();

  // 요약 통계
  int _dueReviewCount = 0;
  bool _hasQuizToday = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadSummaryStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSummaryStats() async {
    final dueItems = await _reviewService.getDueItems();
    final hasCompleted = await _quizService.hasCompletedToday();

    if (mounted) {
      setState(() {
        _dueReviewCount = dueItems.length;
        _hasQuizToday = !hasCompleted;
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
        child: Column(
          children: [
            // 커스텀 AppBar
            SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          color: ParchmentTheme.ancientInk,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            '학습센터',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ParchmentTheme.ancientInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // TabBar
                    Container(
                      decoration: BoxDecoration(
                        color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: _accentColor,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelColor: ParchmentTheme.ancientInk,
                        unselectedLabelColor: ParchmentTheme.weatheredGray,
                        dividerColor: Colors.transparent,
                        tabs: [
                          const Tab(
                            icon: Icon(Icons.menu_book, size: 20),
                            text: '암송',
                          ),
                          Tab(
                            icon: Badge(
                              isLabelVisible: _dueReviewCount > 0,
                              label: Text('$_dueReviewCount'),
                              backgroundColor: ParchmentTheme.warning,
                              child: const Icon(Icons.replay, size: 20),
                            ),
                            text: '복습',
                          ),
                          Tab(
                            icon: Badge(
                              isLabelVisible: _hasQuizToday,
                              backgroundColor: ParchmentTheme.warning,
                              smallSize: 8,
                              child: const Icon(Icons.quiz, size: 20),
                            ),
                            text: '퀴즈',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PracticeTab(authService: widget.authService),
                  _ReviewTab(onComplete: _loadSummaryStats),
                  _QuizTab(onComplete: _loadSummaryStats),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 암송 연습 탭
class _PracticeTab extends StatefulWidget {
  final AuthService authService;

  const _PracticeTab({required this.authService});

  @override
  State<_PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<_PracticeTab>
    with AutomaticKeepAliveClientMixin {
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final ProgressService _progress = ProgressService();
  final BibleDataService _bibleData = BibleDataService.instance;

  List<Book> _books = [];
  Book? _selectedBook;
  int _selectedChapter = 1;
  bool _isLoading = true;
  bool _showVerseList = false;

  Map<int, ChapterProgress> _chapterProgress = {};
  Map<int, VerseProgress> _verseProgress = {};
  int _verseCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _progress.init();
    final books = await _bibleData.getBooks();

    Book? selectedBook;
    if (books.isNotEmpty) {
      selectedBook = books.firstWhere((b) => b.isFree, orElse: () => books.first);
    }

    if (mounted) {
      setState(() {
        _books = books;
        _selectedBook = selectedBook;
        _selectedChapter = 1;
      });

      if (selectedBook != null) {
        await _loadChapterProgress();
        await _loadVerseProgress();
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChapterProgress() async {
    if (_selectedBook == null) return;

    final progressMap = <int, ChapterProgress>{};
    for (int ch = 1; ch <= _selectedBook!.chapterCount; ch++) {
      final verseCount = await _bibleData.getVerseCount(_selectedBook!.id, ch);
      progressMap[ch] = await _progress.getChapterProgress(
        book: _selectedBook!.id,
        chapter: ch,
        totalVerses: verseCount,
      );
    }

    if (mounted) {
      setState(() => _chapterProgress = progressMap);
    }
  }

  Future<void> _loadVerseProgress() async {
    if (_selectedBook == null) return;

    final verseCount = await _bibleData.getVerseCount(
      _selectedBook!.id,
      _selectedChapter,
    );

    final progressMap = <int, VerseProgress>{};
    for (int v = 1; v <= verseCount; v++) {
      progressMap[v] = await _progress.getVerseProgress(
        book: _selectedBook!.id,
        chapter: _selectedChapter,
        verse: v,
      );
    }

    if (mounted) {
      setState(() {
        _verseCount = verseCount;
        _verseProgress = progressMap;
      });
    }
  }

  int _getNextVerse() {
    for (int v = 1; v <= _verseCount; v++) {
      final progress = _verseProgress[v];
      if (progress == null || !progress.isCompleted) {
        return v;
      }
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBookSelector(),
                const SizedBox(height: 20),
                _buildChapterSelector(),
                const SizedBox(height: 20),
                _buildProgressCard(),
                const SizedBox(height: 16),
                _buildVerseListSection(),
              ],
            ),
          ),
        ),
        _buildBottomCTA(),
      ],
    );
  }

  Widget _buildBookSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Book>(
          value: _selectedBook,
          isExpanded: true,
          dropdownColor: _cardColor,
          icon: const Icon(Icons.keyboard_arrow_down, color: ParchmentTheme.fadedScript),
          style: const TextStyle(color: ParchmentTheme.ancientInk, fontSize: 16),
          items: _books.map((book) {
            return DropdownMenuItem<Book>(
              value: book,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: book.testament == 'OT'
                          ? ParchmentTheme.manuscriptGold.withValues(alpha: 0.2)
                          : ParchmentTheme.info.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        book.nameKo[0],
                        style: TextStyle(
                          color: book.testament == 'OT' ? ParchmentTheme.manuscriptGold : ParchmentTheme.info,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      book.nameKo,
                      style: const TextStyle(
                        color: ParchmentTheme.ancientInk,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (book.isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ParchmentTheme.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '무료',
                        style: TextStyle(
                          fontSize: 10,
                          color: ParchmentTheme.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (book) async {
            if (book != null && book != _selectedBook) {
              setState(() {
                _selectedBook = book;
                _selectedChapter = 1;
                _chapterProgress = {};
                _verseProgress = {};
              });
              await _loadChapterProgress();
              await _loadVerseProgress();
            }
          },
        ),
      ),
    );
  }

  Widget _buildChapterSelector() {
    if (_selectedBook == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.layers, color: ParchmentTheme.fadedScript, size: 18),
            const SizedBox(width: 8),
            const Text(
              '장 선택',
              style: TextStyle(
                color: ParchmentTheme.fadedScript,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${_selectedBook!.chapterCount}장',
              style: const TextStyle(
                color: ParchmentTheme.weatheredGray,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedBook!.chapterCount,
            itemBuilder: (context, index) {
              final chapter = index + 1;
              final progress = _chapterProgress[chapter];
              final isSelected = chapter == _selectedChapter;

              Color chipColor;
              if (progress?.status == ChapterStatus.completed) {
                chipColor = ParchmentTheme.success;
              } else if (progress?.status == ChapterStatus.inProgress) {
                chipColor = ParchmentTheme.info;
              } else {
                chipColor = ParchmentTheme.weatheredGray;
              }

              return GestureDetector(
                onTap: () async {
                  setState(() => _selectedChapter = chapter);
                  await _loadVerseProgress();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? chipColor.withValues(alpha: 0.15)
                        : _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? chipColor : ParchmentTheme.warmVellum,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? ParchmentTheme.cardShadow : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$chapter',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? chipColor : ParchmentTheme.fadedScript,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (progress != null && progress.progressPercent > 0)
                        Text(
                          '${progress.progressPercent}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: chipColor,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        const Text(
                          '미시작',
                          style: TextStyle(
                            fontSize: 10,
                            color: ParchmentTheme.weatheredGray,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final progress = _chapterProgress[_selectedChapter];
    final completedVerses = progress?.completedVerses ?? 0;
    final progressRate = _verseCount > 0 ? completedVerses / _verseCount : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ParchmentTheme.goldButtonGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3),
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
                  Text(
                    '${_selectedBook?.nameKo ?? ""} $_selectedChapter장',
                    style: const TextStyle(
                      color: ParchmentTheme.softPapyrus,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedVerses / $_verseCount절 완료',
                    style: TextStyle(
                      color: ParchmentTheme.softPapyrus.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              _buildCircularProgress(progressRate),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressRate,
              backgroundColor: ParchmentTheme.softPapyrus.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(ParchmentTheme.softPapyrus),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(double progress) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: ParchmentTheme.softPapyrus.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(ParchmentTheme.softPapyrus),
            ),
          ),
          Center(
            child: Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                color: ParchmentTheme.softPapyrus,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseListSection() {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _showVerseList = !_showVerseList),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
              boxShadow: ParchmentTheme.cardShadow,
            ),
            child: Row(
              children: [
                Icon(
                  _showVerseList ? Icons.expand_less : Icons.expand_more,
                  color: ParchmentTheme.fadedScript,
                ),
                const SizedBox(width: 8),
                const Text(
                  '구절 목록',
                  style: TextStyle(
                    color: ParchmentTheme.fadedScript,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_verseCount절',
                  style: const TextStyle(
                    color: ParchmentTheme.weatheredGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showVerseList) ...[
          const SizedBox(height: 12),
          _buildVerseGrid(),
        ],
      ],
    );
  }

  Widget _buildVerseGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_verseCount, (index) {
        final verse = index + 1;
        final progress = _verseProgress[verse];
        final isCompleted = progress?.isCompleted ?? false;
        final isInProgress = progress != null &&
            !isCompleted &&
            progress.stages.isNotEmpty;
        final nextVerse = _getNextVerse();
        final isNext = verse == nextVerse;

        Color bgColor;
        Color borderColor;
        IconData? icon;

        if (isCompleted) {
          bgColor = ParchmentTheme.success.withValues(alpha: 0.15);
          borderColor = ParchmentTheme.success;
          icon = Icons.check;
        } else if (isInProgress) {
          bgColor = ParchmentTheme.info.withValues(alpha: 0.15);
          borderColor = ParchmentTheme.info;
          icon = Icons.play_arrow;
        } else if (isNext) {
          bgColor = ParchmentTheme.manuscriptGold.withValues(alpha: 0.15);
          borderColor = ParchmentTheme.manuscriptGold;
          icon = Icons.arrow_forward;
        } else {
          bgColor = _cardColor;
          borderColor = ParchmentTheme.warmVellum;
          icon = null;
        }

        return GestureDetector(
          onTap: () => _startPractice(verse),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$verse',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCompleted || isInProgress || isNext
                        ? borderColor
                        : ParchmentTheme.weatheredGray,
                  ),
                ),
                if (icon != null)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Icon(icon, size: 12, color: borderColor),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomCTA() {
    final nextVerse = _getNextVerse();
    final progress = _chapterProgress[_selectedChapter];
    final isCompleted = progress?.status == ChapterStatus.completed;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: ParchmentTheme.goldButtonGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ParchmentTheme.buttonShadow,
          ),
          child: ElevatedButton(
            onPressed: () => _startPractice(nextVerse),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: ParchmentTheme.softPapyrus,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isCompleted ? Icons.replay : Icons.play_arrow),
                const SizedBox(width: 8),
                Text(
                  isCompleted
                      ? '다시 학습하기'
                      : '${nextVerse}절부터 학습 시작',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startPractice(int verse) {
    if (_selectedBook == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VersePracticeRedesigned(
          authService: widget.authService,
          book: _selectedBook!.id,
          chapter: _selectedChapter,
          initialVerse: verse,
        ),
      ),
    ).then((_) {
      _loadChapterProgress();
      _loadVerseProgress();
    });
  }
}

/// 복습 탭
class _ReviewTab extends StatefulWidget {
  final VoidCallback onComplete;

  const _ReviewTab({required this.onComplete});

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab>
    with AutomaticKeepAliveClientMixin {
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
  bool _sessionComplete = false;

  @override
  bool get wantKeepAlive => true;

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
      _sessionComplete = false;
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

    if (_currentIndex >= _dueItems.length) {
      setState(() => _sessionComplete = true);
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }

    if (_dueItems.isEmpty) {
      return _buildEmptyState();
    }

    if (_sessionComplete) {
      return _buildCompletionView();
    }

    return _buildReviewCard();
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
              boxShadow: ParchmentTheme.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ParchmentTheme.success.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: ParchmentTheme.success,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '오늘 복습할 구절이 없어요!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '새로운 구절을 학습하면\n복습 일정이 자동으로 생성됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: ParchmentTheme.fadedScript,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStatsCard(),
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
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
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
            color: ParchmentTheme.manuscriptGold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: ParchmentTheme.weatheredGray,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionView() {
    final duration = DateTime.now().difference(_sessionStart!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
              boxShadow: ParchmentTheme.cardShadow,
            ),
            child: Column(
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
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: ParchmentTheme.buttonShadow,
            ),
            child: ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: ParchmentTheme.softPapyrus,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('다시 시작', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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

  Widget _buildReviewCard() {
    final item = _dueItems[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 진행 바
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _dueItems.length,
            backgroundColor: ParchmentTheme.warmVellum,
            valueColor: const AlwaysStoppedAnimation(_accentColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentIndex + 1}/${_dueItems.length}',
            style: const TextStyle(color: ParchmentTheme.fadedScript),
          ),
          const SizedBox(height: 16),

          // 레벨 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(item.levelColor).withValues(alpha: 0.2),
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
          const SizedBox(height: 24),

          // 카드
          Expanded(
            child: GestureDetector(
              onTap: _showAnswer ? null : _showAnswerCard,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showAnswer
                    ? _buildAnswerSide(item)
                    : _buildQuestionSide(),
              ),
            ),
          ),

          // 버튼들
          if (_showAnswer) _buildAnswerButtons(),
        ],
      ),
    );
  }

  Widget _buildQuestionSide() {
    return Container(
      key: const ValueKey('question'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.4),
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
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
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
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
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

/// 퀴즈 탭
class _QuizTab extends StatefulWidget {
  final VoidCallback onComplete;

  const _QuizTab({required this.onComplete});

  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab>
    with AutomaticKeepAliveClientMixin {
  static const _bgColor = ParchmentTheme.agedParchment;
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final DailyQuizService _quizService = DailyQuizService();

  DailyQuiz? _quiz;
  QuizStreak? _streak;
  DailyQuizResult? _todayResult;
  bool _isLoading = true;
  bool _hasCompleted = false;

  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  DateTime? _startTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final quiz = await _quizService.getTodayQuiz();
    final streak = await _quizService.getQuizStreak();
    final hasCompleted = await _quizService.hasCompletedToday();

    DailyQuizResult? result;
    if (hasCompleted) {
      result = await _quizService.getTodayResult();
    }

    setState(() {
      _quiz = quiz;
      _streak = streak;
      _hasCompleted = hasCompleted;
      _todayResult = result;
      _isLoading = false;
      _startTime = null;
      _currentIndex = 0;
      _answers.clear();
    });
  }

  void _startQuiz() {
    setState(() {
      _currentIndex = 0;
      _answers.clear();
      _startTime = DateTime.now();
    });
  }

  void _selectAnswer(String answer) {
    if (_quiz == null) return;

    final question = _quiz!.questions[_currentIndex];
    setState(() {
      _answers[question.id] = answer;
    });
  }

  void _nextQuestion() {
    if (_quiz == null) return;

    if (_currentIndex < _quiz!.questionCount - 1) {
      setState(() => _currentIndex++);
    } else {
      _submitQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  Future<void> _submitQuiz() async {
    if (_quiz == null || _startTime == null) return;

    final timeTaken = DateTime.now().difference(_startTime!);

    final answers = _quiz!.questions.map((q) {
      final userAnswer = _answers[q.id] ?? '';
      return QuizAnswer(
        questionId: q.id,
        userAnswer: userAnswer,
        correctAnswer: q.correctAnswer,
        isCorrect: userAnswer == q.correctAnswer,
      );
    }).toList();

    setState(() => _isLoading = true);

    final result = await _quizService.submitQuiz(
      quiz: _quiz!,
      answers: answers,
      timeTaken: timeTaken,
    );

    if (result != null) {
      setState(() {
        _todayResult = result;
        _hasCompleted = true;
        _isLoading = false;
      });
      widget.onComplete();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('제출 중 오류가 발생했습니다'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }

    if (_hasCompleted) {
      return _buildResultView();
    }

    if (_startTime == null) {
      return _buildStartView();
    }

    return _buildQuizView();
  }

  Widget _buildStartView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_streak != null) _buildStreakCard(),
          const SizedBox(height: 20),
          if (_quiz != null) _buildQuizInfoCard(),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ParchmentTheme.buttonShadow,
            ),
            child: ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: ParchmentTheme.softPapyrus,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text(
                    '퀴즈 시작',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ParchmentTheme.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: ParchmentTheme.warning,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '연속 참여',
                  style: TextStyle(
                    fontSize: 14,
                    color: ParchmentTheme.fadedScript,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${_streak!.currentStreak}일',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ParchmentTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '최고: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: ParchmentTheme.weatheredGray,
                      ),
                    ),
                    Text(
                      '${_streak!.longestStreak}일',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ParchmentTheme.weatheredGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.quiz, color: _accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _quiz!.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ParchmentTheme.ancientInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_quiz!.questionCount}문제',
                      style: const TextStyle(
                        fontSize: 14,
                        color: ParchmentTheme.fadedScript,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: ParchmentTheme.warmVellum),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.toll,
                iconColor: ParchmentTheme.manuscriptGold,
                label: '기본 보상',
                value: '${_quiz!.totalPoints}',
              ),
              _buildInfoItem(
                icon: Icons.star,
                iconColor: ParchmentTheme.info,
                label: '만점 보너스',
                value: '+${_quiz!.bonusPoints}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: ParchmentTheme.weatheredGray,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuizView() {
    if (_quiz == null) return const SizedBox.shrink();

    final question = _quiz!.questions[_currentIndex];
    final selectedAnswer = _answers[question.id];

    return Column(
      children: [
        _buildProgressBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.type.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const SizedBox(height: 16),
                if (question.verseText != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.verseText!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: ParchmentTheme.ancientInk,
                            height: 1.5,
                          ),
                        ),
                        if (question.verseReference != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '- ${question.verseReference}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: ParchmentTheme.weatheredGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                ...question.options.map((option) {
                  final isSelected = selectedAnswer == option;
                  return GestureDetector(
                    onTap: () => _selectAnswer(option),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _accentColor.withValues(alpha: 0.15)
                            : _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _accentColor : ParchmentTheme.warmVellum,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? ParchmentTheme.cardShadow : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? _accentColor : ParchmentTheme.warmVellum,
                              border: Border.all(
                                color: isSelected
                                    ? _accentColor
                                    : ParchmentTheme.weatheredGray,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: ParchmentTheme.softPapyrus, size: 16)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                color: isSelected
                                    ? ParchmentTheme.ancientInk
                                    : ParchmentTheme.fadedScript,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        _buildBottomButtons(),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentIndex + 1) / _quiz!.questionCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: ParchmentTheme.warmVellum)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '문제 ${_currentIndex + 1}/${_quiz!.questionCount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
              Text(
                '${_answers.length}개 완료',
                style: const TextStyle(
                  color: ParchmentTheme.fadedScript,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedProgressBar(
            progress: progress,
            height: 6,
            backgroundColor: ParchmentTheme.warmVellum,
            valueColor: _accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final hasAnswer = _answers[_quiz!.questions[_currentIndex].id] != null;
    final isLast = _currentIndex == _quiz!.questionCount - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: ParchmentTheme.warmVellum)),
        boxShadow: [
          BoxShadow(
            color: ParchmentTheme.warmVellum.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousQuestion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ParchmentTheme.ancientInk,
                  side: const BorderSide(color: ParchmentTheme.manuscriptGold),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('이전'),
              ),
            ),
          if (_currentIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: hasAnswer
                  ? BoxDecoration(
                      gradient: ParchmentTheme.goldButtonGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: ParchmentTheme.buttonShadow,
                    )
                  : null,
              child: ElevatedButton(
                onPressed: hasAnswer ? _nextQuestion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasAnswer ? Colors.transparent : ParchmentTheme.warmVellum,
                  shadowColor: Colors.transparent,
                  foregroundColor: hasAnswer ? ParchmentTheme.softPapyrus : ParchmentTheme.weatheredGray,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isLast ? '제출' : '다음',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    if (_todayResult == null) return const SizedBox.shrink();

    final result = _todayResult!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3)),
              boxShadow: ParchmentTheme.cardShadow,
            ),
            child: Column(
              children: [
                Text(
                  result.isPerfect ? '🎉' : result.accuracy >= 0.8 ? '👍' : '💪',
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),
                Text(
                  result.isPerfect
                      ? '완벽해요!'
                      : result.accuracy >= 0.8
                          ? '잘했어요!'
                          : '수고했어요!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${result.correctCount}/${result.totalQuestions} 정답',
                  style: const TextStyle(
                    fontSize: 16,
                    color: ParchmentTheme.fadedScript,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.toll, color: ParchmentTheme.manuscriptGold, size: 28),
                    const SizedBox(width: 8),
                    AnimatedCounter(
                      value: result.totalEarned,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: ParchmentTheme.manuscriptGold,
                      ),
                    ),
                  ],
                ),
                if (result.bonusEarned > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: ParchmentTheme.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '만점 보너스 +${result.bonusEarned}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ParchmentTheme.info,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule, color: _accentColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '내일 새로운 퀴즈가 준비됩니다!',
                    style: TextStyle(
                      color: ParchmentTheme.fadedScript,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
