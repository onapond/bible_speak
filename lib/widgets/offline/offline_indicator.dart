import 'package:flutter/material.dart';
import '../../services/offline/offline_services.dart';

/// 오프라인 상태 표시 배너
class OfflineIndicator extends StatelessWidget {
  final Widget child;

  const OfflineIndicator({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: offlineManager,
      builder: (context, _) {
        return Column(
          children: [
            // 오프라인 배너
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: offlineManager.isOffline ? 32 : 0,
              child: offlineManager.isOffline
                  ? Container(
                      color: Colors.orange.shade800,
                      child: const SafeArea(
                        bottom: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '오프라인 모드',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // 메인 콘텐츠
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// 오프라인 상태에서 동작하는 버튼
class OfflineAwareButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onOfflinePressed;
  final Widget child;
  final bool allowOffline;

  const OfflineAwareButton({
    super.key,
    required this.onPressed,
    this.onOfflinePressed,
    required this.child,
    this.allowOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: offlineManager,
      builder: (context, _) {
        final isEnabled =
            offlineManager.isOnline || allowOffline || onOfflinePressed != null;

        return ElevatedButton(
          onPressed: isEnabled
              ? () {
                  if (offlineManager.isOnline) {
                    onPressed?.call();
                  } else {
                    onOfflinePressed?.call();
                  }
                }
              : null,
          child: child,
        );
      },
    );
  }
}

/// 동기화 대기 표시 배지
class SyncPendingBadge extends StatelessWidget {
  final Widget child;

  const SyncPendingBadge({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: offlineManager,
      builder: (context, _) {
        final pendingCount = offlineManager.pendingSyncCount;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (pendingCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    pendingCount > 9 ? '9+' : pendingCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 온라인 상태에서만 표시되는 위젯
class OnlineOnly extends StatelessWidget {
  final Widget child;
  final Widget? offlineChild;

  const OnlineOnly({
    super.key,
    required this.child,
    this.offlineChild,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: offlineManager,
      builder: (context, _) {
        if (offlineManager.isOnline) {
          return child;
        }
        return offlineChild ?? const SizedBox.shrink();
      },
    );
  }
}

/// 오프라인 힌트 스낵바 표시
void showOfflineHint(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.white),
          SizedBox(width: 8),
          Text('오프라인 상태입니다. 일부 기능이 제한됩니다.'),
        ],
      ),
      backgroundColor: Colors.orange.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
