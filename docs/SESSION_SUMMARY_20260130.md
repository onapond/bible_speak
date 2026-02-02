# 세션 요약 - 2026년 1월 30일

## 완료된 작업

### 1. 화면 통합 (UX 개선)

#### A. 구절 선택 통합 (PracticeSetupScreen)
- **이전**: 3개 화면 (1,811줄)
  - `book_selection_screen.dart` (282줄)
  - `chapter_selection_screen.dart` (695줄)
  - `verse_roadmap_screen.dart` (834줄)
- **이후**: 1개 화면 (660줄)
  - `lib/screens/study/practice_setup_screen.dart`
- **효과**: 64% 코드 감소, 5탭 → 3탭 네비게이션

#### B. 커뮤니티 통합 (CommunityScreen)
- **이전**: 3개 화면 (635줄)
  - `group_dashboard_screen.dart` (207줄)
  - `group_chat_screen.dart` (428줄)
  - (group_select_screen.dart는 온보딩용으로 유지)
- **이후**: 1개 화면 (~900줄)
  - `lib/screens/social/community_screen.dart`
- **기능**:
  - 그룹 드롭다운 선택
  - 대시보드/채팅/멤버 탭
  - 그룹 참여/생성 FAB

### 2. 버그 수정
- `role.name` 웹 미니파이 오류 → `user.isAdmin` 게터 사용
- GroupService에 `getMyGroups()`, `joinGroup()` 메서드 추가

### 3. 배포
- **웹**: https://bible-speak.web.app (API 키 포함 빌드)
- **Android**: `build/app/outputs/bundle/release/app-release.aab` (47.8MB)

## 파일 변경 요약

### 생성
- `lib/screens/study/practice_setup_screen.dart` (660줄)
- `lib/screens/social/community_screen.dart` (~900줄)

### 수정
- `lib/screens/home/main_menu_screen.dart` (CommunityScreen 연결, isAdmin 수정)
- `lib/services/group_service.dart` (getMyGroups, joinGroup 추가)

### 삭제
- `lib/screens/study/book_selection_screen.dart`
- `lib/screens/study/chapter_selection_screen.dart`
- `lib/screens/study/verse_roadmap_screen.dart`
- `lib/screens/group/group_dashboard_screen.dart`
- `lib/screens/chat/group_chat_screen.dart`

## 웹 빌드 명령어 (API 키 포함)

```bash
# .env 파일에서 키를 읽어서 빌드
flutter build web --release \
  --dart-define=ESV_API_KEY=$ESV_API_KEY \
  --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY \
  --dart-define=AZURE_SPEECH_KEY=$AZURE_SPEECH_KEY \
  --dart-define=AZURE_SPEECH_REGION=koreacentral

firebase deploy --only hosting
```

**참고**: API 키는 `.env` 파일 또는 `assets/.env` 에서 확인

## 다음 작업 (TODO)

### 우선순위 높음
1. **Play Store 배포** - AAB 파일 업로드 (`app-release.aab`)
2. **TestFlight 배포** - iOS 빌드 및 업로드 (Apple Developer 계정 필요)

### 추가 통합 후보
1. **설정 화면 통합** - 알림, 테마, 캐시 설정을 하나로
2. **프로필/통계 통합** - ProfileScreen + StatsDashboardScreen

### 남은 파일 (통합 가능)
- `lib/screens/group/group_select_screen.dart` - 온보딩에서 사용 중 (유지)
- `lib/screens/social/friend_screen.dart` - 친구/대전 기능 (별도 유지 또는 통합 검토)

## Git 커밋

```
1f3ec54 refactor: Consolidate screens for improved UX
```

## 중요 URL
- **웹앱**: https://bible-speak.web.app
- **Firebase Console**: https://console.firebase.google.com/project/bible-speak
- **ESV Audio Proxy**: https://bible-speak-proxy.tlsdygksdev.workers.dev
- **GitHub**: https://github.com/onapond/bible_speak

## 서명 키 정보 (Android)
- **위치**: `android/upload-keystore.jks`
- **설정**: `android/key.properties`
- **Alias**: upload
