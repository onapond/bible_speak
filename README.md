# 바이블스픽 (BibleSpeak)

> AI 발음 코칭 기술을 활용한 영어 성경 암송 학습 앱

## 소개

하루 10분, AI 튜터와 영어 성경 한 구절!

- **3단계 쉐도잉 학습**: 듣고 따라하기 → 핵심 표현 → 실전 암송
- **실시간 발음 교정**: 음소(Phoneme) 단위 피드백
- **게이미피케이션**: 연속 학습, 달란트, 업적 시스템

---

## 배포 상태

| 플랫폼 | 상태 | URL/파일 |
|--------|------|----------|
| **Web** | 배포 완료 | https://bible-speak.web.app |
| **Android** | 빌드 완료 | `build/app/outputs/bundle/release/app-release.aab` |
| **iOS** | 대기 중 | TestFlight (macOS 필요) |

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.x / Dart |
| 상태 관리 | Riverpod (주력) + Provider (레거시) |
| 백엔드 | Firebase (Auth, Firestore, FCM) |
| 음성 인식 | Azure Speech Services |
| TTS | ESV API |
| AI 피드백 | Google Gemini |
| 오프라인 | Hive |

---

## 빠른 시작

### 1. 의존성 설치
```bash
flutter pub get
```

### 2. 서버 비밀키 설정

외부 API 키는 앱에 넣지 않고 Firebase Functions Secret으로 설정합니다.

```bash
firebase functions:secrets:set ESV_API_KEY
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set AZURE_SPEECH_KEY
firebase functions:secrets:set ELEVENLABS_API_KEY
firebase functions:secrets:set APPLE_APP_ID
firebase functions:secrets:set APPLE_IAP_KEY_ID
firebase functions:secrets:set APPLE_IAP_ISSUER_ID
firebase functions:secrets:set APPLE_IAP_PRIVATE_KEY
firebase deploy --only functions
```

이미 저장소에 노출된 키는 반드시 공급자 콘솔에서 폐기하고 새 키로 교체해야 합니다.
Google Play 구독 검증을 위해 Functions 런타임 서비스 계정에 Play Console의
앱 조회 권한도 부여해야 합니다. 세부 절차는 `docs/deploy/WEB.md`를 확인합니다.

### 3. 웹 빌드
```powershell
powershell -ExecutionPolicy Bypass -File build_web.ps1
```

기본 Functions 주소가 아닌 경우 공개 설정인 `API_BASE_URL`만 환경 변수로 지정합니다.

### 4. 배포
```bash
firebase deploy --only hosting
```

---

## 문서 구조

| 파일 | 설명 |
|------|------|
| `CLAUDE.md` | Claude Code 개발 규칙 |
| `ARCHITECTURE.md` | 아키텍처 결정 및 코딩 규칙 |
| `DEPLOYMENT_CHECKLIST.md` | 스토어 배포 체크리스트 |
| `docs/PROJECT_STATUS.md` | 프로젝트 현재 상태 |
| `docs/PROGRESS.md` | 개발 히스토리 |
| `docs/BUG_FIXES.md` | 버그 수정 이력 |

---

## 주요 기능

### 학습
- 3단계 학습 시스템 (Listen & Repeat → Key Expressions → Real Speak)
- AI 발음 평가 (Azure Speech Services)
- AI 튜터 피드백 (Google Gemini)
- 스마트 복습 (SM-2 알고리즘)

### 게이미피케이션
- 연속 학습 (Streak) 시스템
- 업적 및 레벨 시스템
- 달란트 샵
- 아침 만나 (Early Bird 보너스)

### 소셜
- 그룹 챌린지
- 그룹 채팅
- 활동 피드
- 찌르기 시스템

---

## 관련 링크

- 웹앱: https://bible-speak.web.app
- Firebase Console: https://console.firebase.google.com/project/bible-speak
- GitHub: https://github.com/onapond/bible_speak

---

## 라이선스

Copyright (c) 2026 Onapond. All rights reserved.
