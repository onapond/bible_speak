import 'package:flutter/material.dart';
import '../../domain/models/bible/bible_models.dart';
import '../../services/auth_service.dart';
import '../../services/bible_data_service.dart';
import '../../services/progress_service.dart';
import '../../models/verse_progress.dart';
import '../../styles/parchment_theme.dart';
import '../practice/verse_practice_redesigned.dart';

/// 통합 암송 연습 설정 화면
/// - 책 선택 (드롭다운)
/// - 장 선택 (가로 스크롤)
/// - 진행률 표시
/// - 바로 학습 시작
class PracticeSetupScreen extends StatefulWidget {
  final AuthService authService;
  final String? initialBookId;
  final int? initialChapter;

  const PracticeSetupScreen({
    super.key,
    required this.authService,
    this.initialBookId,
    this.initialChapter,
  });

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  final ProgressService _progress = ProgressService();
  final BibleDataService _bibleData = BibleDataService.instance;

  // 상태
  List<Book> _books = [];
  Book? _selectedBook;
  int _selectedChapter = 1;
  bool _isLoading = true;
  bool _showVerseList = false;

  // 진행률 데이터
  Map<int, ChapterProgress> _chapterProgress = {};
  Map<int, VerseProgress> _verseProgress = {};
  int _verseCount = 0;

  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _progress.init();
    final books = await _bibleData.getBooks();

    Book? selectedBook;
    if (widget.initialBookId != null) {
      selectedBook = books.firstWhere(
        (b) => b.id == widget.initialBookId,
        orElse: () => books.first,
      );
    } else if (books.isNotEmpty) {
      // 기본값: 무료 책 중 첫 번째 또는 전체 첫 번째
      selectedBook = books.firstWhere((b) => b.isFree, orElse: () => books.first);
    }

    if (mounted) {
      setState(() {
        _books = books;
        _selectedBook = selectedBook;
        _selectedChapter = widget.initialChapter ?? 1;
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
    // 완료되지 않은 첫 번째 구절 찾기
    for (int v = 1; v <= _verseCount; v++) {
      final progress = _verseProgress[v];
      if (progress == null || !progress.isCompleted) {
        return v;
      }
    }
    return 1; // 모두 완료면 처음부터
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
                        '암송 연습',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
              ),
              // Body content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: ParchmentTheme.manuscriptGold,
                        ),
                      )
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 책 선택 드롭다운
                _buildBookSelector(),
                const SizedBox(height: 20),

                // 장 선택 (가로 스크롤)
                _buildChapterSelector(),
                const SizedBox(height: 20),

                // 현재 장 진행률 카드
                _buildProgressCard(),
                const SizedBox(height: 16),

                // 구절 목록 (접기/펼치기)
                _buildVerseListSection(),
              ],
            ),
          ),
        ),

        // 하단 CTA 버튼
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
                          ? ParchmentTheme.warning.withValues(alpha: 0.2)
                          : _accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        book.nameKo[0],
                        style: TextStyle(
                          color: book.testament == 'OT'
                              ? ParchmentTheme.warning
                              : _accentColor,
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
              // Note: using index as key since chapters are 1-indexed contiguous integers
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

              return KeyedSubtree(
                key: ValueKey('chapter_$chapter'),
                child: GestureDetector(
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
                      color: isSelected
                          ? chipColor
                          : ParchmentTheme.manuscriptGold.withValues(alpha: 0.2),
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
        boxShadow: ParchmentTheme.goldGlow,
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
              valueColor: const AlwaysStoppedAnimation<Color>(ParchmentTheme.success),
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
              valueColor: const AlwaysStoppedAnimation<Color>(ParchmentTheme.success),
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
        // 토글 헤더
        InkWell(
          onTap: () => setState(() => _showVerseList = !_showVerseList),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3),
              ),
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

        // 구절 그리드
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
          top: BorderSide(
            color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.3),
          ),
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
          book: _selectedBook!.id,
          chapter: _selectedChapter,
          initialVerse: verse,
        ),
      ),
    ).then((_) {
      // 돌아오면 진행률 새로고침
      _loadChapterProgress();
      _loadVerseProgress();
    });
  }
}
