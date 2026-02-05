import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 온보딩 색상 팔레트 (Warm Parchment Light Theme)
class OnboardingColors {
  // 배경 (양피지 그라데이션)
  static const softPapyrus = Color(0xFFFDF8F3);    // 가장 밝은
  static const agedParchment = Color(0xFFF5EFE6);  // 메인 배경
  static const warmVellum = Color(0xFFEDE4D3);     // 카드 배경

  // 테두리/그림자
  static const antiqueEdge = Color(0xFFD4C4A8);    // 테두리
  static const sepiaShadow = Color(0xFFC9B896);    // 그림자

  // 텍스트 (잉크)
  static const ancientInk = Color(0xFF3D3229);     // 제목
  static const fadedScript = Color(0xFF6B5D4D);    // 본문
  static const weatheredGray = Color(0xFF8C7E6D);  // 보조

  // 악센트 (금박)
  static const manuscriptGold = Color(0xFFC9A857); // 주요 CTA
  static const scriptureGold = Color(0xFFB8860B);  // 성경 구절

  // 배경 그라데이션
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [softPapyrus, agedParchment, warmVellum],
    stops: [0.0, 0.5, 1.0],
  );
}

/// 온보딩 페이지 데이터
class _OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final String verseText;
  final String verseReference;

  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.verseText,
    required this.verseReference,
  });
}

/// 온보딩 화면 (Paper & Typography 디자인)
/// - 라이트 테마 (양피지 느낌)
/// - 4페이지 구성 + 영어 성경 구절 카드
/// - Cardo (영문 구절), NotoSerifKR (한글 제목)
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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: '말씀으로 성장하는\n매일의 여정',
      description: '바이블 스픽과 함께 영어 성경을 입으로 외워보세요',
      icon: Icons.auto_stories_outlined,
      verseText: '"Thy word is a lamp unto my feet, and a light unto my path."',
      verseReference: 'Psalm 119:105',
    ),
    _OnboardingPageData(
      title: '듣고 따라하며\n자연스럽게',
      description: '원어민 발음을 듣고 AI 코칭으로 발음을 교정해요',
      icon: Icons.graphic_eq_outlined,
      verseText: '"Faith comes by hearing, and hearing by the word of God."',
      verseReference: 'Romans 10:17',
    ),
    _OnboardingPageData(
      title: '달란트를 모아\n성장의 기쁨을',
      description: '매일 학습하고 퀴즈에 도전해 보상을 받으세요',
      icon: Icons.monetization_on_outlined,
      verseText: '"Well done, good and faithful servant."',
      verseReference: 'Matthew 25:21',
    ),
    _OnboardingPageData(
      title: '함께하면\n더 멀리',
      description: '그룹 챌린지와 격려로 꾸준함을 유지해요',
      icon: Icons.hub_outlined,
      verseText: '"Two are better than one."',
      verseReference: 'Ecclesiastes 4:9',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
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
    _fadeController.reset();
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: OnboardingColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 건너뛰기 버튼
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8),
                  child: TextButton(
                    onPressed: _skipOnboarding,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      '건너뛰기',
                      style: TextStyle(
                        color: OnboardingColors.weatheredGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                    return _buildPage(_pages[index]);
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
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData page) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 라인 아이콘
              _buildLineIcon(page.icon),
              const SizedBox(height: 40),

              // 제목 (NotoSerifKR)
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerifKr(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.ancientInk,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // 설명
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: OnboardingColors.fadedScript,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              // 성경 구절 카드
              _buildVerseCard(page.verseText, page.verseReference),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineIcon(IconData icon) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: OnboardingColors.warmVellum,
        border: Border.all(
          color: OnboardingColors.antiqueEdge,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: OnboardingColors.sepiaShadow.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 48,
          color: OnboardingColors.fadedScript,
        ),
      ),
    );
  }

  Widget _buildVerseCard(String verseText, String reference) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OnboardingColors.warmVellum,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: OnboardingColors.antiqueEdge,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: OnboardingColors.sepiaShadow.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 영어 성경 구절 (Cardo Italic)
          Text(
            verseText,
            textAlign: TextAlign.center,
            style: GoogleFonts.cardo(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: OnboardingColors.fadedScript,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          // 장절 표시
          Text(
            '— $reference',
            style: GoogleFonts.cardo(
              fontSize: 14,
              color: OnboardingColors.scriptureGold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? OnboardingColors.manuscriptGold
                  : OnboardingColors.antiqueEdge,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final isLastPage = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: OnboardingColors.manuscriptGold,
            foregroundColor: OnboardingColors.ancientInk,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLastPage ? '시작하기' : '다음',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
              ),
            ],
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
