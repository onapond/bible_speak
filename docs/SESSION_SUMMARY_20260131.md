# 세션 요약 - 2026년 1월 31일 (최종)

## 완료된 작업

### 1. Firestore update 패턴 전체 점검 및 수정
모든 `transaction.update()` 및 `.update()` 패턴을 `set(merge: true)` 패턴으로 수정 (10개 서비스)

### 2. 추가 버그 수정 (4건)

| # | 버그 | 원인 | 해결 |
|---|------|------|------|
| 6 | 퀴즈 제출 오류 | Transaction 읽기/쓰기 순서 문제 | Transaction 없이 개별 호출 |
| 7 | 샵 달란트 0원 | AuthService 캐시 문제 | Firestore 직접 조회 |
| 8 | 업적 미작동 | 체크 메서드 미호출 | _checkAchievements() 추가 |
| 9 | 폰트 로딩 지연 | 비동기 폰트 로딩 | document.fonts.ready 대기 |

## 수정된 파일 목록

```
lib/services/daily_quiz_service.dart      # 퀴즈 transaction 제거
lib/services/shop_service.dart            # getUserTalants() 추가
lib/screens/shop/shop_screen.dart         # Firestore 직접 조회
lib/screens/practice/verse_practice_screen.dart  # 업적 체크 추가
web/index.html                            # 폰트 로딩 대기
docs/BUG_FIXES.md                         # 버그 이력 추가
```

## Git 커밋

```
6522014 fix: Replace Firestore update() with set(merge: true) for safety
```

## 배포

- 웹앱: https://bible-speak.web.app (2회 배포)

## 다음 작업 (TODO)

### 설정 화면 통합 (완료)
- [x] 접근성 설정 메뉴 추가
- [x] 앱 정보 다이얼로그 추가

### 스토어 배포
- [ ] Play Store 배포
- [ ] TestFlight 배포

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
