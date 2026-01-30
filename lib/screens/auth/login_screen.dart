import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'profile_setup_screen.dart';
import '../home/main_menu_screen.dart';

/// 로그인 화면
/// - Google, Apple, Email 로그인 지원
class LoginScreen extends StatefulWidget {
  final AuthService authService;

  const LoginScreen({
    super.key,
    required this.authService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

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
      final available = await widget.authService.isAppleSignInAvailable();
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
            builder: (_) => ProfileSetupScreen(authService: widget.authService),
          ),
        );
      }
    } else {
      // 기존 사용자 - 메인으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MainMenuScreen(authService: widget.authService),
          ),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final result = await widget.authService.signInWithGoogle();
    setState(() => _isLoading = false);
    await _handleAuthResult(result);
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    final result = await widget.authService.signInWithApple();
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

    AuthResult result;
    if (_isSignUp) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _showError('이름을 입력해주세요.');
        setState(() => _isLoading = false);
        return;
      }
      result = await widget.authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
    } else {
      result = await widget.authService.signInWithEmail(
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
    final result = await widget.authService.sendPasswordResetEmail(email);
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
      backgroundColor: _bgColor,
      body: SafeArea(
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
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.menu_book,
            size: 64,
            color: _accentColor,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '바이블 스픽',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AI 발음 코칭으로 영어 성경 암송',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.7),
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
          textColor: Colors.black87,
        ),
        const SizedBox(height: 12),

        // Apple 로그인 (iOS/macOS만)
        if (_appleAvailable) ...[
          _buildSocialButton(
            onTap: _isLoading ? null : _signInWithApple,
            icon: '',
            label: 'Apple로 계속하기',
            backgroundColor: Colors.white,
            textColor: Colors.black87,
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
          iconColor: _accentColor,
          label: '이메일로 계속하기',
          backgroundColor: _cardColor,
          textColor: Colors.white,
        ),

        if (_isLoading) ...[
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: _accentColor),
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
          ),
          elevation: 0,
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
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
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Text(
                _isSignUp ? '회원가입' : '이메일 로그인',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 이름 (회원가입만)
          if (_isSignUp) ...[
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('이름', Icons.person),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
          ],

          // 이메일
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('이메일', Icons.email),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // 비밀번호
          TextField(
            controller: _passwordController,
            style: const TextStyle(color: Colors.white),
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
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? '로그인' : '회원가입',
                  style: const TextStyle(color: _accentColor),
                ),
              ),
            ],
          ),

          // 비밀번호 찾기 (로그인만)
          if (!_isSignUp)
            TextButton(
              onPressed: _resetPassword,
              child: Text(
                '비밀번호를 잊으셨나요?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
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
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, color: _accentColor),
      filled: true,
      fillColor: _bgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
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
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 게스트 모드 (테스트용)
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ProfileSetupScreen(authService: widget.authService),
              ),
            );
          },
          child: Text(
            '게스트로 시작하기',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
