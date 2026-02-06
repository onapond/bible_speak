import 'dart:ui';
import 'package:flutter/material.dart';

/// 모던한 성경 구절 암송 카드 위젯
///
/// UI/UX Pro Max 디자인 시스템 적용:
/// - Glassmorphism 스타일
/// - Soft gradient 배경
/// - 부드러운 애니메이션
/// - 영적/명상적 분위기의 색상 팔레트
class VerseMemorizationCard extends StatefulWidget {
  final String verseReference; // "말라기 1:2"
  final String englishText;
  final String? koreanText;
  final int currentStage; // 1, 2, 3
  final double? bestScore;
  final bool isCompleted;
  final bool isCurrentVerse;
  final VoidCallback? onTap;
  final VoidCallback? onPlayAudio;
  final bool isAudioPlaying;
  final bool isAudioLoading;

  const VerseMemorizationCard({
    super.key,
    required this.verseReference,
    required this.englishText,
    this.koreanText,
    this.currentStage = 1,
    this.bestScore,
    this.isCompleted = false,
    this.isCurrentVerse = false,
    this.onTap,
    this.onPlayAudio,
    this.isAudioPlaying = false,
    this.isAudioLoading = false,
  });

  @override
  State<VerseMemorizationCard> createState() => _VerseMemorizationCardState();
}

class _VerseMemorizationCardState extends State<VerseMemorizationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isCurrentVerse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VerseMemorizationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentVerse && !oldWidget.isCurrentVerse) {
      _controller.repeat(reverse: true);
    } else if (!widget.isCurrentVerse && oldWidget.isCurrentVerse) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCurrentVerse ? _scaleAnimation.value : 1.0,
          child: _buildCard(),
        );
      },
    );
  }

  Widget _buildCard() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (widget.isCurrentVerse)
              BoxShadow(
                color: _VerseCardColors.primary.withValues(alpha: _glowAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isCompleted
                      ? [
                          _VerseCardColors.successGradientStart,
                          _VerseCardColors.successGradientEnd,
                        ]
                      : [
                          _VerseCardColors.cardGradientStart,
                          _VerseCardColors.cardGradientEnd,
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isCurrentVerse
                      ? _VerseCardColors.primary.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                  width: widget.isCurrentVerse ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildVerseContent(),
                    if (widget.koreanText != null) ...[
                      const SizedBox(height: 12),
                      _buildKoreanText(),
                    ],
                    const SizedBox(height: 16),
                    _buildStageProgress(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // 구절 참조
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                _VerseCardColors.primary,
                _VerseCardColors.primaryLight,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _VerseCardColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                widget.verseReference,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // 완료 배지
        if (widget.isCompleted)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _VerseCardColors.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: _VerseCardColors.success.withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: _VerseCardColors.success,
              size: 20,
            ),
          ),
        // 점수 표시
        if (widget.bestScore != null && !widget.isCompleted) ...[
          const SizedBox(width: 8),
          _buildScoreBadge(),
        ],
        // 오디오 버튼
        const SizedBox(width: 8),
        _buildAudioButton(),
      ],
    );
  }

  Widget _buildScoreBadge() {
    final score = widget.bestScore!;
    final color = _getScoreColor(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${score.toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildAudioButton() {
    return GestureDetector(
      onTap: widget.onPlayAudio,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: widget.isAudioLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _VerseCardColors.primary,
                ),
              )
            : Icon(
                widget.isAudioPlaying
                    ? Icons.stop_rounded
                    : Icons.volume_up_rounded,
                color: widget.isAudioPlaying
                    ? _VerseCardColors.warning
                    : Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
      ),
    );
  }

  Widget _buildVerseContent() {
    // Stage에 따른 텍스트 표시
    String displayText;
    TextStyle textStyle;

    switch (widget.currentStage) {
      case 1:
        // Stage 1: 전체 텍스트
        displayText = widget.englishText;
        textStyle = _VerseCardStyles.verseText;
        break;
      case 2:
        // Stage 2: 빈칸 처리
        displayText = _getBlankText(widget.englishText);
        textStyle = _VerseCardStyles.verseText;
        break;
      case 3:
        // Stage 3: 숨김
        displayText = '';
        textStyle = _VerseCardStyles.verseText;
        break;
      default:
        displayText = widget.englishText;
        textStyle = _VerseCardStyles.verseText;
    }

    if (widget.currentStage == 3) {
      return _buildHiddenVerseContent();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Text(
        displayText,
        style: textStyle,
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildHiddenVerseContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _VerseCardColors.primary.withValues(alpha: 0.1),
            _VerseCardColors.primaryLight.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _VerseCardColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.visibility_off_rounded,
            size: 40,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            '영어 텍스트 없이 암송하세요',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '최종 단계입니다!',
            style: TextStyle(
              fontSize: 13,
              color: _VerseCardColors.primary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKoreanText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: _VerseCardColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '한국어',
                style: TextStyle(
                  fontSize: 12,
                  color: _VerseCardColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.koreanText!,
            style: _VerseCardStyles.koreanText,
          ),
        ],
      ),
    );
  }

  Widget _buildStageProgress() {
    return Row(
      children: List.generate(3, (index) {
        final stageNum = index + 1;
        final isActive = stageNum == widget.currentStage;
        final isCompleted = stageNum < widget.currentStage ||
            (widget.isCompleted && stageNum <= 3);

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
            child: Column(
              children: [
                // 스테이지 프로그레스 바
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: isCompleted || isActive
                        ? LinearGradient(
                            colors: isCompleted
                                ? [
                                    _VerseCardColors.success,
                                    _VerseCardColors.success.withValues(alpha: 0.7),
                                  ]
                                : [
                                    _VerseCardColors.primary,
                                    _VerseCardColors.primaryLight,
                                  ],
                          )
                        : null,
                    color: isCompleted || isActive
                        ? null
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(height: 8),
                // 스테이지 라벨
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getStageIcon(stageNum),
                      size: 14,
                      color: isActive
                          ? _VerseCardColors.primary
                          : (isCompleted
                              ? _VerseCardColors.success
                              : Colors.white.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getStageName(stageNum),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? _VerseCardColors.primary
                            : (isCompleted
                                ? _VerseCardColors.success
                                : Colors.white.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _getBlankText(String text) {
    final words = text.split(' ');
    final keyWords = _getKeyWords(text);

    return words.map((word) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      if (keyWords.contains(cleanWord)) {
        final punctuation = word.replaceAll(RegExp(r'\w'), '');
        return '_____$punctuation';
      }
      return word;
    }).join(' ');
  }

  List<String> _getKeyWords(String text) {
    final words = text.split(' ');
    final keyWords = <String>[];
    final excludeWords = ['have', 'with', 'that', 'this', 'from', 'will', 'been', 'were', 'the', 'and', 'for'];

    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      if (cleanWord.length >= 4 && keyWords.length < 3 && !excludeWords.contains(cleanWord)) {
        keyWords.add(cleanWord);
      }
    }
    return keyWords;
  }

  IconData _getStageIcon(int stage) {
    switch (stage) {
      case 1:
        return Icons.hearing_rounded;
      case 2:
        return Icons.edit_note_rounded;
      case 3:
        return Icons.record_voice_over_rounded;
      default:
        return Icons.circle;
    }
  }

  String _getStageName(int stage) {
    switch (stage) {
      case 1:
        return '듣기';
      case 2:
        return '빈칸';
      case 3:
        return '암송';
      default:
        return '';
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 85) return _VerseCardColors.success;
    if (score >= 70) return _VerseCardColors.primary;
    if (score >= 50) return _VerseCardColors.warning;
    return _VerseCardColors.error;
  }
}

/// 색상 팔레트 (영적/명상 테마)
class _VerseCardColors {
  // Primary - 깊은 보라/인디고
  static const primary = Color(0xFF7C4DFF);
  static const primaryLight = Color(0xFFB388FF);
  static const primaryDark = Color(0xFF651FFF);

  // 보조 색상
  static const accent = Color(0xFF64FFDA);
  static const success = Color(0xFF69F0AE);
  static const warning = Color(0xFFFFD54F);
  static const error = Color(0xFFFF5252);

  // 배경 그라데이션
  static const cardGradientStart = Color(0xFF1A1A2E);
  static const cardGradientEnd = Color(0xFF16213E);

  // 완료 상태 그라데이션
  static const successGradientStart = Color(0xFF0D2818);
  static const successGradientEnd = Color(0xFF1A4D2E);
}

/// 텍스트 스타일
class _VerseCardStyles {
  static const verseText = TextStyle(
    fontSize: 18,
    height: 1.7,
    color: Colors.white,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );

  static final koreanText = TextStyle(
    fontSize: 15,
    height: 1.6,
    color: Colors.white.withValues(alpha: 0.75),
    fontWeight: FontWeight.w400,
  );
}

/// 녹음 버튼 위젯 (Glassmorphism)
class RecordButton extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final bool isDisabled;
  final VoidCallback? onPressed;

  const RecordButton({
    super.key,
    this.isRecording = false,
    this.isProcessing = false,
    this.isDisabled = false,
    this.onPressed,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.isDisabled ? null : widget.onPressed,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isRecording
                    ? [
                        const Color(0xFFFF5252),
                        const Color(0xFFD32F2F),
                      ]
                    : widget.isDisabled
                        ? [
                            Colors.grey.shade600,
                            Colors.grey.shade800,
                          ]
                        : [
                            _VerseCardColors.primary,
                            _VerseCardColors.primaryDark,
                          ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isRecording
                          ? const Color(0xFFFF5252)
                          : _VerseCardColors.primary)
                      .withValues(alpha: widget.isRecording ? _pulseAnimation.value * 0.5 : 0.4),
                  blurRadius: widget.isRecording ? 24 : 16,
                  spreadRadius: widget.isRecording ? 4 : 2,
                ),
              ],
            ),
            child: Transform.scale(
              scale: widget.isRecording ? _pulseAnimation.value : 1.0,
              child: Center(
                child: widget.isProcessing
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 점수 결과 카드 (Glassmorphism)
class ScoreResultCard extends StatelessWidget {
  final double score;
  final double accuracyScore;
  final double fluencyScore;
  final double prosodyScore;
  final bool passed;
  final String? encouragement;
  final VoidCallback? onRetry;
  final VoidCallback? onNextStage;

  const ScoreResultCard({
    super.key,
    required this.score,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.prosodyScore,
    this.passed = false,
    this.encouragement,
    this.onRetry,
    this.onNextStage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (passed ? _VerseCardColors.success : _VerseCardColors.warning)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: passed
                    ? [
                        _VerseCardColors.successGradientStart,
                        _VerseCardColors.successGradientEnd,
                      ]
                    : [
                        const Color(0xFF2D1F1F),
                        const Color(0xFF1A1A2E),
                      ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: passed
                    ? _VerseCardColors.success.withValues(alpha: 0.3)
                    : _VerseCardColors.warning.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 점수 서클
                _buildScoreCircle(),
                const SizedBox(height: 20),

                // 통과/실패 메시지
                Text(
                  passed ? '통과!' : '다시 도전해보세요',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: passed ? _VerseCardColors.success : _VerseCardColors.warning,
                  ),
                ),
                const SizedBox(height: 24),

                // 상세 점수
                _buildDetailScores(),
                const SizedBox(height: 20),

                // 격려 메시지
                if (encouragement != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _VerseCardColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _VerseCardColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: _VerseCardColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            encouragement!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 액션 버튼
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCircle() {
    final color = passed ? _VerseCardColors.success : _VerseCardColors.warning;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: color,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${score.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailScores() {
    return Row(
      children: [
        _buildScoreItem('정확도', accuracyScore, const Color(0xFF42A5F5)),
        const SizedBox(width: 12),
        _buildScoreItem('유창성', fluencyScore, const Color(0xFF66BB6A)),
        const SizedBox(width: 12),
        _buildScoreItem('운율', prosodyScore, const Color(0xFFAB47BC)),
      ],
    );
  }

  Widget _buildScoreItem(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('다시 시도'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (passed && onNextStage != null) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onNextStage,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: const Text(
                '다음 단계',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _VerseCardColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
