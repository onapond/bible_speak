import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/data_preloader_service.dart';
import 'auth/login_screen.dart';
import 'home/main_menu_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// 스플래시 화면
/// - 인증 상태 확인
/// - 로그인/메인 화면 분기
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
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
            // OnboardingScreen 완료 후 로그인 화면으로
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LoginScreen(authService: _authService),
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
        builder: (_) => LoginScreen(authService: _authService),
      ),
    );
  }

  Future<void> _checkAuthStatus() async {
    // 인증 상태와 온보딩 확인 병렬 실행 (딜레이 제거)
    final List<bool> results = await Future.wait<bool>([
      _authService.init(),
      isOnboardingCompleted(),
    ]).timeout(
      const Duration(seconds: 5),
      onTimeout: () => [false, false], // 타임아웃 시 기본값
    );

    final isLoggedIn = results[0];
    final onboardingDone = results[1];

    if (!mounted) return;

    // 로그인되지 않은 경우 - 온보딩 또는 로그인
    if (!isLoggedIn) {
      if (!onboardingDone) {
        // 온보딩 먼저 표시
        _navigateToOnboarding();
      } else {
        // 온보딩 완료 - 로그인 화면으로
        _navigateToLogin();
      }
    } else {
      // 로그인된 경우 - 데이터 프리로드 시작 후 메인 화면으로
      // 백그라운드에서 프리로드 시작 (결과 기다리지 않음)
      _preloader.preloadMainScreenData();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainMenuScreen(authService: _authService),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade700, Colors.indigo.shade400],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                '바이블 스픽',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '영어 성경 암송 튜터',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 48),
              CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
