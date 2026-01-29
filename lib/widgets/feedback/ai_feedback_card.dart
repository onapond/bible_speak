import 'package:flutter/material.dart';

/// AI 피드백 카드
/// 로딩 상태와 피드백 내용을 명확하게 표시
class AiFeedbackCard extends StatelessWidget {
  final bool isLoading;
  final String? feedback;
  final String? error;
  final VoidCallback? onRetry;

  const AiFeedbackCard({
    super.key,
    this.isLoading = false,
    this.feedback,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor().withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getBorderColor().withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(),
                  color: _getBorderColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitle(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getBorderColor(),
                      ),
                    ),
                    if (isLoading)
                      Text(
                        '분석 중...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6C63FF),
                  ),
                ),
            ],
          ),

          // 콘텐츠
          const SizedBox(height: 12),
          if (isLoading)
            _buildLoadingContent()
          else if (error != null)
            _buildErrorContent()
          else if (feedback != null)
            _buildFeedbackContent()
          else
            _buildEmptyContent(),
        ],
      ),
    );
  }

  Color _getBorderColor() {
    if (error != null) return Colors.orange;
    return const Color(0xFF6C63FF);
  }

  IconData _getIcon() {
    if (error != null) return Icons.info_outline;
    if (isLoading) return Icons.psychology;
    return Icons.lightbulb_outline;
  }

  String _getTitle() {
    if (error != null) return '피드백을 가져올 수 없어요';
    if (isLoading) return 'AI 코치가 분석 중이에요';
    return 'AI 코치의 조언';
  }

  Widget _buildLoadingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerLine(width: double.infinity),
        const SizedBox(height: 8),
        _buildShimmerLine(width: 200),
        const SizedBox(height: 8),
        _buildShimmerLine(width: 250),
      ],
    );
  }

  Widget _buildShimmerLine({required double width}) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '네트워크 문제로 AI 피드백을 가져오지 못했어요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('다시 시도'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeedbackContent() {
    return Text(
      feedback!,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[300],
        height: 1.6,
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Text(
      '피드백이 없습니다.',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[500],
      ),
    );
  }
}

/// 점수 개선 표시 위젯
class ScoreImprovementBadge extends StatelessWidget {
  final double previousScore;
  final double currentScore;

  const ScoreImprovementBadge({
    super.key,
    required this.previousScore,
    required this.currentScore,
  });

  @override
  Widget build(BuildContext context) {
    final diff = currentScore - previousScore;
    final improved = diff > 0;
    final color = improved ? const Color(0xFF4CAF50) : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            improved ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            improved
                ? '+${diff.toInt()}% 향상!'
                : '${diff.toInt()}% (이전: ${previousScore.toInt()}%)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 다음 구절 제안 카드
class NextVerseCard extends StatelessWidget {
  final String? nextVerse;
  final VoidCallback onContinue;
  final VoidCallback onGoBack;

  const NextVerseCard({
    super.key,
    this.nextVerse,
    required this.onContinue,
    required this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.2),
            const Color(0xFF4834D4).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFF6C63FF),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '잘했어요! 다음 구절도 도전해볼까요?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (nextVerse != null) ...[
            const SizedBox(height: 8),
            Text(
              nextVerse!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onGoBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    side: BorderSide(color: Colors.grey[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('목록으로'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '다음 구절',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
