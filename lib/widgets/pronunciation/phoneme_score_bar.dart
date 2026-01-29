import 'package:flutter/material.dart';
import '../../services/pronunciation/azure_pronunciation_service.dart';

/// 음소별 점수 바 위젯
/// - 음소 심볼 + 한글 힌트
/// - 점수 바 (색상: 빨강 <60%, 주황 60-80%, 초록 >=80%)
/// - 탭하면 발음 팁 표시
class PhonemeScoreBar extends StatelessWidget {
  final PhonemePronunciation phoneme;
  final bool showTip;
  final VoidCallback? onTap;

  const PhonemeScoreBar({
    super.key,
    required this.phoneme,
    this.showTip = false,
    this.onTap,
  });

  Color get _scoreColor {
    if (phoneme.accuracyScore >= 80) return const Color(0xFF4CAF50); // Green
    if (phoneme.accuracyScore >= 60) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  Color get _backgroundColor {
    if (phoneme.accuracyScore >= 80) return const Color(0xFF4CAF50).withValues(alpha: 0.2);
    if (phoneme.accuracyScore >= 60) return const Color(0xFFFF9800).withValues(alpha: 0.2);
    return const Color(0xFFF44336).withValues(alpha: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _scoreColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 음소 + 한글 힌트 + 점수
            Row(
              children: [
                // IPA 심볼
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    phoneme.phoneme,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 한글 힌트
                Expanded(
                  child: Text(
                    phoneme.koreanHint,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[300],
                    ),
                  ),
                ),
                // 점수
                Text(
                  '${phoneme.accuracyScore.toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _scoreColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 점수 바
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: phoneme.accuracyScore / 100,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(_scoreColor),
                minHeight: 8,
              ),
            ),
            // 발음 팁 (옵션)
            if (showTip && phoneme.pronunciationTip != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.amber[300],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phoneme.pronunciationTip!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 간단한 음소 칩 (인라인용)
class PhonemeChip extends StatelessWidget {
  final PhonemePronunciation phoneme;
  final VoidCallback? onTap;

  const PhonemeChip({
    super.key,
    required this.phoneme,
    this.onTap,
  });

  Color get _scoreColor {
    if (phoneme.accuracyScore >= 80) return const Color(0xFF4CAF50);
    if (phoneme.accuracyScore >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 4, bottom: 4),
        decoration: BoxDecoration(
          color: _scoreColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _scoreColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              phoneme.phoneme,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _scoreColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${phoneme.accuracyScore.toInt()}%',
              style: TextStyle(
                fontSize: 11,
                color: _scoreColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
