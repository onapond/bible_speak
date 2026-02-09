import 'package:flutter/material.dart';
import '../../styles/parchment_theme.dart';

/// 빈 상태 위젯
/// 데이터가 없을 때 친절한 안내와 액션 버튼을 제공
class EmptyStateWidget extends StatelessWidget {
  final String emoji;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accentColor;
  final List<String>? tips;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const EmptyStateWidget({
    super.key,
    required this.emoji,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.accentColor,
    this.tips,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  /// 학습 기록 없음
  factory EmptyStateWidget.noLearningHistory({
    VoidCallback? onStartLearning,
  }) {
    return EmptyStateWidget(
      emoji: '📖',
      title: '아직 학습 기록이 없어요',
      description: '첫 번째 성경 구절을 암송해보세요!\n매일 조금씩 성장하는 기쁨을 느껴보세요.',
      actionLabel: '첫 암송 시작하기',
      onAction: onStartLearning,
    );
  }

  /// 복습할 구절 없음
  factory EmptyStateWidget.noReviewItems({
    VoidCallback? onStartLearning,
  }) {
    return EmptyStateWidget(
      emoji: '✨',
      title: '복습할 구절이 없어요',
      description: '새로운 구절을 학습하면\n자동으로 복습 일정이 잡혀요.',
      actionLabel: '새 구절 학습하기',
      onAction: onStartLearning,
    );
  }

  /// 그룹 멤버 없음
  factory EmptyStateWidget.noGroupMembers({
    VoidCallback? onInvite,
  }) {
    return EmptyStateWidget(
      emoji: '👥',
      title: '아직 그룹 멤버가 없어요',
      description: '친구들을 초대해서 함께 성장해요!\n그룹 코드를 공유해보세요.',
      actionLabel: '초대 링크 복사',
      onAction: onInvite,
    );
  }

  /// 친구 없음
  factory EmptyStateWidget.noFriends({
    VoidCallback? onSearchFriends,
  }) {
    return EmptyStateWidget(
      emoji: '🤝',
      title: '아직 친구가 없어요',
      description: '친구를 추가하고 함께 학습해요!\n1:1 배틀로 실력을 겨뤄보세요.',
      actionLabel: '친구 찾기',
      onAction: onSearchFriends,
    );
  }

  /// 활동 기록 없음
  factory EmptyStateWidget.noActivities() {
    return const EmptyStateWidget(
      emoji: '📝',
      title: '아직 활동 기록이 없어요',
      description: '그룹 멤버들이 학습을 시작하면\n여기서 활동을 확인할 수 있어요.',
    );
  }

  /// 검색 결과 없음
  factory EmptyStateWidget.noSearchResults({
    String? searchTerm,
  }) {
    return EmptyStateWidget(
      emoji: '🔍',
      title: '검색 결과가 없어요',
      description: searchTerm != null
          ? '"$searchTerm"에 대한 결과를 찾지 못했어요.\n다른 검색어로 시도해보세요.'
          : '검색 결과를 찾지 못했어요.',
    );
  }

  /// 업적 없음
  factory EmptyStateWidget.noAchievements({
    VoidCallback? onStartLearning,
  }) {
    return EmptyStateWidget(
      emoji: '🏆',
      title: '아직 획득한 업적이 없어요',
      description: '학습을 진행하면 다양한 업적을\n달성할 수 있어요!',
      actionLabel: '학습 시작하기',
      onAction: onStartLearning,
    );
  }

  /// 네트워크 에러
  factory EmptyStateWidget.networkError({
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      emoji: '📡',
      title: '연결에 문제가 있어요',
      description: '인터넷 연결을 확인해주세요.\nWi-Fi 또는 모바일 데이터가 켜져 있는지 확인해보세요.',
      actionLabel: '다시 시도',
      onAction: onRetry,
      accentColor: ParchmentTheme.warning,
    );
  }

  /// 일반 에러
  factory EmptyStateWidget.error({
    String? message,
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      emoji: '😅',
      title: '문제가 발생했어요',
      description: message ?? '잠시 후 다시 시도해주세요.\n문제가 계속되면 앱을 재시작해보세요.',
      actionLabel: '다시 시도',
      onAction: onRetry,
      accentColor: ParchmentTheme.error,
    );
  }

  /// 퀴즈 기록 없음
  factory EmptyStateWidget.noQuizHistory({
    VoidCallback? onStartQuiz,
  }) {
    return EmptyStateWidget(
      emoji: '🧠',
      title: '아직 퀴즈 기록이 없어요',
      description: '매일 퀴즈로 암송 실력을 점검해보세요!',
      actionLabel: '오늘의 퀴즈 시작',
      onAction: onStartQuiz,
      accentColor: ParchmentTheme.warning,
      tips: const [
        '매일 퀴즈를 완료하면 보너스 달란트 획득',
        '틀린 문제는 자동으로 복습 목록에 추가',
      ],
    );
  }

  /// 플래시카드 없음
  factory EmptyStateWidget.noFlashcards({
    VoidCallback? onCreateFlashcard,
  }) {
    return EmptyStateWidget(
      emoji: '🃏',
      title: '플래시카드가 없어요',
      description: '학습한 구절로 플래시카드를 만들어보세요!',
      actionLabel: '플래시카드 만들기',
      onAction: onCreateFlashcard,
      accentColor: ParchmentTheme.categorySocial,
      tips: const [
        '플래시카드로 짧은 시간에 효율적인 복습',
        '스와이프로 빠르게 넘기며 학습',
      ],
    );
  }

  /// 일일 목표 미설정
  factory EmptyStateWidget.noDailyGoal({
    VoidCallback? onSetGoal,
  }) {
    return EmptyStateWidget(
      emoji: '🎯',
      title: '일일 목표를 설정해보세요',
      description: '목표를 설정하면 학습 동기부여가 돼요!',
      actionLabel: '목표 설정하기',
      onAction: onSetGoal,
      accentColor: ParchmentTheme.categoryMyPage,
      tips: const [
        '쉬움/보통/어려움 중 선택 가능',
        '목표 달성 시 보너스 달란트 10 획득',
      ],
    );
  }

  /// 오늘의 만나 없음
  factory EmptyStateWidget.noMorningManna({
    VoidCallback? onRefresh,
  }) {
    return EmptyStateWidget(
      emoji: '🌅',
      title: '오늘의 만나가 아직 없어요',
      description: '매일 새로운 성경 구절을 추천받아보세요.',
      actionLabel: '새로고침',
      onAction: onRefresh,
      accentColor: ParchmentTheme.manuscriptGold,
      tips: const [
        '아침 6시 이전에 학습하면 얼리버드 보너스!',
        '오늘의 만나로 하루를 시작해보세요',
      ],
    );
  }

  /// 단어 북마크 없음
  factory EmptyStateWidget.noWordBookmarks({
    VoidCallback? onBrowseWords,
  }) {
    return EmptyStateWidget(
      emoji: '📚',
      title: '저장된 단어가 없어요',
      description: '학습 중 어려운 단어를 북마크해보세요!',
      actionLabel: '단어 학습 시작',
      onAction: onBrowseWords,
      accentColor: ParchmentTheme.categoryPractice,
      tips: const [
        '모르는 단어는 ★ 버튼으로 저장',
        '저장한 단어는 언제든 복습 가능',
      ],
    );
  }

  /// 알림 없음
  factory EmptyStateWidget.noNotifications() {
    return const EmptyStateWidget(
      emoji: '🔔',
      title: '새로운 알림이 없어요',
      description: '새로운 소식이 있으면 알려드릴게요!',
      tips: [
        '친구의 찌르기, 그룹 알림 등 확인',
        '설정에서 알림을 관리할 수 있어요',
      ],
    );
  }

  /// 처음 시작하는 사용자
  factory EmptyStateWidget.welcome({
    VoidCallback? onStartTour,
    VoidCallback? onSkip,
  }) {
    return EmptyStateWidget(
      emoji: '👋',
      title: '바이블 스픽에 오신 것을 환영해요!',
      description: '영어 성경 암송으로 믿음과 영어 실력을\n함께 키워보세요.',
      actionLabel: '앱 둘러보기',
      onAction: onStartTour,
      secondaryActionLabel: '바로 시작하기',
      onSecondaryAction: onSkip,
      accentColor: const Color(0xFF6C63FF),
      tips: const [
        '매일 한 구절씩, 꾸준히 암송',
        '음성 인식으로 발음 교정',
        '친구들과 함께 성장',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? const Color(0xFF6C63FF);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이모지
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 제목
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            // 설명
            if (description != null) ...[
              const SizedBox(height: 12),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // 팁 섹션
            if (tips != null && tips!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(
                          '팁',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...tips!.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],

            // 액션 버튼
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],

            // 보조 액션 버튼
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSecondaryAction,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[400],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  secondaryActionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 로딩 상태 위젯 (메시지 포함)
class LoadingStateWidget extends StatelessWidget {
  final String message;
  final String? subMessage;

  const LoadingStateWidget({
    super.key,
    required this.message,
    this.subMessage,
  });

  /// 성경 구절 로딩
  factory LoadingStateWidget.loadingVerse() {
    return const LoadingStateWidget(
      message: '성경 구절을 불러오는 중...',
      subMessage: '보통 2-3초 정도 걸려요',
    );
  }

  /// 발음 분석 중
  factory LoadingStateWidget.analyzingPronunciation() {
    return const LoadingStateWidget(
      message: '발음을 분석하고 있어요...',
      subMessage: 'AI가 꼼꼼히 분석 중이에요',
    );
  }

  /// 데이터 동기화 중
  factory LoadingStateWidget.syncing() {
    return const LoadingStateWidget(
      message: '데이터를 동기화하는 중...',
    );
  }

  /// 일반 로딩
  factory LoadingStateWidget.general() {
    return const LoadingStateWidget(
      message: '잠시만 기다려주세요...',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6C63FF),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
