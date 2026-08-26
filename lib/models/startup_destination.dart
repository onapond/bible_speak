/// 앱 시작 시 로컬에서 결정할 수 있는 첫 화면.
enum StartupDestination {
  onboarding,
  login,
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
