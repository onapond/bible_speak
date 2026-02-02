# 바이블스픽 (BibleSpeak) - Claude Code 개발 규칙

## 프로젝트 소개

**바이블스픽**은 AI 발음 코칭 기술을 활용한 영어 성경 암송 학습 앱입니다.

### 핵심 학습 흐름
1. **Stage 1: Listen & Repeat** (듣고 따라하기) - 70% 통과
2. **Stage 2: Key Expressions** (핵심 표현) - 75% 통과
3. **Stage 3: Real Speak** (실전 암송) - 80% 통과

### 기술 스택
- **프레임워크**: Flutter 3.x (Android, iOS, Web)
- **백엔드**: Firebase (Auth, Firestore, Storage, FCM)
- **음성 인식**: Azure Speech Services
- **TTS**: ESV API
- **AI 피드백**: Google Gemini

### 주요 URL
- 웹앱: https://bible-speak.web.app
- Firebase: https://console.firebase.google.com/project/bible-speak
- GitHub: https://github.com/onapond/bible_speak

---

## 문서 구조

| 문서 | 용도 | 언제 참조? |
|------|------|-----------|
| `docs/CHANGELOG.md` | 변경 이력 (시간순) | 이전 작업 내역 확인 시 |
| `docs/PROJECT_STATUS.md` | 현재 상태 요약 | 프로젝트 파악, 빌드 명령어 |
| `docs/BUG_FIXES.md` | 버그 패턴 체크리스트 | 버그 수정 전 |
| `docs/SESSION_SUMMARY_*.md` | 현재 세션 기록 | 최신 1개만 유지 |
| `docs/APP_DOCUMENTATION.md` | 종합 앱 문서 | 기능/화면 상세 정보 |
| `docs/FEATURE_SPEC.md` | 기능 설계서 | 신규 기능 개발 시 |
| `docs/TECH_ARCHITECTURE.md` | 기술 아키텍처 | 구조 변경 시 |
| `DEPLOYMENT_CHECKLIST.md` | 배포 체크리스트 | 배포 전 |

---

## 세션 시작 시 필수 읽기

새 세션을 시작할 때 다음 파일들을 먼저 읽어주세요:
1. `docs/PROJECT_STATUS.md` (프로젝트 현재 상태)
2. `docs/SESSION_SUMMARY_*.md` (가장 최신 파일 - 진행 중인 작업)
3. `docs/BUG_FIXES.md` (버그 패턴)

---

## 세션 관리 규칙

### SESSION_SUMMARY 규칙
- **최신 1개만 유지**
- 세션 종료 시: 완료된 작업을 `docs/CHANGELOG.md`로 이동
- 이전 SESSION_SUMMARY 삭제

### 90% 이하 컨텍스트 시
1. 현재 작업 상태 요약
2. `docs/SESSION_SUMMARY_YYYYMMDD.md` 파일 생성/업데이트
3. 완료된 작업은 `docs/CHANGELOG.md`에 추가

### 세션 요약 파일 형식
```markdown
# 세션 요약 - YYYY년 MM월 DD일

## 완료된 작업
- 작업 내용

## 수정된 파일
- 파일 경로 및 변경 내용

## 발견된 버그 및 수정
- 버그 설명 및 해결 방법

## 다음 작업 (TODO)
- 남은 작업

## 중요 참고사항
- 주의할 점
```

---

## 빌드 및 배포 규칙

### 웹 빌드 (필수!)
**항상 `build_web.ps1` 스크립트 사용** - API 키 주입 필수
```powershell
powershell -ExecutionPolicy Bypass -File build_web.ps1
```

절대로 `flutter build web --release --no-pub` 직접 사용 금지!
(ESV API 키 등이 누락됨)

### 배포 전 체크리스트
1. [ ] `flutter analyze` 에러 없음 확인
2. [ ] `build_web.ps1`로 빌드 (API 키 주입)
3. [ ] `firebase deploy --only hosting`
4. [ ] 배포 후 ESV API 동작 확인

---

## Firestore 업데이트 패턴

### 안전한 패턴 (권장)
```dart
await docRef.set({
  'field': FieldValue.increment(1),
}, SetOptions(merge: true));
```

### 위험한 패턴 (피하기)
```dart
// 문서/필드가 없으면 실패할 수 있음
transaction.update(docRef, {...});
await docRef.update({...});
```

---

## 버그 기록

모든 버그 수정은 `docs/BUG_FIXES.md`에 기록

---

## 주요 파일 위치

### 핵심 화면
```
lib/screens/
├── home/main_menu_screen.dart           # 메인 메뉴
├── practice/verse_practice_screen.dart  # 암송 연습 (핵심)
├── review/review_screen.dart            # 복습
├── stats/stats_dashboard_screen.dart    # 통계
└── social/community_screen.dart         # 커뮤니티
```

### 핵심 서비스
```
lib/services/
├── pronunciation/azure_pronunciation_service.dart  # 발음 평가
├── social/streak_service.dart           # 연속 학습
├── review_service.dart                  # 복습 (SM-2)
├── tts_service.dart                     # TTS
└── progress_service.dart                # 진행 상태
```
