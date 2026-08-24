# 바이블스픽 (BibleSpeak)

> AI 발음 코칭 기술을 활용한 영어 성경 암송 학습 앱

## 소개

하루 10분, AI 튜터와 영어 성경 한 구절!

- **3단계 쉐도잉 학습**: 듣고 따라하기 → 핵심 표현 → 실전 암송
- **실시간 발음 교정**: 음소(Phoneme) 단위 피드백
- **게이미피케이션**: 연속 학습, 달란트, 업적 시스템

---

## 배포 상태

| 환경/플랫폼 | 상태 | URL/파일 |
|---------------|------|----------|
| **Development Web** | 분리 구성 | https://bible-speak-dev.web.app |
| **Production Web** | 배포 완료 | https://bible-speak.web.app |
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

### 브랜치와 환경

| 브랜치 | Firebase | 용도 |
|--------|----------|------|
| `codex/*`, `claude/*` | 개발 빌드만 | 개별 AI 작업 |
| `develop` | `bible-speak-dev` | 통합 개발·자동 개발 배포 |
| `master` | `bible-speak` | 검증된 운영 릴리스만 |

기본 Firebase 프로젝트는 의도적으로 설정하지 않았습니다. 모든 배포는 환경을
명시해야 하며, 잘못된 브랜치와 프로젝트 조합은 스크립트가 차단합니다.

### 1. 의존성 설치
```bash
flutter pub get
```

### 2. 서버 비밀키 설정

외부 API 키는 앱에 넣지 않고 Firebase Functions Secret으로 설정합니다.

```bash
firebase functions:secrets:set ESV_API_KEY --project prod
firebase functions:secrets:set GEMINI_API_KEY --project prod
firebase functions:secrets:set AZURE_SPEECH_KEY --project prod
firebase functions:secrets:set ELEVENLABS_API_KEY --project prod
```

이미 저장소에 노출된 키는 반드시 공급자 콘솔에서 폐기하고 새 키로 교체해야 합니다.
Google Play 구독 검증을 위해 Functions 런타임 서비스 계정에 Play Console의
앱 조회 권한도 부여해야 합니다. 세부 절차는 `docs/deploy/WEB.md`를 확인합니다.

### 3. 개발 웹 빌드

```bash
./build_web.sh development
```

기본 Functions 주소가 아닌 경우 공개 설정인 `API_BASE_URL`만 환경 변수로 지정합니다.

### 4. 개발 배포

```bash
./scripts/deploy_environment.sh development hosting
```

운영 배포는 `master`의 `v*` 태그, 깨끗한 작업 트리, 전체 검증 및 명시적
확인이 모두 필요합니다. 자세한 승격 절차는 `docs/deploy/ENVIRONMENTS.md`를
참조합니다.

---

## 문서 구조

| 파일 | 설명 |
|------|------|
| `CLAUDE.md` | Claude Code 개발 규칙 |
| `docs/deploy/ENVIRONMENTS.md` | 개발·운영 브랜치와 Firebase 승격 절차 |
| `docs/deploy/CHECKLIST.md` | 스토어 배포 체크리스트 |
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
- 개발 웹앱: https://bible-speak-dev.web.app
- Firebase Console: https://console.firebase.google.com/project/bible-speak
- 개발 Firebase Console: https://console.firebase.google.com/project/bible-speak-dev
- GitHub: https://github.com/onapond/bible_speak

---

## 라이선스

Copyright (c) 2026 Onapond. All rights reserved.
