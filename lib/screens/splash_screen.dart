import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth/profile_setup_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // 잠시 스플래시 표시
    await Future.delayed(const Duration(milliseconds: 1500));

    // 인증 상태 확인
    final isLoggedIn = await _authService.init();
    final onboardingDone = await isOnboardingCompleted();

    if (!mounted) return;

    // 로그인되지 않은 경우 - 온보딩 또는 프로필 설정
    if (!isLoggedIn) {
      if (!onboardingDone) {
        // 온보딩 먼저 표시
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingScreen(
              onComplete: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ProfileSetupScreen(authService: _authService),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // 온보딩 완료 - 프로필 설정으로
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(authService: _authService),
          ),
        );
      }
    } else {
      // 로그인된 경우 - 메인 화면으로
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
