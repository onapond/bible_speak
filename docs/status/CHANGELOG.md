# Changelog

바이블스픽 개발 변경 이력입니다. [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/) 형식을 따릅니다.

---

## [2026-02-02]

### Added
- **PWA 업데이트 시스템**: iOS 홈 화면 PWA 업데이트 문제 해결
  - `lib/services/pwa_update_service.dart` - 웹 전용 PWA 업데이트 서비스
  - `lib/services/app_update_service.dart` - 플랫폼 독립적 인터페이스
  - `web/custom_service_worker.js` - SKIP_WAITING 메시지 처리
  - 1분마다 업데이트 확인, 새 버전 감지 시 사용자 알림
- **PrefsService**: SharedPreferences 전역 캐싱 서비스

### Changed
- **메모리 누수 수정**: VersePracticeScreen dispose에 `BibleAudioService.instance.stop()` 추가
- **서비스 싱글톤화**: 5개 서비스에 싱글톤 패턴 적용
  - ReviewService, StreakService, StatsService, DailyGoalService, DailyQuizService
- **ProgressService LRU 캐시**: 무제한 캐시 → LinkedHashMap 기반 LRU 캐시 (최대 100개)
- **ReviewService 최적화**: 전체 문서 로드 → Firestore count() 쿼리 3개 병렬 실행
- **DataPreloaderService**: `_getCachedMainData()`가 실제 캐시 데이터 반환하도록 수정
- **MainMenuScreen setState 통합**: 5-7회 개별 setState → 단일 setState
- **StatsDashboardScreen 캐싱**: 주간 그래프 maxMinutes 로드 시점에 캐싱
- **Firebase Hosting 캐시 최적화**: 서비스 워커, index.html에 no-cache 설정
- **build_web.ps1 개선**: PWA 전략, 버전 관리, 서비스 워커 패치 추가

---

## [2026-01-31]

### Fixed
- **Firestore update 패턴 전체 점검**: 10개 서비스에서 `transaction.update()` → `set(merge: true)` 수정
  - daily_quiz_service, achievement_service, shop_service, battle_service
  - auth_service, group_challenge_service, group_activity_service
  - nudge_service, friend_service, chat_service
- **퀴즈 제출 오류**: Transaction 읽기/쓰기 순서 문제 → Transaction 제거, 개별 호출
- **샵 달란트 0원 표시**: AuthService 캐시 문제 → Firestore 직접 조회
- **업적 미작동**: 체크 메서드 미호출 → `_checkAchievements()` 추가
- **폰트 로딩 지연**: 비동기 폰트 로딩 → display=block, 시스템 폰트 고정
- **로그인 시 프로필 설정 반복**: registerAnonymous가 새 익명 계정 생성 → completeProfile 사용

### Added
- **설정 화면 통합**: 접근성 설정 메뉴, 앱 정보 다이얼로그 추가
- **로그인 마이그레이션 로직**: 이메일 기반 기존 사용자 검색, 익명 → 소셜 계정 마이그레이션

---

## [2026-01-30]

### Changed
- **구절 선택 화면 통합** (PracticeSetupScreen)
  - 이전: 3개 화면 (1,811줄) → 이후: 1개 화면 (660줄)
  - 64% 코드 감소, 5탭 → 3탭 네비게이션
- **커뮤니티 화면 통합** (CommunityScreen)
  - 이전: 3개 화면 (635줄) → 이후: 1개 화면 (~900줄)
  - 그룹 드롭다운 선택, 대시보드/채팅/멤버 탭, 그룹 참여/생성 FAB

### Fixed
- **role.name 웹 미니파이 오류**: `user.isAdmin` 게터 사용으로 수정

### Added
- GroupService에 `getMyGroups()`, `joinGroup()` 메서드 추가

### Removed
- `book_selection_screen.dart`, `chapter_selection_screen.dart`, `verse_roadmap_screen.dart`
- `group_dashboard_screen.dart`, `group_chat_screen.dart`

---

## [2026-01-29]

### Added
- **스토어 배포 준비**
  - 스크린샷 도우미 (`lib/screens/admin/screenshot_helper_screen.dart`)
  - TestFlight/Codemagic 설정 (`codemagic.yaml`, `ios/ExportOptions.plist`)
  - 스토어 메타데이터 (`docs/STORE_LISTING.md`)
- **종합 앱 문서**: `docs/APP_DOCUMENTATION.md` (541줄)
- **UX 개선 위젯 라이브러리**: EmptyStateWidget, LoadingStateWidget, TodaysLearningCard 등 10개 위젯
- **법적 문서**: 개인정보 처리방침, 이용약관 (`docs/legal/`)

### Changed
- **용어 개선**: "스트릭" → "연속 학습"으로 변경 (11개 파일)
- **웹 성능 최적화**
  - 오디오 재생: 인메모리 LRU 캐시 (최근 10개 구절)
  - 녹음: 마이크 권한 상태 캐싱, 사전 권한 체크
  - 화면 전환: 웹 애니메이션 시간 40% 단축

### Fixed
- Warning 해결 (`flutter analyze`)
- 웹 네비게이션 버그 수정 (온보딩 완료 후 context 문제)

---

## [2026-01-27]

### Added
- **소셜 UX 시스템 완성**
  - 스트릭 시스템: 연속 학습 추적, 마일스톤 보상, 보호권
  - 그룹 활동 피드: 박수/기도/화이팅 반응, 7일 TTL
  - 성전 쌓기 챌린지: 주간 그룹 목표, 시각화
  - 아침 만나: 오늘의 구절, Early Bird 보너스
  - 찌르기 시스템: 비활성 멤버 격려, 메시지 템플릿

- **Azure Speech API 통합**: 발음 평가 기능 (Korea Central)
- **웹 배포 완성**
  - Firebase Hosting 배포
  - Cloudflare Worker (CORS 프록시)
  - 웹 녹음 지원 (WAV 형식)

### Changed
- 웹 녹음 형식: WebM/Opus → WAV (Azure 호환)
- 통과 기준 조정: Stage 1 (70%), Stage 2 (75%), Stage 3 (80%)
- API 타임아웃: 45초 → 15초
- 데이터 로딩: 순차 → 병렬 (`Future.wait`)

---

## [2026-01-26]

### Added
- **Speak 스타일 로드맵 UI**: 지그재그 노드 레이아웃, 3단계 진행 표시
- Verse 프리로딩 기능

### Changed
- `ChapterSelectionScreen` 네비게이션 개선

---

## [이전 개발 내역]

### Phase 1-4: 기본 인프라
- iOS 권한 설정 (마이크, 음성 인식, 백그라운드 오디오)
- Firestore 데이터 구조
- 3단계 학습 모델 (Listen & Repeat → Key Expressions → Real Speak)
- 기획/기술 문서화

### 핵심 기능 구현
- AI 발음 평가 (Azure Speech Services)
- AI 피드백 (Google Gemini)
- 스마트 복습 (SM-2 알고리즘)
- 업적 및 레벨 시스템
- 달란트 샵
- 그룹 챌린지 및 채팅
- 푸시 알림 (FCM)
- 오프라인 지원 (Hive)
- 온보딩 튜토리얼

### 인앱 결제
- 월간 프리미엄: ₩4,900
- 연간 프리미엄: ₩39,000 (33% 할인)

### 앱 아이콘
- 딥 퍼플 그라데이션 배경, 흰색 성경책, 골드 마이크

---

## 커밋 히스토리 요약

```
2026-02-02:
- PWA 업데이트 시스템 구현
- 메모리 누수 수정 및 성능 최적화

2026-01-31:
- 6cb0ce4 fix: Add try-catch for email lookup
- 30f6c8d fix: Add email-based user lookup for account migration
- 1998c9d fix: Use completeProfile instead of registerAnonymous
- 2dacd55 fix: Prevent font size shift on loading screen

2026-01-30:
- 1f3ec54 refactor: Consolidate screens for improved UX

2026-01-29:
- de95934 fix: Fix onboarding navigation context issue on web
- 557f80c docs: Add comprehensive app documentation
- 56fd358 fix: Resolve all warning-level issues

2026-01-27:
- 94e9c53 feat: Fix web audio format and optimize loading
- 240e36b feat: Implement Nudge System
- a932d90 feat: Implement Morning Manna with Early Bird bonus
- feafe53 feat: Implement streak system with milestones

2026-01-26:
- Speak 스타일 로드맵 UI 구현
```
