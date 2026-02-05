import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../models/word_progress.dart';
import '../../services/tts_service.dart';
import '../../services/word_progress_service.dart';
import '../../styles/parchment_theme.dart';

/// 단어 상세 화면
class WordDetailScreen extends StatefulWidget {
  final BibleWord word;
  final WordProgress? progress;

  const WordDetailScreen({
    super.key,
    required this.word,
    this.progress,
  });

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

  final TTSService _tts = TTSService();
  final WordProgressService _progressService = WordProgressService();

  bool _isPlaying = false;
  late WordProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress ?? WordProgress(wordId: widget.word.id);
  }

  Future<void> _playPronunciation() async {
    if (_isPlaying) {
      await _tts.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      await _tts.speakText(widget.word.word);
    } catch (e) {
      _showSnackBar('발음 재생 실패', isError: true);
    }

    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _markAsLearned() async {
    await _progressService.init();
    final updated = await _progressService.recordAnswer(
      wordId: widget.word.id,
      isCorrect: true,
    );

    setState(() => _progress = updated);
    _showSnackBar('학습 완료 기록됨!', isError: false);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ParchmentTheme.error : ParchmentTheme.success,
      ),
    );
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;

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
                    Expanded(
                      child: Text(
                        word.word,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 메인 단어 카드
                      _buildMainCard(word),
                      const SizedBox(height: 20),

                      // 등장 구절
                      if (word.verses.isNotEmpty) ...[
                        _buildSectionTitle('등장 구절'),
                        const SizedBox(height: 12),
                        ...word.verses.map((v) => _buildVerseCard(v)),
                        const SizedBox(height: 20),
                      ],

                      // 암기 팁
                      if (word.memoryTip != null) ...[
                        _buildSectionTitle('암기 팁'),
                        const SizedBox(height: 12),
                        _buildTipCard(word.memoryTip!),
                        const SizedBox(height: 20),
                      ],

                      // 학습 상태
                      _buildProgressCard(),
                      const SizedBox(height: 20),

                      // 액션 버튼
                      _buildActionButtons(),
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

  Widget _buildMainCard(BibleWord word) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 단어 + 발음 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                word.word,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _playPronunciation,
                icon: _isPlaying
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ParchmentTheme.manuscriptGold,
                        ),
                      )
                    : const Icon(
                        Icons.volume_up,
                        size: 28,
                        color: ParchmentTheme.manuscriptGold,
                      ),
                tooltip: '발음 듣기',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 발음 기호
          Text(
            word.pronunciation,
            style: const TextStyle(
              fontSize: 16,
              color: ParchmentTheme.fadedScript,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

          // 품사
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '품사',
              style: TextStyle(
                color: ParchmentTheme.manuscriptGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            word.partOfSpeechKo,
            style: const TextStyle(
              color: ParchmentTheme.fadedScript,
            ),
          ),
          const SizedBox(height: 20),

          // 뜻
          Divider(color: ParchmentTheme.warmVellum.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          ...word.meanings.map(
            (meaning) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: ParchmentTheme.manuscriptGold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      meaning,
                      style: const TextStyle(
                        fontSize: 18,
                        color: ParchmentTheme.ancientInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 난이도
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '난이도: ',
                style: TextStyle(
                  color: ParchmentTheme.fadedScript,
                  fontSize: 12,
                ),
              ),
              ...List.generate(5, (i) {
                final isActive = i < word.difficulty;
                return Icon(
                  isActive ? Icons.star : Icons.star_border,
                  size: 16,
                  color: isActive ? ParchmentTheme.manuscriptGold : ParchmentTheme.warmVellum,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ParchmentTheme.ancientInk,
          ),
        ),
      ],
    );
  }

  Widget _buildVerseCard(VerseReference verse) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 참조
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              verse.reference,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ParchmentTheme.manuscriptGold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 영어 발췌
          Text(
            '"${verse.excerpt}"',
            style: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: ParchmentTheme.ancientInk,
            ),
          ),
          const SizedBox(height: 8),

          // 한글 번역
          Text(
            verse.korean,
            style: const TextStyle(
              fontSize: 14,
              color: ParchmentTheme.fadedScript,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: ParchmentTheme.manuscriptGold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: ParchmentTheme.manuscriptGold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final status = _progress.status;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case WordStatus.mastered:
        statusColor = ParchmentTheme.success;
        statusText = '암기 완료!';
        statusIcon = Icons.check_circle;
        break;
      case WordStatus.reviewing:
        statusColor = ParchmentTheme.info;
        statusText = '복습 중';
        statusIcon = Icons.replay;
        break;
      case WordStatus.learning:
        statusColor = ParchmentTheme.warning;
        statusText = '학습 중';
        statusIcon = Icons.pending;
        break;
      case WordStatus.notStarted:
        statusColor = ParchmentTheme.weatheredGray;
        statusText = '아직 학습 전';
        statusIcon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 16,
                  ),
                ),
                if (_progress.totalAttempts > 0)
                  Text(
                    '정답: ${_progress.correctCount}회 / 시도: ${_progress.totalAttempts}회',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ParchmentTheme.fadedScript,
                    ),
                  ),
                if (_progress.lastStudied != null)
                  Text(
                    '마지막 학습: ${_formatDate(_progress.lastStudied!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ParchmentTheme.fadedScript,
                    ),
                  ),
              ],
            ),
          ),
          if (_progress.streak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ParchmentTheme.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_fire_department, size: 16, color: ParchmentTheme.warning),
                  SizedBox(width: 4),
                  Text(
                    '연속',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: ParchmentTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '오늘';
    } else if (diff.inDays == 1) {
      return '어제';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _playPronunciation,
            icon: const Icon(Icons.volume_up),
            label: const Text('발음 듣기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ParchmentTheme.ancientInk,
              side: BorderSide(color: _accentColor.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: ParchmentTheme.goldButtonGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: ParchmentTheme.buttonShadow,
            ),
            child: ElevatedButton.icon(
              onPressed: _markAsLearned,
              icon: const Icon(Icons.check),
              label: const Text('학습 완료'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: ParchmentTheme.softPapyrus,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
