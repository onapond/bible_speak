# 세션 요약 - 2026년 1월 31일

## 완료된 작업

### 1. 버그 수정 (5건)

| 버그 | 원인 | 해결 |
|------|------|------|
| 오늘의 만나 한글 미표시 | DailyVerse 책이 BibleData에 없음 | dailyVerseKoreanText 파라미터 추가 |
| SnackBar 안 사라짐 | duration 미지정 | 4초 duration 추가 |
| Early Bird 달란트 미지급 | transaction.update() 실패 | set() with merge 사용 |
| 구절 달란트 미적립 | transaction.update() 실패 | set() with merge 사용 |
| ESV API 키 누락 | 빌드 스크립트 미사용 | build_web.ps1 필수 사용 |

### 2. 문서화
- `CLAUDE.md` 생성 - Claude 개발 규칙
- `docs/BUG_FIXES.md` 생성 - 버그 수정 이력
- 세션 요약 작성

### 3. 배포
- 웹앱 3회 배포 (버그 수정마다)
- 최종 배포: https://bible-speak.web.app

## 수정된 파일

### lib/screens/practice/verse_practice_screen.dart
- `dailyVerseKoreanText` 파라미터 추가
- `_loadVerses()`에서 한글 텍스트 폴백 로직 추가

### lib/screens/home/main_menu_screen.dart
- `_goToDailyVersePractice()`에서 `dailyVerseKoreanText` 전달

### lib/screens/settings/theme_settings_screen.dart
- `_showPurchaseHint()` SnackBar에 duration 추가

### lib/services/auth_service.dart
- `addTalant()` 메서드 리팩토링
- `transaction.update()` → `set()` with merge

### lib/services/social/morning_manna_service.dart
- `claimEarlyBirdBonus()` 메서드 리팩토링
- `transaction.update()` → `set()` with merge

## 핵심 학습: Firestore 업데이트 패턴

```dart
// 위험 (피하기)
transaction.update(docRef, {'field': value});

// 안전 (권장)
await docRef.set({'field': value}, SetOptions(merge: true));
```

## Git 커밋

```
38c2982 fix: Resolve multiple talent and UX bugs
```

## 다음 작업 (TODO)

### 잠재적 버그 점검
- [ ] 다른 Firestore update 사용처 확인 및 수정
- [ ] 단어 학습 달란트 적립 확인
- [ ] 그룹 통계 업데이트 확인

### 기능 개선
- [ ] Play Store 배포
- [ ] TestFlight 배포
- [ ] 설정 화면 통합

## 빌드 명령어

```powershell
# 웹 빌드 (API 키 포함 - 필수!)
powershell -ExecutionPolicy Bypass -File build_web.ps1

# 배포
firebase deploy --only hosting
```

## 중요 URL
- 웹앱: https://bible-speak.web.app
- Firebase: https://console.firebase.google.com/project/bible-speak
- GitHub: https://github.com/onapond/bible_speak
