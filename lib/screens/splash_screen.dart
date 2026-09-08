import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_state.dart';
import '../models/startup_destination.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';
import '../services/data_preloader_service.dart';
import '../styles/parchment_theme.dart';
import 'auth/login_screen.dart';
import 'auth/profile_setup_screen.dart';
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
  var _didNavigate = false;
  var _routingEpoch = 0;

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

  void _navigateToProfileSetup() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(),
      ),
    );
  }

  Future<void> _routeForSession(SessionState session) async {
    final operation = ++_routingEpoch;
    await Future<void>.delayed(Duration.zero);

    var onboardingCompleted = false;
    if (session.status == SessionStatus.signedOut) {
      try {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      } catch (error) {
        debugPrint('❌ 온보딩 상태 확인 오류: $error');
      }
    }

    if (!mounted || _didNavigate || operation != _routingEpoch) return;

    final destination = resolveSessionStartupDestination(
      session: session,
      onboardingCompleted: onboardingCompleted,
    );
    if (destination == null) return;

    _didNavigate = true;

    switch (destination) {
      case StartupDestination.onboarding:
        _navigateToOnboarding();
        return;
      case StartupDestination.login:
        _navigateToLogin();
        return;
      case StartupDestination.profileSetup:
        _navigateToProfileSetup();
        return;
      case StartupDestination.mainMenu:
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
    final session = ref.watch(sessionNotifierProvider);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_routeForSession(session)),
    );

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

              if (session.status == SessionStatus.recoverableError) ...[
                const Text(
                  '연결을 확인하며 로그인 정보를 복구하고 있어요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: ParchmentTheme.weatheredGray,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.read(sessionNotifierProvider.notifier).refreshUser(),
                  child: const Text('다시 시도'),
                ),
                const SizedBox(height: 8),
              ],

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
