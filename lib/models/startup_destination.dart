import 'session_state.dart';

/// 앱 시작 시 로컬에서 결정할 수 있는 첫 화면.
enum StartupDestination {
  onboarding,
  login,
  profileSetup,
  mainMenu,
}

/// Firebase 세션과 로컬 사용자 ID가 같은 계정을 가리킬 때만 복귀한다.
/// 네트워크 조회 없이 결정할 수 있어 오프라인 시작에도 동일하게 동작한다.
StartupDestination resolveStartupDestination({
  required bool onboardingCompleted,
  required String? savedUserId,
  required String? firebaseUserId,
}) {
  final hasMatchingSession = savedUserId != null &&
      savedUserId.isNotEmpty &&
      savedUserId == firebaseUserId;

  if (hasMatchingSession) return StartupDestination.mainMenu;
  if (!onboardingCompleted) return StartupDestination.onboarding;
  return StartupDestination.login;
}

/// 확정된 세션 상태만 시작 화면으로 변환한다.
/// loading과 일시 오류는 스플래시에 머물도록 null을 반환한다.
StartupDestination? resolveSessionStartupDestination({
  required SessionState session,
  required bool onboardingCompleted,
}) {
  switch (session.status) {
    case SessionStatus.loading:
    case SessionStatus.recoverableError:
      return null;
    case SessionStatus.authenticated:
      return StartupDestination.mainMenu;
    case SessionStatus.needsProfile:
      return StartupDestination.profileSetup;
    case SessionStatus.signedOut:
      return onboardingCompleted
          ? StartupDestination.login
          : StartupDestination.onboarding;
  }
}
