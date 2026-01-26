import 'package:flutter/material.dart';
import '../../models/subscription.dart';
import '../../services/iap_service.dart';

/// 구독 화면
/// - 프리미엄 기능 소개
/// - 월간/연간 구독 선택
/// - 구매 및 복원
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final IAPService _iapService = IAPService();
  SubscriptionPlan _selectedPlan = SubscriptionPlan.yearly;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _initIAP();
  }

  Future<void> _initIAP() async {
    await _iapService.init();
    setState(() => _isLoading = false);

    // 구독 상태 변경 리스닝
    _iapService.subscriptionStream.listen((subscription) {
      if (subscription.isPremium && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프리미엄 구독이 활성화되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _iapService.dispose();
    super.dispose();
  }

  Future<void> _purchase() async {
    if (_isPurchasing) return;

    setState(() => _isPurchasing = true);

    final success = await _iapService.purchase(_selectedPlan);

    if (!success && mounted) {
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_iapService.lastError ?? '결제를 시작할 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
    final success = await _iapService.restorePurchases();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '구매 복원을 시도합니다.' : _iapService.lastError ?? '복원 실패'),
          backgroundColor: success ? Colors.blue : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // 헤더
                  SliverToBoxAdapter(child: _buildHeader()),

                  // 프리미엄 기능 목록
                  SliverToBoxAdapter(child: _buildFeatures()),

                  // 플랜 선택
                  SliverToBoxAdapter(child: _buildPlanSelection()),

                  // 구매 버튼
                  SliverToBoxAdapter(child: _buildPurchaseButton()),

                  // 하단 정보
                  SliverToBoxAdapter(child: _buildFooter()),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 닫기 버튼
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          const SizedBox(height: 16),

          // 프리미엄 아이콘
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              size: 48,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          // 제목
          const Text(
            '바이블 스픽 프리미엄',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          // 부제목
          Text(
            'AI 튜터와 함께하는 무제한 영어 성경 암송',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha:0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: PremiumFeature.all.map((feature) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      feature.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feature.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha:0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // 체크 아이콘
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlanSelection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 연간 플랜
          _buildPlanCard(
            plan: SubscriptionPlan.yearly,
            isSelected: _selectedPlan == SubscriptionPlan.yearly,
            badge: '${SubscriptionPlan.yearly.discountPercent}% 할인',
          ),

          const SizedBox(height: 12),

          // 월간 플랜
          _buildPlanCard(
            plan: SubscriptionPlan.monthly,
            isSelected: _selectedPlan == SubscriptionPlan.monthly,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required bool isSelected,
    String? badge,
  }) {
    final product = _iapService.getProduct(plan);
    final priceString = product?.price ?? '₩${plan.priceKRW.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D2D44) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha:0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 라디오 버튼
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha:0.4),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: CircleAvatar(
                        radius: 6,
                        backgroundColor: Color(0xFFFFD700),
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 16),

            // 플랜 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan == SubscriptionPlan.yearly
                        ? '월 ₩${plan.monthlyEquivalent.toString().replaceAllMapped(
                            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )}원 상당'
                        : '매월 자동 갱신',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha:0.6),
                    ),
                  ),
                ],
              ),
            ),

            // 가격
            Text(
              priceString,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 구매 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isPurchasing ? null : _purchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isPurchasing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    )
                  : const Text(
                      '프리미엄 시작하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // 구매 복원
          TextButton(
            onPressed: _restorePurchases,
            child: Text(
              '이전 구매 복원',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha:0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 약관 안내
          Text(
            '구독은 현재 기간이 끝나기 최소 24시간 전에 자동 갱신이 해제되지 않으면 자동으로 갱신됩니다. '
            '구독 및 자동 갱신은 구매 후 계정 설정에서 관리할 수 있습니다.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha:0.4),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // 링크
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  // TODO: 이용약관 페이지
                },
                child: Text(
                  '이용약관',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha:0.5),
                  ),
                ),
              ),
              Text(
                '|',
                style: TextStyle(color: Colors.white.withValues(alpha:0.3)),
              ),
              TextButton(
                onPressed: () {
                  // TODO: 개인정보처리방침 페이지
                },
                child: Text(
                  '개인정보처리방침',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha:0.5),
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
