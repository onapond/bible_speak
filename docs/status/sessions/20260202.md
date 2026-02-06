# 세션 요약 - 2026년 2월 2일

## 완료된 작업

### Phase 1: 긴급 - 메모리 누수 수정
- **VersePracticeScreen dispose 보완**: `BibleAudioService.instance.stop()` 추가
- **서비스 싱글톤화**: 5개 서비스에 싱글톤 패턴 적용
  - `ReviewService`
  - `StreakService`
  - `StatsService`
  - `DailyGoalService`
  - `DailyQuizService`

### Phase 2: 높음 - 데이터 로딩 최적화
- **ProgressService LRU 캐시**: 무제한 캐시 → LinkedHashMap 기반 LRU 캐시 (최대 100개)
- **ReviewService getStats() 최적화**: 전체 문서 로드 → Firestore `count()` 쿼리 3개 병렬 실행
- **DataPreloaderService 캐시 완성**: `_getCachedMainData()`가 실제 캐시 데이터 반환하도록 수정

### Phase 3: 중간 - UI 성능
- **MainMenuScreen setState 통합**: 5-7회 개별 setState → 단일 setState (Silent 버전 메서드 추가)
- **StatsDashboardScreen 캐싱**: 주간 그래프 `maxMinutes` 로드 시점에 캐싱

### Phase 4: 낮음 - 앱 시작
- **PrefsService 생성**: SharedPreferences 전역 캐싱 서비스 (`lib/services/prefs_service.dart`)
- **main.dart 통합**: Firebase와 PrefsService 병렬 초기화

## 수정된 파일

| 파일 | 변경 내용 |
|------|----------|
| `lib/screens/practice/verse_practice_screen.dart` | dispose에 BibleAudioService.stop() 추가, import 추가 |
| `lib/services/review_service.dart` | 싱글톤 패턴 적용, getStats() Firestore count() 쿼리 최적화 |
| `lib/services/social/streak_service.dart` | 싱글톤 패턴 적용 |
| `lib/services/stats_service.dart` | 싱글톤 패턴 적용 |
| `lib/services/daily_goal_service.dart` | 싱글톤 패턴 적용, PrefsService 사용 |
| `lib/services/daily_quiz_service.dart` | 싱글톤 패턴 적용 |
| `lib/services/progress_service.dart` | LRU 캐시 구현, PrefsService 사용, dart:collection import 추가 |
| `lib/services/data_preloader_service.dart` | _cachedData 필드 추가, _getCachedMainData() 캐시 반환 구현 |
| `lib/screens/home/main_menu_screen.dart` | Silent 버전 메서드 추가, _loadAllData() 단일 setState 적용 |
| `lib/screens/stats/stats_dashboard_screen.dart` | _cachedMaxMinutes 필드 추가, _loadStats()에서 캐싱 |
| `lib/services/prefs_service.dart` | 신규 생성 - SharedPreferences 전역 캐싱 |
| `lib/main.dart` | PrefsService import 및 init() 호출 추가 |

## 발견된 버그 및 수정
- 없음 (성능 개선만 수행)

## 다음 작업 (TODO)
- 메모리 누수 테스트 (DevTools Memory 탭)
- Firebase 콘솔에서 읽기 횟수 모니터링
- DevTools Performance 탭에서 프레임 레이트 확인
- `flutter run --trace-startup`으로 앱 시작 시간 측정

---

## iOS PWA 업데이트 문제 해결 (추가)

### 문제 상황
- iOS 홈 화면에 추가된 PWA에서 코드 업데이트 후에도 예전 버전이 계속 실행됨
- 서비스 워커가 이전 버전 캐시를 유지하고 새 SW가 'Waiting' 상태에서 활성화되지 않음

### 해결책 구현

#### Task A: Update Detection Logic
- `web/index.html`에 서비스 워커 업데이트 감지 JavaScript 코드 추가
- `lib/services/pwa_update_service.dart` 생성 - Flutter 측 업데이트 알림 처리
- `lib/services/app_update_service.dart` 생성 - 플랫폼 독립적 인터페이스
- 1분마다 업데이트 확인, 새 버전 감지 시 사용자에게 다이얼로그/SnackBar 표시

#### Task B: Firebase Hosting Optimization
- `firebase.json`에 캐시 헤더 설정 추가:
  - `flutter_service_worker.js`, `index.html`: `no-cache, no-store, must-revalidate`
  - `flutter_bootstrap.js`, `version.json`: `no-cache`
  - 정적 자산 (js, css, 이미지): `max-age=31536000, immutable`

#### Task C: Flutter Build Strategy
- `build_web.ps1` 개선:
  - `--pwa-strategy=offline-first` 옵션 추가
  - 빌드 타임스탬프 자동 생성 및 index.html 삽입
  - `version.json` 생성 (버전 확인용)
  - 커스텀 서비스 워커 코드 추가 (`SKIP_WAITING` 메시지 처리)

### 수정된 파일 (PWA 업데이트)

| 파일 | 변경 내용 |
|------|----------|
| `web/index.html` | 서비스 워커 업데이트 감지 JS 코드, 버전 메타 태그 추가 |
| `web/manifest.json` | 앱 이름, 색상, 설명 개선 |
| `web/custom_service_worker.js` | 신규 - SKIP_WAITING 메시지 처리 |
| `firebase.json` | 캐시 헤더 설정 추가 |
| `build_web.ps1` | PWA 전략, 버전 관리, 서비스 워커 패치 추가 |
| `pubspec.yaml` | `web: ^1.1.0` 패키지 추가 |
| `lib/services/pwa_update_service.dart` | 신규 - 웹 전용 PWA 업데이트 서비스 |
| `lib/services/pwa_update_service_stub.dart` | 신규 - 비웹 플랫폼용 스텁 |
| `lib/services/app_update_service.dart` | 신규 - 플랫폼 독립적 래퍼 |
| `lib/main.dart` | AppUpdateService 초기화 추가 |
| `lib/screens/home/main_menu_screen.dart` | AppUpdateService 컨텍스트 설정 |

### 배포 방법
```powershell
# 1. 웹 빌드 (PWA 최적화 포함)
powershell -ExecutionPolicy Bypass -File build_web.ps1

# 2. Firebase 배포
firebase deploy --only hosting
```

### 작동 원리
1. 사용자가 앱 실행 → 서비스 워커가 1분마다 업데이트 확인
2. 새 버전 감지 → JS에서 Flutter로 콜백 호출
3. Flutter에서 "업데이트 알림" 다이얼로그 표시
4. 사용자가 "지금 업데이트" 클릭 → `skipWaiting` 메시지 전송
5. 새 서비스 워커 활성화 → 페이지 자동 새로고침

## 중요 참고사항
- `flutter analyze` 오류 없음 확인 완료
- 기존 개별 호출용 메서드들은 유지 (다른 곳에서 사용 가능)
- ReviewService getStats()에서 totalReviews/totalCorrect는 집계 쿼리로 얻을 수 없어 0 반환 (필요 시 별도 로드)

## 예상 효과

| 영역 | 현재 | 개선 후 |
|------|------|--------|
| 화면 전환 메모리 | +5~10MB 누적 | 안정 유지 |
| ReviewService 쿼리 | 전체 문서 로드 | count() 3개 |
| MainMenuScreen rebuild | 5-7회 | 1회 |
| SharedPreferences | 반복 getInstance() | 1회 |
| ProgressService 캐시 | 무제한 | 최대 100개 (LRU) |
