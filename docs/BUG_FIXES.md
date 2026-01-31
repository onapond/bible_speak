# 버그 수정 이력

## 2026-01-31 (3차 수정)

### 10. 로그인 시 프로필 설정 반복 + 회원가입 실패
**증상**:
- 기존 사용자가 로그인하면 프로필 설정 화면이 다시 나옴
- 닉네임 입력해도 넘어가지 않음

**원인**:
- `ProfileSetupScreen`에서 `registerAnonymous()` 호출
- 이 메서드가 **새 익명 Firebase Auth 계정**을 생성함
- Google 로그인 UID와 다른 UID가 생성되어 연결 안 됨

**해결**:
- `registerAnonymous()` → `completeProfile()` 변경
- 이메일 기반 기존 사용자 검색 로직 추가
- 오류 처리를 위한 try-catch 추가

**수정 파일**:
- `lib/screens/auth/profile_setup_screen.dart`
- `lib/services/auth_service.dart`

**미해결**:
- 이전에 익명 계정으로 가입한 사용자는 이메일이 저장되지 않아 마이그레이션 불가
- Firebase Console에서 수동 데이터 마이그레이션 필요

---

### 11. 로딩 화면 폰트 크기 변동
**증상**: 로딩 화면에서 "바이블 스픽" 글씨와 아이콘이 점진적으로 커짐

**원인**:
- Google Fonts `display=swap` 사용
- 시스템 폰트 → 웹 폰트 교체 시 크기 변동

**해결**:
- `display=block`으로 변경 (폰트 로드 전까지 텍스트 숨김)
- 로딩 화면에 시스템 폰트 강제 적용 (`!important`)
- 아이콘 크기 고정 (width, height)

**수정 파일**:
- `web/index.html`

---

## 2026-01-31 (2차 수정)

### 6. 일일 퀴즈 제출 오류
**증상**: 퀴즈 제출 시 오류 발생

**원인**:
- Transaction 내에서 읽기/쓰기 순서 문제
- `_updateStreak`에서 `transaction.get()` 후 `transaction.set()` 호출

**해결**:
- Transaction 없이 개별 Firestore 호출로 변경
- `_updateStreakSimple()` 메서드 신규 생성

**수정 파일**:
- `lib/services/daily_quiz_service.dart`

---

### 7. 샵 달란트 0원 표시
**증상**: 아이템 샵 상단 달란트가 0원으로 표기됨

**원인**:
- `_authService.currentUser?.talants` 사용
- AuthService의 캐시된 데이터가 최신이 아님

**해결**:
- `ShopService.getUserTalants()` 메서드 추가
- Firestore에서 직접 달란트 조회

**수정 파일**:
- `lib/services/shop_service.dart`
- `lib/screens/shop/shop_screen.dart`

---

### 8. 업적 달성 미작동
**증상**: 업적 달성이 진행되지 않음

**원인**:
- `checkVerseAchievements()`, `checkTalantAchievements()` 메서드가 어디서도 호출되지 않음

**해결**:
- `VersePracticeScreen`에 `_checkAchievements()` 메서드 추가
- 달란트 적립 후 업적 체크 호출

**수정 파일**:
- `lib/screens/practice/verse_practice_screen.dart`

---

### 9. 폰트 로딩 지연
**증상**: 로그인 시 아이콘/한글이 깨졌다가 표시됨

**원인**:
- Flutter 웹 폰트 비동기 로딩
- 첫 프레임 렌더링 시 폰트 미로드

**해결**:
- `document.fonts.ready` 대기 후 로딩 화면 숨김
- 추가 100ms 딜레이로 안정화

**수정 파일**:
- `web/index.html`

---

## 2026-01-31

### 1. 오늘의 만나 한글 텍스트 미표시
**증상**: "오늘의 만나"에서 "오늘의 구절 암송하기" 클릭 시 영어만 표시되고 한글이 안 나옴

**원인**:
- `DailyVerse`는 proverbs, psalms, john 등 다양한 책의 구절 포함
- `BibleData.getKoreanVerse()`는 malachi, philippians, hebrews, ephesians만 지원
- 지원하지 않는 책의 한글 번역이 null 반환

**해결**:
- `VersePracticeScreen`에 `dailyVerseKoreanText` 파라미터 추가
- `DailyVerse.textKo`를 직접 전달하여 사용

**수정 파일**:
- `lib/screens/practice/verse_practice_screen.dart`
- `lib/screens/home/main_menu_screen.dart`

---

### 2. 테마 설정 SnackBar 안 사라짐
**증상**: 샵에서 오션테마 구매 클릭 시 "샵에서 구매할 수 있습니다" SnackBar가 계속 남아있음

**원인**: SnackBar에 action 버튼이 있으면 duration 미지정 시 무한히 표시됨

**해결**: `duration: const Duration(seconds: 4)` 추가

**수정 파일**:
- `lib/screens/settings/theme_settings_screen.dart` (line 420)

---

### 3. Early Bird 달란트 미지급
**증상**: 오늘의 만나 Early Bird 보너스 표시되지만 실제 달란트 미증가

**원인**:
- `transaction.update()` 사용
- earlyBird 필드가 없는 문서에서 실패

**해결**:
```dart
// Before
transaction.update(userRef, {...});

// After
await userRef.set({...}, SetOptions(merge: true));
```

**수정 파일**:
- `lib/services/social/morning_manna_service.dart`

---

### 4. 구절 암송 달란트 미적립
**증상**: Stage 3 통과 시 "달란트 +1 획득!" 메시지 표시되지만 실제 카운트 미증가

**원인**:
- `addTalant()` 메서드에서 `transaction.update()` 사용
- Firestore 문서 구조 불완전 시 실패

**해결**:
```dart
// Before
await _firestore.runTransaction((transaction) async {
  transaction.update(userRef, {...});
});

// After
await userRef.set({
  'talants': FieldValue.increment(1),
  'completedVerses': FieldValue.arrayUnion([verseNumber]),
}, SetOptions(merge: true));
```

**수정 파일**:
- `lib/services/auth_service.dart`

---

### 5. ESV API 키 누락 (반복 발생)
**증상**: 말라기 암송 시작 시 ESV API 오류 발생

**원인**:
- `flutter build web --release --no-pub` 직접 사용
- `--dart-define`으로 API 키 주입 누락

**해결**:
- 항상 `build_web.ps1` 스크립트 사용
- CLAUDE.md에 규칙 문서화

**관련 파일**:
- `build_web.ps1`
- `lib/config/app_config.dart`

---

## 공통 패턴: Firestore 업데이트 문제

### 문제 패턴
```dart
// 위험: 문서/필드 없으면 실패
transaction.update(docRef, {'field': value});
await docRef.update({'field': value});
```

### 안전한 패턴
```dart
// 안전: 문서/필드 없어도 생성하며 업데이트
await docRef.set({
  'field': FieldValue.increment(1),
}, SetOptions(merge: true));
```

### 영향받는 기능들 (모두 수정 완료)
- [x] 달란트 적립 (`auth_service.dart`)
- [x] Early Bird 보너스 (`morning_manna_service.dart`)
- [x] 단어 학습 달란트 (`auth_service.dart`)
- [x] 일일 목표 보너스 (`auth_service.dart`)
- [x] 일일 퀴즈 달란트/스트릭 (`daily_quiz_service.dart`)
- [x] 업적 보상 (`achievement_service.dart`)
- [x] 샵 구매/인벤토리 (`shop_service.dart`)
- [x] 배틀 승/패/무승부 (`battle_service.dart`)
- [x] 그룹 챌린지 (`group_challenge_service.dart`)
- [x] 그룹 활동 리액션 (`group_activity_service.dart`)
- [x] 찌르기 읽음/응답 (`nudge_service.dart`)
- [x] 친구 요청 수락/거절 (`friend_service.dart`)
- [x] 채팅 메시지/읽음 (`chat_service.dart`)

---

## 체크리스트: 새로운 Firestore 업데이트 코드 작성 시
1. [ ] `transaction.update()` 대신 `set()` with `SetOptions(merge: true)` 사용
2. [ ] 중첩 필드는 map 형태로 전달 (dot notation 피하기)
3. [ ] 에러 로깅 추가
4. [ ] 실제 Firestore에서 데이터 확인
