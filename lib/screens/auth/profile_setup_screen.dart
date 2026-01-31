import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../home/main_menu_screen.dart';
import '../group/group_select_screen.dart';

/// 프로필 설정 화면 (개선된 다크 테마)
/// - 이름 입력
/// - 그룹 선택/생성/코드 가입
class ProfileSetupScreen extends StatefulWidget {
  final AuthService authService;

  const ProfileSetupScreen({
    super.key,
    required this.authService,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final _nameController = TextEditingController();
  final _groupService = GroupService();

  String? _selectedGroupId;
  String? _selectedGroupName;
  bool _isSubmitting = false;

  void _onGroupSelected(String groupId, String groupName) {
    setState(() {
      _selectedGroupId = groupId;
      _selectedGroupName = groupName;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('이름을 입력해주세요');
      return;
    }

    if (_selectedGroupId == null) {
      _showError('그룹을 선택해주세요');
      return;
    }

    setState(() => _isSubmitting = true);

    // completeProfile 사용 (Google/Apple 로그인 사용자의 프로필 완성)
    final user = await widget.authService.completeProfile(
      name: name,
      groupId: _selectedGroupId!,
    );

    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainMenuScreen(authService: widget.authService),
        ),
      );
    } else {
      _showError('등록 중 오류가 발생했습니다');
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // 로고 영역
              _buildHeader(),
              const SizedBox(height: 32),

              // 이름 입력
              _buildNameInput(),
              const SizedBox(height: 20),

              // 그룹 선택 (새로운 컴포넌트)
              GroupSelectScreen(onGroupSelected: _onGroupSelected),
              const SizedBox(height: 24),

              // 선택된 그룹 표시
              if (_selectedGroupName != null) _buildSelectedGroupBadge(),
              const SizedBox(height: 16),

              // 시작 버튼
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.menu_book, size: 48, color: _accentColor),
        ),
        const SizedBox(height: 16),
        const Text(
          '바이블 스픽',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '영어 성경 암송 챌린지',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedGroupBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택된 그룹',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
                Text(
                  _selectedGroupName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: _accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '내 이름 (닉네임)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '예: 김철수, 은혜, 믿음이',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: _bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _nameController.text.trim().isNotEmpty && _selectedGroupId != null;

    return ElevatedButton(
      onPressed: _isSubmitting || !canSubmit ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: canSubmit ? _accentColor : Colors.grey.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow),
                const SizedBox(width: 8),
                const Text(
                  '암송 시작하기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
