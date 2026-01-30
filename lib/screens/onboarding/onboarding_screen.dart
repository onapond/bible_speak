import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 온보딩 페이지 데이터
class OnboardingPage {
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final List<String>? features;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    this.features,
  });
}

/// 온보딩 화면 (애니메이션 개선)
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _bgColor = Color(0xFF0F0F1A);

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 애니메이션 컨트롤러
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      title: '바이블 스픽에 오신 것을\n환영합니다!',
      description: '성경 구절을 효과적으로 암송하고\n말씀과 함께 성장하세요',
      emoji: '📖',
      color: Color(0xFF6C63FF),
      features: ['AI 발음 코칭', '원어민 음성 지원', '체계적인 암송 시스템'],
    ),
    OnboardingPage(
      title: '음성으로 암송하세요',
      description: '원어민 발음을 듣고 따라하며\n자연스럽게 구절을 외워보세요',
      emoji: '🎙️',
      color: Color(0xFF00B4D8),
      features: ['원어민 TTS 발음', '음성 인식 피드백', '발음 점수 제공'],
    ),
    OnboardingPage(
      title: '매일 퀴즈에 도전하세요',
      description: '일일 퀴즈로 암송을 복습하고\n탈란트 보상을 받으세요',
      emoji: '🎯',
      color: Color(0xFFFF6B35),
      features: ['매일 새로운 퀴즈', '탈란트 보상 시스템', '학습 통계 제공'],
    ),
    OnboardingPage(
      title: '그룹과 함께 성장하세요',
      description: '그룹원들과 함께 목표를 달성하고\n서로 격려하며 성장하세요',
      emoji: '👥',
      color: Color(0xFF2D6A4F),
      features: ['그룹 챌린지', '실시간 랭킹', '친구와 1:1 대결'],
    ),
    OnboardingPage(
      title: '꾸준함이 실력이 됩니다',
      description: '매일 연속 학습하면\n특별한 보상이 기다립니다',
      emoji: '🔥',
      color: Color(0xFFFF8C00),
      features: ['연속 학습 스트릭', '얼리버드 보너스', '목표 달성 리워드'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // 이모지 펄스 애니메이션
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 페이지 전환 시 페이드 애니메이션
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    // 페이지 전환 시 페이드 애니메이션 재시작
    _fadeController.reset();
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 스킵 버튼
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    '건너뛰기',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // 페이지 콘텐츠
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildAnimatedPage(_pages[index], index);
                },
              ),
            ),

            // 페이지 인디케이터
            _buildPageIndicator(),

            // 다음/시작 버튼
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedPage(OnboardingPage page, int index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double pageOffset = 0;
        if (_pageController.position.haveDimensions) {
          pageOffset = _pageController.page! - index;
        }

        // 패럴랙스 효과
        final parallaxOffset = pageOffset * 100;
        final opacity = (1 - pageOffset.abs()).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(parallaxOffset, 0),
            child: _buildPageContent(page, index),
          ),
        );
      },
    );
  }

  Widget _buildPageContent(OnboardingPage page, int index) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 애니메이션 이모지
            _buildAnimatedEmoji(page),
            const SizedBox(height: 40),

            // 타이틀 (슬라이드 인 효과)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(_fadeAnimation),
              child: Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 설명
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(_fadeAnimation),
              child: Text(
                page.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),

            // 기능 리스트 (있는 경우)
            if (page.features != null) ...[
              const SizedBox(height: 32),
              _buildFeatureList(page.features!, page.color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedEmoji(OnboardingPage page) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              page.color.withValues(alpha: 0.3),
              page.color.withValues(alpha: 0.1),
              page.color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: page.color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 60),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList(List<String> features, Color color) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.7),
        end: Offset.zero,
      ).animate(_fadeAnimation),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 100)),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(20 * (1 - value), 0),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      feature,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _pages.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? _pages[index].color
                  : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
              boxShadow: _currentPage == index
                  ? [
                      BoxShadow(
                        color: _pages[index].color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final isLastPage = _currentPage == _pages.length - 1;
    final currentColor = _pages[_currentPage].color;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                currentColor,
                currentColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: currentColor.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _nextPage,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLastPage ? '시작하기' : '다음',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLastPage) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 온보딩 완료 여부 확인
Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
}

/// 온보딩 상태 초기화 (테스트용)
Future<void> resetOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('onboarding_completed');
}
