import 'package:flutter/material.dart';

/// 빈 상태 위젯
/// 데이터가 없을 때 친절한 안내와 액션 버튼을 제공
class EmptyStateWidget extends StatelessWidget {
  final String emoji;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accentColor;

  const EmptyStateWidget({
    super.key,
    required this.emoji,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.accentColor,
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
      accentColor: Colors.orange,
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
      accentColor: Colors.red,
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
                color: color.withOpacity(0.1),
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
