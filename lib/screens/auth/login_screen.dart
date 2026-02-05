import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'profile_setup_screen.dart';
import '../home/main_menu_screen.dart';

/// 로그인 화면 색상 팔레트 (Warm Parchment Light Theme)
class _LoginColors {
  // 배경 (양피지 그라데이션)
  static const softPapyrus = Color(0xFFFDF8F3);
  static const agedParchment = Color(0xFFF5EFE6);
  static const warmVellum = Color(0xFFEDE4D3);

  // 테두리/그림자
  static const antiqueEdge = Color(0xFFD4C4A8);
  static const sepiaShadow = Color(0xFFC9B896);

  // 텍스트 (잉크)
  static const ancientInk = Color(0xFF3D3229);
  static const fadedScript = Color(0xFF6B5D4D);
  static const weatheredGray = Color(0xFF8C7E6D);

  // 악센트 (금박)
  static const manuscriptGold = Color(0xFFC9A857);
}

/// 로그인 화면
/// - Google, Apple, Email 로그인 지원
/// - 라이트 테마 (양피지 스타일)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _isSignUp = false;
  bool _appleAvailable = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAppleAvailability();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkAppleAvailability() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      final authService = ref.read(authServiceProvider);
      final available = await authService.isAppleSignInAvailable();
      if (mounted) {
        setState(() => _appleAvailable = available);
      }
    }
  }

  Future<void> _handleAuthResult(AuthResult result) async {
    if (result.cancelled) {
      return;
    }

    if (!result.success) {
      _showError(result.errorMessage ?? '로그인에 실패했습니다.');
      return;
    }

    if (result.needsProfile) {
      // 신규 사용자 - 프로필 설정으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ProfileSetupScreen(),
          ),
        );
      }
    } else {
      // 기존 사용자 - 메인으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const MainMenuScreen(),
          ),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final result = await authNotifier.signInWithGoogle();
    setState(() => _isLoading = false);
    await _handleAuthResult(result);
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final result = await authNotifier.signInWithApple();
    setState(() => _isLoading = false);
    await _handleAuthResult(result);
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    final authNotifier = ref.read(authNotifierProvider.notifier);
    AuthResult result;
    if (_isSignUp) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _showError('이름을 입력해주세요.');
        setState(() => _isLoading = false);
        return;
      }
      result = await authNotifier.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
    } else {
      result = await authNotifier.signInWithEmail(
        email: email,
        password: password,
      );
    }

    setState(() => _isLoading = false);
    await _handleAuthResult(result);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('비밀번호를 재설정할 이메일을 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    final result = await authService.sendPasswordResetEmail(email);
    setState(() => _isLoading = false);

    if (result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('비밀번호 재설정 이메일을 발송했습니다.'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      _showError(result.errorMessage ?? '이메일 발송에 실패했습니다.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              _LoginColors.softPapyrus,
              _LoginColors.agedParchment,
              _LoginColors.warmVellum,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고 & 타이틀
                  _buildHeader(),
                  const SizedBox(height: 48),

                  // 로그인 버튼들
                  if (_showEmailForm)
                    _buildEmailForm()
                  else
                    _buildSocialButtons(),

                  const SizedBox(height: 24),

                  // 하단 링크
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _LoginColors.softPapyrus,
            border: Border.all(
              color: _LoginColors.manuscriptGold.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _LoginColors.manuscriptGold.withValues(alpha: 0.4),
                blurRadius: 28,
                spreadRadius: 6,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.menu_book,
              size: 48,
              color: _LoginColors.manuscriptGold,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '바이블 스픽',
          style: GoogleFonts.notoSerifKr(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: _LoginColors.ancientInk,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'AI 발음 코칭으로 영어 성경 암송',
          style: TextStyle(
            fontSize: 16,
            color: _LoginColors.weatheredGray,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        // Google 로그인
        _buildSocialButton(
          onTap: _isLoading ? null : _signInWithGoogle,
          icon: 'G',
          iconColor: Colors.red,
          label: 'Google로 계속하기',
          backgroundColor: Colors.white,
          textColor: _LoginColors.ancientInk,
        ),
        const SizedBox(height: 12),

        // Apple 로그인 (iOS/macOS만)
        if (_appleAvailable) ...[
          _buildSocialButton(
            onTap: _isLoading ? null : _signInWithApple,
            icon: '',
            label: 'Apple로 계속하기',
            backgroundColor: Colors.white,
            textColor: _LoginColors.ancientInk,
            useAppleIcon: true,
          ),
          const SizedBox(height: 12),
        ],

        // 이메일 로그인
        _buildSocialButton(
          onTap: _isLoading
              ? null
              : () => setState(() => _showEmailForm = true),
          icon: '@',
          iconColor: _LoginColors.manuscriptGold,
          label: '이메일로 계속하기',
          backgroundColor: _LoginColors.warmVellum,
          textColor: _LoginColors.ancientInk,
          hasBorder: true,
        ),

        if (_isLoading) ...[
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: _LoginColors.manuscriptGold),
        ],
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onTap,
    required String icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? iconColor,
    bool useAppleIcon = false,
    bool hasBorder = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: hasBorder
                ? const BorderSide(color: _LoginColors.antiqueEdge, width: 1)
                : BorderSide.none,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (useAppleIcon)
              const Icon(Icons.apple, size: 24)
            else
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconColor ?? textColor,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _LoginColors.softPapyrus,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _LoginColors.antiqueEdge,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _LoginColors.sepiaShadow.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _showEmailForm = false;
                  _isSignUp = false;
                }),
                icon: const Icon(Icons.arrow_back, color: _LoginColors.ancientInk),
              ),
              Text(
                _isSignUp ? '회원가입' : '이메일 로그인',
                style: GoogleFonts.notoSerifKr(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _LoginColors.ancientInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 이름 (회원가입만)
          if (_isSignUp) ...[
            TextField(
              controller: _nameController,
              style: const TextStyle(color: _LoginColors.ancientInk),
              decoration: _inputDecoration('이름', Icons.person),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
          ],

          // 이메일
          TextField(
            controller: _emailController,
            style: const TextStyle(color: _LoginColors.ancientInk),
            decoration: _inputDecoration('이메일', Icons.email),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // 비밀번호
          TextField(
            controller: _passwordController,
            style: const TextStyle(color: _LoginColors.ancientInk),
            decoration: _inputDecoration('비밀번호', Icons.lock),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signInWithEmail(),
          ),
          const SizedBox(height: 24),

          // 로그인/회원가입 버튼
          ElevatedButton(
            onPressed: _isLoading ? null : _signInWithEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: _LoginColors.manuscriptGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isSignUp ? '가입하기' : '로그인',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // 전환 링크
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isSignUp ? '이미 계정이 있으신가요?' : '계정이 없으신가요?',
                style: const TextStyle(color: _LoginColors.fadedScript),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? '로그인' : '회원가입',
                  style: const TextStyle(color: _LoginColors.manuscriptGold),
                ),
              ),
            ],
          ),

          // 비밀번호 찾기 (로그인만)
          if (!_isSignUp)
            TextButton(
              onPressed: _resetPassword,
              child: const Text(
                '비밀번호를 잊으셨나요?',
                style: TextStyle(
                  color: _LoginColors.weatheredGray,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _LoginColors.fadedScript.withValues(alpha: 0.6)),
      prefixIcon: Icon(icon, color: _LoginColors.manuscriptGold),
      filled: true,
      fillColor: _LoginColors.warmVellum,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _LoginColors.antiqueEdge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _LoginColors.antiqueEdge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _LoginColors.manuscriptGold, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        if (!_showEmailForm) ...[
          Text(
            '계속 진행하면 서비스 이용약관 및\n개인정보 처리방침에 동의하는 것으로 간주됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _LoginColors.weatheredGray.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 게스트 모드 (테스트용)
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const ProfileSetupScreen(),
              ),
            );
          },
          child: const Text(
            '게스트로 시작하기',
            style: TextStyle(
              color: _LoginColors.weatheredGray,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
