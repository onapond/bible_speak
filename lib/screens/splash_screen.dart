import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/data_preloader_service.dart';
import '../styles/parchment_theme.dart';
import 'auth/login_screen.dart';
import 'home/main_menu_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'onboarding/goal_setup_screen.dart';

/// 스플래시 화면
/// - 인증 상태 확인
/// - 로그인/메인 화면 분기
/// - 라이트 테마 + 골드 글로우 아이콘 + 정적 로딩 점
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final DataPreloaderService _preloader = DataPreloaderService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _navigateToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => OnboardingScreen(
          onComplete: () {
            // OnboardingScreen 완료 후 목표 설정 화면으로
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(
                builder: (goalCtx) => GoalSetupScreen(
                  onComplete: () {
                    // 목표 설정 완료 후 로그인 화면으로
                    Navigator.of(goalCtx).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  Future<void> _checkAuthStatus() async {
    bool isLoggedIn = false;
    bool onboardingDone = false;

    try {
      // 로컬 상태만 확인 (네트워크 호출 없음 - 빠름)
      final prefs = await SharedPreferences.getInstance();
      onboardingDone = prefs.getBool('onboarding_completed') ?? false;

      final savedUserId = prefs.getString('bible_speak_userId');
      final authService = ref.read(authServiceProvider);
      final hasFirebaseUser = authService.firebaseUser != null;
      isLoggedIn = savedUserId != null && hasFirebaseUser;
    } catch (e) {
      debugPrint('❌ 인증 상태 확인 오류: $e');
    }

    if (!mounted) return;

    // 로그인되지 않은 경우 - 온보딩 또는 로그인
    if (!isLoggedIn) {
      if (!onboardingDone) {
        _navigateToOnboarding();
      } else {
        _navigateToLogin();
      }
    } else {
      // 로그인된 경우 - Riverpod Provider가 자동으로 초기화
      _preloader.preloadMainScreenData();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainMenuScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ParchmentTheme.softPapyrus,
              ParchmentTheme.agedParchment,
              ParchmentTheme.warmVellum,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 골드 글로우 아이콘
              _buildGlowIcon(),
              const SizedBox(height: 24),

              // 앱 이름
              const Text(
                '바이블 스픽',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ParchmentTheme.ancientInk,
                ),
              ),
              const SizedBox(height: 8),

              // 서브 타이틀
              const Text(
                '영어 성경 암송 튜터',
                style: TextStyle(
                  fontSize: 14,
                  color: ParchmentTheme.weatheredGray,
                ),
              ),
              const SizedBox(height: 48),

              // 로딩 점
              _buildLoadingDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlowIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.4),
            blurRadius: 28,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ParchmentTheme.softPapyrus,
          border: Border.all(
            color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.menu_book,
            size: 48,
            color: ParchmentTheme.manuscriptGold,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

}
