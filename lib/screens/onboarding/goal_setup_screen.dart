import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/daily_goal.dart';
import '../../services/daily_goal_service.dart';
import 'onboarding_screen.dart';

/// 목표 설정 색상 팔레트 (Warm Parchment Light Theme)
class _GoalColors {
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
  static const scriptureGold = Color(0xFFB8860B);
}

/// 학습 목표 설정 화면
/// - 온보딩 완료 후 표시
/// - 일일 학습 목표 (쉬움/보통/도전) 선택
/// - 라이트 테마, 양피지 스타일
class GoalSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const GoalSetupScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen>
    with SingleTickerProviderStateMixin {
  final DailyGoalService _goalService = DailyGoalService();
  DailyGoalPreset? _selectedPreset;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<_GoalPreset> _presets = const [
    _GoalPreset(
      preset: DailyGoalPreset.easy,
      title: '가볍게',
      description: '하루 5분, 부담 없이 시작해요',
      icon: Icons.eco_outlined,
      color: Color(0xFF6B8E6B),
      words: 5,
      quizzes: 1,
      flashcards: 1,
    ),
    _GoalPreset(
      preset: DailyGoalPreset.normal,
      title: '꾸준히',
      description: '하루 15분, 균형 잡힌 학습',
      icon: Icons.menu_book_outlined,
      color: Color(0xFF5B7B9B),
      words: 10,
      quizzes: 1,
      flashcards: 1,
      isRecommended: true,
    ),
    _GoalPreset(
      preset: DailyGoalPreset.hard,
      title: '도전적으로',
      description: '하루 30분, 빠른 성장을 원해요',
      icon: Icons.local_fire_department_outlined,
      color: Color(0xFFB8860B),
      words: 20,
      quizzes: 2,
      flashcards: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _goalService.init();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onPresetSelected(DailyGoalPreset preset) async {
    setState(() {
      _selectedPreset = preset;
      _isLoading = true;
    });

    try {
      await _goalService.setPreset(preset);
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onComplete();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('설정 저장에 실패했습니다.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _skipSetup() {
    widget.onComplete();
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
              _GoalColors.softPapyrus,
              _GoalColors.agedParchment,
              _GoalColors.warmVellum,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 건너뛰기 버튼
                    Align(
                      alignment: Alignment.topRight,
                      child: TextButton(
                        onPressed: _skipSetup,
                        child: const Text(
                          '나중에',
                          style: TextStyle(
                            color: _GoalColors.weatheredGray,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 헤더
                    Text(
                      '학습 목표를\n설정해볼까요?',
                      style: GoogleFonts.notoSerifKr(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: _GoalColors.ancientInk,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '나에게 맞는 학습량을 선택하면\n매일 목표 달성 보너스를 받을 수 있어요',
                      style: TextStyle(
                        fontSize: 16,
                        color: _GoalColors.fadedScript,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 목표 선택 카드
                    Expanded(
                      child: ListView.separated(
                        itemCount: _presets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final presetData = _presets[index];
                          final isSelected = _selectedPreset == presetData.preset;

                          return _buildPresetCard(presetData, isSelected, index);
                        },
                      ),
                    ),

                    // 성경 구절
                    _buildBibleVerse(),

                    // 하단 안내
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: _GoalColors.weatheredGray.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '설정은 마이페이지에서 언제든 변경 가능해요',
                            style: TextStyle(
                              fontSize: 13,
                              color: _GoalColors.weatheredGray.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetCard(_GoalPreset preset, bool isSelected, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _isLoading ? null : () => _onPresetSelected(preset.preset),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? _GoalColors.warmVellum
                : _GoalColors.softPapyrus,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? _GoalColors.manuscriptGold
                  : _GoalColors.antiqueEdge,
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _GoalColors.manuscriptGold.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: _GoalColors.sepiaShadow.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // 추천 배지
              if (preset.isRecommended)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _GoalColors.manuscriptGold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '추천',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              Row(
                children: [
                  // 라인 아이콘
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isSelected
                          ? _GoalColors.manuscriptGold.withValues(alpha: 0.12)
                          : _GoalColors.warmVellum,
                      border: Border.all(
                        color: isSelected
                            ? _GoalColors.manuscriptGold.withValues(alpha: 0.5)
                            : preset.color.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        preset.icon,
                        size: 28,
                        color: isSelected ? _GoalColors.manuscriptGold : preset.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? _GoalColors.manuscriptGold
                                : _GoalColors.ancientInk,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: _GoalColors.fadedScript,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 목표 수치
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildGoalChip(
                              '단어 ${preset.words}개',
                              isSelected,
                            ),
                            _buildGoalChip(
                              '퀴즈 ${preset.quizzes}개',
                              isSelected,
                            ),
                            _buildGoalChip(
                              '카드 ${preset.flashcards}장',
                              isSelected,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 선택 인디케이터
                  if (isSelected && _isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _GoalColors.manuscriptGold,
                      ),
                    )
                  else
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? _GoalColors.manuscriptGold
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? _GoalColors.manuscriptGold
                              : _GoalColors.antiqueEdge,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? _GoalColors.manuscriptGold.withValues(alpha: 0.15)
            : _GoalColors.warmVellum,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? _GoalColors.manuscriptGold.withValues(alpha: 0.3)
              : _GoalColors.antiqueEdge.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? _GoalColors.manuscriptGold : _GoalColors.fadedScript,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildBibleVerse() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _GoalColors.warmVellum,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _GoalColors.antiqueEdge,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _GoalColors.sepiaShadow.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.format_quote,
            color: _GoalColors.manuscriptGold.withValues(alpha: 0.6),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"네 손이 일을 당하는 대로 힘을 다하여 할지어다"',
                  style: TextStyle(
                    fontSize: 13,
                    color: _GoalColors.ancientInk.withValues(alpha: 0.9),
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '- 전도서 9:10',
                  style: GoogleFonts.cardo(
                    fontSize: 12,
                    color: _GoalColors.scriptureGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 목표 프리셋 데이터
class _GoalPreset {
  final DailyGoalPreset preset;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int words;
  final int quizzes;
  final int flashcards;
  final bool isRecommended;

  const _GoalPreset({
    required this.preset,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.words,
    required this.quizzes,
    required this.flashcards,
    this.isRecommended = false,
  });
}
