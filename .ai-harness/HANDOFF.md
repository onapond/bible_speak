# AI handoff

- Task: SESSION-001 — 로그인 세션 상태 단일화와 오프라인 복귀 안정화
- From/To: codex -> human
- State: ready
- Summary: Firebase Auth·로컬 UID·프로필 로딩을 단일 SessionState로 통합하고, UID 검증 세션 캐시와 오프라인 복귀, 확정 상태 기반 Splash 라우팅, 계정 전환·로그아웃 세대 가드 및 원자적 캐시 정리를 구현했다. 지연 Auth·UID 불일치·오프라인·A→B 전환·로그아웃 경합 회귀 테스트를 추가했고 독립 리뷰 지적 P1/P2를 모두 해소했다.
- Changed: lib/models/session_state.dart, lib/models/startup_destination.dart, lib/models/user_model.dart, lib/providers/auth_provider.dart, lib/providers/core_providers.dart, lib/screens/splash_screen.dart, lib/services/auth_service.dart, test/models/session_state_test.dart, test/models/startup_destination_test.dart, test/providers/session_notifier_test.dart, test/services/session_restorer_test.dart
- Verification: 6d9791b-3b831641-standard-1788856139 (pass)
- Next: 변경을 codex/session-state에 커밋·푸시하고 develop 대상 PR의 원격 필수 검사를 확인한 뒤 사용자 최종 병합 승인을 받는다. 운영 배포·운영 데이터는 변경하지 않는다.
