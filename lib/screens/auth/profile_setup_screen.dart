import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';
import '../home/main_menu_screen.dart';

/// 프로필 설정 화면
/// - 이름 입력
/// - 그룹 선택
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
  final _nameController = TextEditingController();
  final _groupService = GroupService();

  String? _selectedGroupId;
  List<GroupModel> _groups = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await _groupService.getGroups();
    setState(() {
      _groups = groups;
      _isLoading = false;
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

    final user = await widget.authService.registerAnonymous(
      name: name,
      groupId: _selectedGroupId!,
    );

    if (user != null && mounted) {
      // 메인 화면으로 이동 (뒤로가기 방지)
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.menu_book, size: 80, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        '바이블 스픽',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '영어 성경 암송 챌린지',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 48),

                      // 이름 입력
                      _buildNameInput(),
                      const SizedBox(height: 16),

                      // 그룹 선택
                      _buildGroupSelector(),
                      const SizedBox(height: 32),

                      // 시작 버튼
                      _buildSubmitButton(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNameInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 이름 (닉네임)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '예: 김철수, 은혜, 믿음이',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.person),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 그룹 선택',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),
          _groups.isEmpty
              ? const Text('그룹을 불러오는 중...', style: TextStyle(color: Colors.grey))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _groups.map((group) {
                    final isSelected = _selectedGroupId == group.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedGroupId = group.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.indigo : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              group.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              '${group.memberCount}명',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white70 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(
              '암송 시작하기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
