import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/main_menu_screen.dart';
import '../practice/verse_practice_screen.dart';
import '../stats/stats_dashboard_screen.dart';
import '../review/review_screen.dart';
import '../achievement/achievement_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// 스크린샷 촬영 도우미 화면
/// 스토어 배포용 스크린샷을 쉽게 촬영할 수 있도록 도와줍니다.
class ScreenshotHelperScreen extends StatelessWidget {
  final AuthService authService;

  const ScreenshotHelperScreen({
    super.key,
    required this.authService,
  });

  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        title: const Text('📸 스크린샷 도우미'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildSectionTitle('핵심 화면 (필수)'),
          _buildScreenButton(
            context,
            icon: Icons.waving_hand,
            title: '1. 온보딩',
            subtitle: '앱 소개 화면',
            onTap: () => _navigateTo(
              context,
              OnboardingScreen(
                onComplete: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          _buildScreenButton(
            context,
            icon: Icons.home,
            title: '2. 메인 메뉴',
            subtitle: '홈 대시보드',
            onTap: () => _navigateTo(
              context,
              MainMenuScreen(authService: authService),
            ),
          ),
          _buildScreenButton(
            context,
            icon: Icons.mic,
            title: '3. 암송 연습',
            subtitle: '핵심 학습 화면',
            onTap: () => _navigateTo(
              context,
              VersePracticeScreen(
                authService: authService,
                book: 'john',
                chapter: 3,
                initialVerse: 16,
              ),
            ),
          ),
          _buildScreenButton(
            context,
            icon: Icons.bar_chart,
            title: '4. 학습 통계',
            subtitle: '진행 상황 대시보드',
            onTap: () => _navigateTo(context, const StatsDashboardScreen()),
          ),
          _buildScreenButton(
            context,
            icon: Icons.refresh,
            title: '5. 복습',
            subtitle: '스페이스드 리피티션',
            onTap: () => _navigateTo(context, const ReviewScreen()),
          ),
          _buildScreenButton(
            context,
            icon: Icons.emoji_events,
            title: '6. 업적',
            subtitle: '성취 시스템',
            onTap: () => _navigateTo(context, const AchievementScreen()),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('촬영 팁'),
          _buildTipCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withValues(alpha: 0.3),
            _accentColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '스토어 스크린샷 촬영',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '아래 화면들을 순서대로 방문하며 스크린샷을 촬영하세요.\n'
            '촬영 후 디바이스 프레임과 마케팅 텍스트를 추가합니다.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildScreenButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipItem('📱', '시간을 11:00으로 설정'),
          _buildTipItem('🔋', '배터리 100% 또는 숨김'),
          _buildTipItem('📶', 'Wi-Fi 연결 상태'),
          _buildTipItem('🌙', '다크 모드 유지'),
          _buildTipItem('🎯', '좋은 데이터로 테스트 계정 사용'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
