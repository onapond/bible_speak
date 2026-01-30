import 'package:flutter/material.dart';
import '../../models/daily_goal.dart';
import '../../services/daily_goal_service.dart';

/// 학습 목표 설정 화면
/// - 온보딩 완료 후 표시
/// - 일일 학습 목표 (쉬움/보통/어려움) 선택
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
  static const _bgColor = Color(0xFF0F0F1A);

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
      emoji: '🌱',
      color: Color(0xFF4CAF50),
      words: 5,
      quizzes: 1,
      flashcards: 1,
    ),
    _GoalPreset(
      preset: DailyGoalPreset.normal,
      title: '꾸준히',
      description: '하루 15분, 균형 잡힌 학습',
      emoji: '📚',
      color: Color(0xFF2196F3),
      words: 10,
      quizzes: 1,
      flashcards: 1,
      isRecommended: true,
    ),
    _GoalPreset(
      preset: DailyGoalPreset.hard,
      title: '도전적으로',
      description: '하루 30분, 빠른 성장을 원해요',
      emoji: '🔥',
      color: Color(0xFFFF5722),
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
      begin: const Offset(0, 0.2),
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
          const SnackBar(content: Text('설정 저장에 실패했습니다.')),
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
      backgroundColor: _bgColor,
      body: SafeArea(
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
                      child: Text(
                        '나중에',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 헤더
                  const Text(
                    '학습 목표를\n설정해볼까요?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '나에게 맞는 학습량을 선택하면\n매일 목표 달성 보너스를 받을 수 있어요',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
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

                  // 하단 안내
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '설정은 마이페이지에서 언제든 변경 가능해요',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
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
                ? preset.color.withValues(alpha: 0.15)
                : const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? preset.color
                  : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: preset.color.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
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
                      color: preset.color,
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
                  // 이모지
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: preset.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        preset.emoji,
                        style: const TextStyle(fontSize: 32),
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
                            color: isSelected ? preset.color : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 목표 수치
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildGoalChip(
                              '단어 ${preset.words}개',
                              preset.color,
                              isSelected,
                            ),
                            _buildGoalChip(
                              '퀴즈 ${preset.quizzes}개',
                              preset.color,
                              isSelected,
                            ),
                            _buildGoalChip(
                              '카드 ${preset.flashcards}장',
                              preset.color,
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
                        color: Colors.white,
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
                            ? preset.color
                            : Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: isSelected
                              ? preset.color
                              : Colors.white.withValues(alpha: 0.3),
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

  Widget _buildGoalChip(String label, Color color, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? color : Colors.white.withValues(alpha: 0.6),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

/// 목표 프리셋 데이터
class _GoalPreset {
  final DailyGoalPreset preset;
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final int words;
  final int quizzes;
  final int flashcards;
  final bool isRecommended;

  const _GoalPreset({
    required this.preset,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    required this.words,
    required this.quizzes,
    required this.flashcards,
    this.isRecommended = false,
  });
}
