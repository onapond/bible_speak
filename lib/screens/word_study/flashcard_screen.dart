import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../services/tts_service.dart';
import '../../services/word_progress_service.dart';
import '../../services/auth_service.dart';

/// 플래시카드 화면
class FlashcardScreen extends StatefulWidget {
  final List<BibleWord> words;
  final String bookName;
  final int chapter;

  const FlashcardScreen({
    super.key,
    required this.words,
    required this.bookName,
    required this.chapter,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);
  static const _successColor = Color(0xFF4CAF50);

  final TTSService _tts = TTSService();
  final WordProgressService _progressService = WordProgressService();

  late List<BibleWord> _shuffledWords;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isPlaying = false;

  // 학습 결과 추적
  int _knownCount = 0;
  int _unknownCount = 0;
  int _vagueCount = 0;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _shuffledWords = List.from(widget.words)..shuffle();
    _progressService.init();

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  Future<void> _playPronunciation() async {
    if (_isPlaying) return;

    setState(() => _isPlaying = true);
    try {
      await _tts.speakText(_shuffledWords[_currentIndex].word);
    } catch (_) {}
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _markAnswer(String answer) async {
    final word = _shuffledWords[_currentIndex];

    // 결과 추적
    switch (answer) {
      case 'known':
        _knownCount++;
        break;
      case 'vague':
        _vagueCount++;
        break;
      case 'unknown':
        _unknownCount++;
        break;
    }

    // SRS 기반 기록
    await _progressService.recordFlashcardAnswer(
      wordId: word.id,
      answer: answer,
    );

    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < _shuffledWords.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
      _flipController.reset();
    } else {
      _showResultDialog();
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
      _flipController.reset();
    }
  }

  void _showResultDialog() async {
    // 탈란트 적립
    final earnedTalants = await AuthService().earnWordStudyTalant(
      activityType: 'flashcard',
      totalWords: _shuffledWords.length,
      correctCount: _knownCount,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          '학습 완료!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResultRow('암기 완료', _knownCount, Colors.green),
            _buildResultRow('애매함', _vagueCount, Colors.orange),
            _buildResultRow('모름', _unknownCount, Colors.red),
            const Divider(color: Colors.white24),
            Text(
              '총 ${_shuffledWords.length}개 단어 학습',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (earnedTalants > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      '+$earnedTalants 달란트',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetStudy();
            },
            child: Text(
              '다시 학습',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('완료'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            '$count개',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _resetStudy() {
    setState(() {
      _shuffledWords.shuffle();
      _currentIndex = 0;
      _isFlipped = false;
      _knownCount = 0;
      _unknownCount = 0;
      _vagueCount = 0;
    });
    _flipController.reset();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = _shuffledWords[_currentIndex];

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          widget.chapter > 0
              ? '${widget.bookName} ${widget.chapter}장 플래시카드'
              : '${widget.bookName} 플래시카드',
        ),
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 진행 표시
            _buildProgressIndicator(),

            // 카드
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * pi;
                      final isFront = angle < pi / 2;

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: isFront
                            ? _buildFrontCard(word)
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(pi),
                                child: _buildBackCard(word),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 평가 버튼 (뒤집힌 상태에서만)
            if (_isFlipped) _buildEvaluationButtons(),

            // 네비게이션
            _buildNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
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
              Text(
                '${_currentIndex + 1} / ${_shuffledWords.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  _buildMiniStat(Icons.check_circle, _knownCount, _successColor),
                  const SizedBox(width: 12),
                  _buildMiniStat(Icons.help, _vagueCount, Colors.orange),
                  const SizedBox(width: 12),
                  _buildMiniStat(Icons.cancel, _unknownCount, Colors.red),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _shuffledWords.length,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFrontCard(BibleWord word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // 영단어
          Text(
            word.word,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // 발음 기호
          Text(
            word.pronunciation,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          // 발음 버튼
          ElevatedButton.icon(
            onPressed: _playPronunciation,
            icon: _isPlaying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.volume_up),
            label: const Text('발음 듣기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
          const Spacer(),
          // 힌트
          Text(
            '탭하여 뜻 보기',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBackCard(BibleWord word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentColor.withValues(alpha: 0.3),
            const Color(0xFF9C27B0).withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accentColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 품사
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              word.partOfSpeechKo,
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 뜻
          Text(
            word.allMeanings,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // 예문 (첫 번째 구절)
          if (word.verses.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '"${word.verses.first.excerpt}"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '- ${word.verses.first.reference}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 암기 팁
          if (word.memoryTip != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lightbulb, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    word.memoryTip!,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvaluationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildEvalButton(
              '모름',
              Icons.sentiment_dissatisfied,
              Colors.red,
              () => _markAnswer('unknown'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildEvalButton(
              '애매함',
              Icons.sentiment_neutral,
              Colors.orange,
              () => _markAnswer('vague'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildEvalButton(
              '암기!',
              Icons.sentiment_very_satisfied,
              _successColor,
              () => _markAnswer('known'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvalButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        elevation: 0,
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentIndex > 0 ? _previousCard : null,
            icon: const Icon(Icons.arrow_back_ios),
            color: Colors.white,
            disabledColor: Colors.white.withValues(alpha: 0.3),
          ),
          Text(
            '카드를 탭하여 뒤집기',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          IconButton(
            onPressed:
                _currentIndex < _shuffledWords.length - 1 ? _nextCard : null,
            icon: const Icon(Icons.arrow_forward_ios),
            color: Colors.white,
            disabledColor: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
