import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../screens/subscription/subscription_screen.dart';

/// 프리미엄 콘텐츠 접근 시 표시되는 페이월 다이얼로그
class PaywallDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final PaywallReason reason;

  const PaywallDialog({
    super.key,
    this.title,
    this.message,
    this.reason = PaywallReason.premiumContent,
  });

  /// 다이얼로그 표시
  static Future<bool?> show(
    BuildContext context, {
    String? title,
    String? message,
    PaywallReason reason = PaywallReason.premiumContent,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaywallDialog(
        title: title,
        message: message,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들 바
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          // 아이콘
          _buildIcon(),

          const SizedBox(height: 20),

          // 제목
          Text(
            title ?? _getDefaultTitle(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // 메시지
          Text(
            message ?? _getDefaultMessage(),
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha:0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // 프리미엄 혜택 미리보기
          _buildBenefitPreview(),

          const SizedBox(height: 24),

          // 프리미엄 버튼
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => _openSubscription(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '프리미엄으로 업그레이드',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 취소 버튼
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '나중에',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha:0.6),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (reason) {
      case PaywallReason.dailyLimitReached:
        icon = Icons.hourglass_empty;
        color = const Color(0xFFFF9800);
        break;
      case PaywallReason.premiumContent:
        icon = Icons.lock;
        color = const Color(0xFFFFD700);
        break;
      case PaywallReason.advancedFeature:
        icon = Icons.star;
        color = const Color(0xFF9C27B0);
        break;
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 36, color: color),
    );
  }

  String _getDefaultTitle() {
    switch (reason) {
      case PaywallReason.dailyLimitReached:
        return '오늘의 무료 학습을 완료했어요';
      case PaywallReason.premiumContent:
        return '프리미엄 콘텐츠입니다';
      case PaywallReason.advancedFeature:
        return '프리미엄 기능입니다';
    }
  }

  String _getDefaultMessage() {
    switch (reason) {
      case PaywallReason.dailyLimitReached:
        return '무료 버전은 하루 ${FreeTierLimits.dailyVerseLimit}구절까지 학습할 수 있어요.\n'
            '프리미엄으로 무제한 학습하세요!';
      case PaywallReason.premiumContent:
        return '이 콘텐츠는 프리미엄 구독자만 이용할 수 있어요.\n'
            '모든 성경 콘텐츠를 잠금 해제하세요!';
      case PaywallReason.advancedFeature:
        return '이 기능은 프리미엄 구독자 전용이에요.\n'
            '더 강력한 학습 도구를 사용해보세요!';
    }
  }

  Widget _buildBenefitPreview() {
    final benefits = [
      ('무제한 학습', Icons.all_inclusive),
      ('전체 성경', Icons.menu_book),
      ('상세 분석', Icons.analytics),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: benefits.map((benefit) {
        return Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                benefit.$2,
                color: const Color(0xFFFFD700),
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              benefit.$1,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha:0.7),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _openSubscription(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

/// 페이월 표시 이유
enum PaywallReason {
  dailyLimitReached,
  premiumContent,
  advancedFeature,
}

/// 간편 페이월 체크 함수
class PaywallGuard {
  /// 프리미엄 콘텐츠 접근 체크
  static Future<bool> checkPremiumContent(
    BuildContext context, {
    required bool isPremium,
    required String bookId,
    required int chapter,
  }) async {
    // 프리미엄 사용자는 통과
    if (isPremium) return true;

    // 무료 콘텐츠는 통과
    if (FreeTierLimits.isChapterFree(bookId, chapter)) {
      return true;
    }

    // 유료 콘텐츠 접근 시 페이월
    await PaywallDialog.show(
      context,
      reason: PaywallReason.premiumContent,
    );
    return false;
  }

  /// 일일 제한 체크
  static Future<bool> checkDailyLimit(
    BuildContext context, {
    required bool isPremium,
    required int todayCount,
  }) async {
    // 프리미엄 사용자는 통과
    if (isPremium) return true;

    // 일일 제한 미달 시 통과
    if (todayCount < FreeTierLimits.dailyVerseLimit) {
      return true;
    }

    // 제한 도달 시 페이월
    await PaywallDialog.show(
      context,
      reason: PaywallReason.dailyLimitReached,
    );
    return false;
  }

  /// 고급 기능 체크
  static Future<bool> checkAdvancedFeature(
    BuildContext context, {
    required bool isPremium,
    String? featureName,
  }) async {
    if (isPremium) return true;

    await PaywallDialog.show(
      context,
      title: featureName != null ? '$featureName 기능' : null,
      reason: PaywallReason.advancedFeature,
    );
    return false;
  }
}
