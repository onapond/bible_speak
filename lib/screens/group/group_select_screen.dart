import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';

/// 그룹 선택 화면 (개선된 UI)
/// - 기존 그룹 선택
/// - 새 그룹 생성
/// - 초대 코드로 가입
class GroupSelectScreen extends StatefulWidget {
  final Function(String groupId, String groupName) onGroupSelected;

  const GroupSelectScreen({
    super.key,
    required this.onGroupSelected,
  });

  @override
  State<GroupSelectScreen> createState() => _GroupSelectScreenState();
}

class _GroupSelectScreenState extends State<GroupSelectScreen>
    with SingleTickerProviderStateMixin {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final GroupService _groupService = GroupService();
  final _searchController = TextEditingController();
  final _codeController = TextEditingController();

  late TabController _tabController;
  List<GroupModel> _groups = [];
  List<GroupModel> _filteredGroups = [];
  bool _isLoading = true;
  String? _selectedGroupId;
  GroupModel? _foundGroup;
  bool _isSearchingCode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroups();
    _searchController.addListener(_filterGroups);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await _groupService.getGroups();
    setState(() {
      _groups = groups;
      _filteredGroups = groups;
      _isLoading = false;
    });
  }

  void _filterGroups() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = _groups;
      } else {
        _filteredGroups = _groups
            .where((g) => g.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _searchByCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showSnackBar('6자리 코드를 입력해주세요', isError: true);
      return;
    }

    setState(() => _isSearchingCode = true);

    final group = await _groupService.findGroupByCode(code);

    setState(() {
      _foundGroup = group;
      _isSearchingCode = false;
    });

    if (group == null) {
      _showSnackBar('해당 코드의 그룹을 찾을 수 없습니다', isError: true);
    }
  }

  void _selectGroup(String groupId, String groupName) {
    setState(() => _selectedGroupId = groupId);
    widget.onGroupSelected(groupId, groupName);
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '새 그룹 만들기',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '그룹 이름 (최대 20자)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                filled: true,
                fillColor: _bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.group, color: _accentColor),
              ),
              maxLength: 20,
            ),
            const SizedBox(height: 8),
            Text(
              '그룹을 만들면 초대 코드가 생성됩니다.\n코드를 공유하여 멤버를 초대하세요.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);
              await _createGroup(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup(String name) async {
    setState(() => _isLoading = true);

    final result = await _groupService.createGroupByUser(name: name);

    if (result.success && result.groupId != null) {
      _showSnackBar('그룹이 생성되었습니다!');
      _showInviteCodeDialog(name, result.inviteCode!);
      await _loadGroups();
      _selectGroup(result.groupId!, name);
    } else {
      _showSnackBar(result.message, isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showInviteCodeDialog(String groupName, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              '그룹 생성 완료!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              groupName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '초대 코드',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      _showSnackBar('코드가 복사되었습니다');
                    },
                    icon: const Icon(Icons.copy, color: _accentColor),
                    tooltip: '복사',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '이 코드를 멤버들에게 공유하세요',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups, color: _accentColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '그룹 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '함께 암송할 그룹을 선택하세요',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showCreateGroupDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                  tooltip: '새 그룹 만들기',
                ),
              ],
            ),
          ),

          // 탭바
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: '그룹 목록'),
                Tab(text: '코드 입력'),
                Tab(text: '새로 만들기'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 탭 컨텐츠
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGroupListTab(),
                _buildCodeInputTab(),
                _buildCreateTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupListTab() {
    return Column(
      children: [
        // 검색바
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '그룹 검색...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: _bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 그룹 목록
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _accentColor))
              : _filteredGroups.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? '등록된 그룹이 없습니다'
                            : '검색 결과가 없습니다',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = _filteredGroups[index];
                        final isSelected = _selectedGroupId == group.id;

                        return KeyedSubtree(
                          key: ValueKey(group.id),
                          child: GestureDetector(
                          onTap: () => _selectGroup(group.id, group.name),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _accentColor.withValues(alpha: 0.2)
                                  : _bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? _accentColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _accentColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      group.name.isNotEmpty
                                          ? group.name[0]
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '${group.memberCount}명 · ${group.totalTalants} 탈란트',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: _accentColor,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCodeInputTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '초대 코드를 입력하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),

          // 코드 입력 필드
          TextField(
            controller: _codeController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 8,
              ),
              filled: true,
              fillColor: _bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              counterText: '',
            ),
            onChanged: (value) {
              if (value.length == 6) {
                _searchByCode();
              } else {
                setState(() => _foundGroup = null);
              }
            },
          ),
          const SizedBox(height: 16),

          // 찾기 버튼 또는 결과
          if (_isSearchingCode)
            const CircularProgressIndicator(color: _accentColor)
          else if (_foundGroup != null)
            _buildFoundGroupCard(_foundGroup!)
          else
            ElevatedButton.icon(
              onPressed: _searchByCode,
              icon: const Icon(Icons.search),
              label: const Text('그룹 찾기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoundGroupCard(GroupModel group) {
    final isSelected = _selectedGroupId == group.id;

    return GestureDetector(
      onTap: () => _selectGroup(group.id, group.name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withValues(alpha: 0.2)
              : _bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.green,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${group.memberCount}명 참여 중',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '선택됨',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const Text(
                '탭하여 선택',
                style: TextStyle(
                  fontSize: 12,
                  color: _accentColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.group_add,
              size: 48,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '새 그룹 만들기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '직접 그룹을 만들고\n멤버들을 초대하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text('그룹 만들기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
