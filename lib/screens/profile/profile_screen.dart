import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/shop_item.dart';
import '../../services/auth_service.dart';
import '../../services/shop_service.dart';
import '../shop/shop_screen.dart';
import '../shop/inventory_screen.dart';
import '../settings/notification_settings_screen.dart';

/// 프로필 화면
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 다크 테마 상수
  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  final AuthService _authService = AuthService();
  final ShopService _shopService = ShopService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _user;
  Map<String, dynamic> _stats = {};
  List<InventoryItem> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _user = _authService.currentUser;

      if (_user != null) {
        // 통계 로드
        await _loadStats();

        // 뱃지 로드
        _badges = await _shopService.getInventoryByCategory(ShopCategory.badge);
      }
    } catch (e) {
      print('Load profile data error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    if (_user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      final data = userDoc.data() ?? {};

      final streakData = data['streak'] as Map<String, dynamic>? ?? {};

      _stats = {
        'currentStreak': streakData['currentStreak'] ?? 0,
        'longestStreak': streakData['longestStreak'] ?? 0,
        'totalStudyDays': streakData['totalStudyDays'] ?? 0,
        'completedVerses': (_user!.completedVerses).length,
        'totalTalants': _user!.talants,
        'memberSince': _user!.createdAt,
      };
    } catch (e) {
      print('Load stats error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '프로필',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _accentColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildLevelCard(),
                  const SizedBox(height: 16),
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  _buildBadgesCard(),
                  const SizedBox(height: 16),
                  _buildMenuCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // 아바타
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor, _accentColor.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _user?.name.isNotEmpty == true ? _user!.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // 이름 및 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.name ?? '사용자',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor().withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getRoleLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.toll, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${_user?.talants ?? 0} 탈란트',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard() {
    final level = _calculateLevel();
    final xpForCurrentLevel = _getXPForLevel(level);
    final xpForNextLevel = _getXPForLevel(level + 1);
    final currentXP = _calculateTotalXP();
    final progress = (currentXP - xpForCurrentLevel) / (xpForNextLevel - xpForCurrentLevel);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _getLevelEmoji(level),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lv. $level',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _getLevelTitle(level),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '$currentXP / $xpForNextLevel XP',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 경험치 바
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다음 레벨까지 ${xpForNextLevel - currentXP} XP',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
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
              const Icon(Icons.bar_chart, color: _accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '학습 통계',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 통계 그리드
          Row(
            children: [
              _buildStatItem(
                icon: Icons.local_fire_department,
                iconColor: Colors.orange,
                value: '${_stats['currentStreak'] ?? 0}',
                label: '연속 학습',
              ),
              _buildStatItem(
                icon: Icons.emoji_events,
                iconColor: Colors.amber,
                value: '${_stats['longestStreak'] ?? 0}',
                label: '최장 기록',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem(
                icon: Icons.calendar_today,
                iconColor: Colors.green,
                value: '${_stats['totalStudyDays'] ?? 0}',
                label: '총 학습일',
              ),
              _buildStatItem(
                icon: Icons.check_circle,
                iconColor: Colors.blue,
                value: '${_stats['completedVerses'] ?? 0}',
                label: '완료 구절',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesCard() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '뱃지',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_badges.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryScreen()),
                  );
                },
                child: const Text('전체보기'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_badges.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '아직 획득한 뱃지가 없습니다',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _badges.take(6).map((badge) => _buildBadgeItem(badge)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(InventoryItem badge) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.isActive
            ? _accentColor.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: badge.isActive
            ? Border.all(color: _accentColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        children: [
          Text(badge.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            badge.itemName,
            style: TextStyle(
              fontSize: 10,
              color: badge.isActive ? _accentColor : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.shopping_bag,
            iconColor: Colors.pink,
            title: '탈란트 샵',
            subtitle: '아이템 구매하기',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              );
            },
          ),
          const Divider(color: Colors.white12, height: 1, indent: 60),
          _buildMenuItem(
            icon: Icons.inventory_2,
            iconColor: Colors.teal,
            title: '내 아이템',
            subtitle: '구매한 아이템 관리',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              );
            },
          ),
          const Divider(color: Colors.white12, height: 1, indent: 60),
          _buildMenuItem(
            icon: Icons.notifications,
            iconColor: Colors.orange,
            title: '알림 설정',
            subtitle: '푸시 알림 관리',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.white.withValues(alpha: 0.3),
      ),
    );
  }

  // Helper methods
  Color _getRoleColor() {
    switch (_user?.role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.leader:
        return Colors.amber;
      default:
        return _accentColor;
    }
  }

  String _getRoleLabel() {
    switch (_user?.role) {
      case UserRole.admin:
        return '관리자';
      case UserRole.leader:
        return '그룹 리더';
      default:
        return '멤버';
    }
  }

  int _calculateLevel() {
    final xp = _calculateTotalXP();
    if (xp < 100) return 1;
    if (xp < 300) return 2;
    if (xp < 600) return 3;
    if (xp < 1000) return 4;
    if (xp < 1500) return 5;
    if (xp < 2100) return 6;
    if (xp < 2800) return 7;
    if (xp < 3600) return 8;
    if (xp < 4500) return 9;
    return 10;
  }

  int _getXPForLevel(int level) {
    const xpTable = [0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 5500];
    if (level <= 0) return 0;
    if (level >= xpTable.length) return xpTable.last;
    return xpTable[level];
  }

  int _calculateTotalXP() {
    final studyDays = _stats['totalStudyDays'] ?? 0;
    final completedVerses = _stats['completedVerses'] ?? 0;
    final longestStreak = _stats['longestStreak'] ?? 0;

    return (studyDays * 10) + (completedVerses * 5) + (longestStreak * 3);
  }

  String _getLevelEmoji(int level) {
    const emojis = ['🌱', '🌿', '🌳', '🌸', '🌺', '🌻', '⭐', '💫', '🌟', '👑'];
    return emojis[(level - 1).clamp(0, emojis.length - 1)];
  }

  String _getLevelTitle(int level) {
    const titles = ['새싹', '풀잎', '나무', '꽃봉오리', '꽃', '해바라기', '별', '유성', '빛나는 별', '왕관'];
    return titles[(level - 1).clamp(0, titles.length - 1)];
  }
}
