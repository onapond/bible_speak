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

### 2. 환경 변수 설정
`.env` 파일 생성:
```
ESV_API_KEY=...
GEMINI_API_KEY=...
AZURE_SPEECH_KEY=...
AZURE_SPEECH_REGION=koreacentral
```

### 3. 웹 빌드 (API 키 주입 필수)
```powershell
powershell -ExecutionPolicy Bypass -File build_web.ps1
```

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
