import 'package:flutter/material.dart';
import '../../services/pronunciation/azure_pronunciation_service.dart';
import 'phoneme_score_bar.dart';

/// 단어 발음 상세 팝업
/// - 단어 + IPA 발음 + 한글 가이드
/// - 전체 음소별 점수 바
/// - 발음 팁
class WordPronunciationPopup extends StatefulWidget {
  final WordPronunciation word;
  final Future<void> Function(String text)? onPlayWord;

  const WordPronunciationPopup({
    super.key,
    required this.word,
    this.onPlayWord,
  });

  /// 팝업 표시 헬퍼
  static Future<void> show(
    BuildContext context,
    WordPronunciation word, {
    Future<void> Function(String text)? onPlayWord,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WordPronunciationPopup(
        word: word,
        onPlayWord: onPlayWord,
      ),
    );
  }

  @override
  State<WordPronunciationPopup> createState() => _WordPronunciationPopupState();
}

class _WordPronunciationPopupState extends State<WordPronunciationPopup> {
  bool _isPlaying = false;

  Color get _statusColor {
    if (widget.word.isOmitted) return Colors.grey;
    if (widget.word.accuracyScore >= 80) return const Color(0xFF4CAF50);
    if (widget.word.accuracyScore >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String get _statusText {
    if (widget.word.isOmitted) return '누락됨';
    if (widget.word.accuracyScore >= 80) return '정확함';
    if (widget.word.accuracyScore >= 60) return '개선 필요';
    return '발음 오류';
  }

  IconData get _statusIcon {
    if (widget.word.isOmitted) return Icons.remove_circle_outline;
    if (widget.word.accuracyScore >= 80) return Icons.check_circle;
    if (widget.word.accuracyScore >= 60) return Icons.info;
    return Icons.error;
  }

  /// 한글 발음 가이드 생성
  String get _koreanGuide {
    if (widget.word.phonemes.isEmpty) return '';
    return widget.word.phonemes.map((p) => p.koreanHint).join('-');
  }

  /// IPA 발음 기호 생성
  String get _ipaGuide {
    if (widget.word.phonemes.isEmpty) return '';
    return '/${widget.word.phonemes.map((p) => p.phoneme).join('')}/';
  }

  Future<void> _playWord() async {
    if (widget.onPlayWord == null || _isPlaying) return;

    setState(() => _isPlaying = true);
    try {
      await widget.onPlayWord!(widget.word.word);
    } catch (e) {
      // 에러 무시
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더: 단어 + 상태
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 단어와 재생 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.word.word,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _playWord,
                      icon: Icon(
                        _isPlaying ? Icons.stop : Icons.volume_up,
                        color: const Color(0xFF6C63FF),
                        size: 28,
                      ),
                    ),
                  ],
                ),

                // IPA 발음
                if (_ipaGuide.isNotEmpty)
                  Text(
                    _ipaGuide,
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'monospace',
                      color: Colors.grey[400],
                    ),
                  ),

                const SizedBox(height: 8),

                // 한글 발음 가이드
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _koreanGuide,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 전체 점수 + 상태
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_statusIcon, color: _statusColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 16,
                        color: _statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.word.accuracyScore.toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Colors.grey, height: 1),

          // 음소별 상세
          Flexible(
            child: widget.word.phonemes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '음소 데이터가 없습니다',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    children: [
                      // 섹션 헤더
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.analytics_outlined,
                              color: Color(0xFF6C63FF),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '음소별 분석',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 음소 리스트
                      ...widget.word.phonemes.map((phoneme) => PhonemeScoreBar(
                            phoneme: phoneme,
                            showTip: phoneme.accuracyScore < 80,
                          )),

                      const SizedBox(height: 16),

                      // 공통 발음 팁
                      if (widget.word.worstPhoneme != null &&
                          widget.word.worstPhoneme!.pronunciationTip != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.tips_and_updates,
                                    color: Colors.amber[300],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '가장 어려운 음소: ${widget.word.worstPhoneme!.phoneme}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.amber[300],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.word.worstPhoneme!.pronunciationTip!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // 닫기 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
