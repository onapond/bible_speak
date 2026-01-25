import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/bible_word.dart';
import '../../services/tts_service.dart';
import '../../services/word_progress_service.dart';

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
        await _progressService.recordAnswer(wordId: word.id, isCorrect: true);
        break;
      case 'vague':
        _vagueCount++;
        await _progressService.recordAnswer(wordId: word.id, isCorrect: false);
        break;
      case 'unknown':
        _unknownCount++;
        await _progressService.recordAnswer(wordId: word.id, isCorrect: false);
        break;
    }

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

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('학습 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResultRow('암기 완료', _knownCount, Colors.green),
            _buildResultRow('애매함', _vagueCount, Colors.orange),
            _buildResultRow('모름', _unknownCount, Colors.red),
            const Divider(),
            Text(
              '총 ${_shuffledWords.length}개 단어 학습',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetStudy();
            },
            child: const Text('다시 학습'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
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
      appBar: AppBar(
        title: Text('${widget.bookName} ${widget.chapter}장 플래시카드'),
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
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  _buildMiniStat(Icons.check_circle, _knownCount, Colors.green.shade300),
                  const SizedBox(width: 12),
                  _buildMiniStat(Icons.help, _vagueCount, Colors.orange.shade300),
                  const SizedBox(width: 12),
                  _buildMiniStat(Icons.cancel, _unknownCount, Colors.red.shade300),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _shuffledWords.length,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
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
              ),
            ),
            const SizedBox(height: 8),
            // 발음 기호
            Text(
              word.pronunciation,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
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
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const Spacer(),
            // 힌트
            Text(
              '탭하여 뜻 보기',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBackCard(BibleWord word) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.green.shade50,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 품사
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                word.partOfSpeechKo,
                style: TextStyle(
                  color: Colors.green.shade800,
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
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // 예문 (첫 번째 구절)
            if (word.verses.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '"${word.verses.first.excerpt}"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '- ${word.verses.first.reference}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
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
                  Icon(Icons.lightbulb, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      word.memoryTip!,
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
              Colors.green,
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
        backgroundColor: Colors.white,
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            disabledColor: Colors.white38,
          ),
          Text(
            '카드를 탭하여 뒤집기',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          IconButton(
            onPressed:
                _currentIndex < _shuffledWords.length - 1 ? _nextCard : null,
            icon: const Icon(Icons.arrow_forward_ios),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
        ],
      ),
    );
  }
}
