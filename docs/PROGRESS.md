# Bible Speak Development Progress

**Last Updated**: 2026-01-27
**Last Commit**: Web recording support + secure API key management

---

## Project Overview

**Bible Speak** (바이블 스픽) is an AI-powered English Bible memorization app built with Flutter. The app uses a 3-stage learning system inspired by language learning apps like "Speak".

### Core Learning Flow
1. **Stage 1: Listen & Repeat** (듣고 따라하기) - 75% pass threshold
2. **Stage 2: Key Expressions** (핵심 표현) - 78% pass threshold
3. **Stage 3: Real Speak** (실전 암송) - 80% pass threshold

### Deployment URLs
- **Web App**: https://bible-speak.web.app
- **Audio Proxy**: https://bible-speak-proxy.tlsdygksdev.workers.dev

---

## Completed Tasks

### Phase 1-4 (Previous Sessions)
- [x] iOS permission setup (`ios/Runner/Info.plist`)
- [x] Firestore progress migration (`lib/services/progress_service.dart`)
- [x] Learning stage model (`lib/models/learning_stage.dart`)
- [x] Verse progress model (`lib/models/verse_progress.dart`)
- [x] 3-stage learning UI in VersePracticeScreen
- [x] Business plan documentation (`docs/BUSINESS_PLAN.md`)
- [x] Feature specification (`docs/FEATURE_SPEC.md`)
- [x] Technical architecture (`docs/TECH_ARCHITECTURE.md`)
- [x] Marketing plan (`docs/MARKETING_PLAN.md`)

### Task 1: Speak-style Roadmap UI (2026-01-26)
- [x] Created `VerseRoadmapScreen` with dark theme
- [x] Node-based verse visualization with status icons
- [x] 3-stage progress indicators per verse
- [x] Pulse animation for current learning verse
- [x] Bottom detail panel with verse preview
- [x] Modified `ChapterSelectionScreen` navigation flow
- [x] Added `initialVerse` parameter to `VersePracticeScreen`

### Task 2: Azure Speech API Integration (2026-01-27)
- [x] Azure Speech Services 연동 (Korea Central)
- [x] 발음 평가 기능 구현 (Pronunciation Assessment)
- [x] 녹음 형식 WAV로 변경 (PCM 16-bit, 16kHz, mono)
- [x] 점수 계산 로직 최적화 (정확도 80% 가중치)
- [x] 통과 기준 조정 (75/78/80점)

### Task 3: Web Deployment (2026-01-27)
- [x] Flutter Web 빌드 설정
- [x] Firebase Hosting 배포
- [x] AppConfig 생성 (웹/모바일 설정 분기)
- [x] 웹용 녹음 서비스 (`record` 패키지)
- [x] 플랫폼별 오디오 로더 (conditional imports)
- [x] Cloudflare Worker 오디오 프록시 구현
- [x] CORS 문제 해결

### Task 4: Web Recording Support (2026-01-27)
- [x] VersePracticeScreen 웹 녹음 활성화
- [x] opus/webm 오디오 포맷 지원 (웹용)
- [x] blob URL에서 오디오 데이터 로드 (`AudioLoader`)
- [x] Azure Speech API 웹 오디오 Content-Type 처리
- [x] 웹에서 "내 목소리" 재생 기능 (`UrlSource`)
- [x] `--dart-define`으로 보안 API 키 관리
- [x] 빌드 스크립트 생성 (`build_web.ps1`, `build_web.sh`)

---

## Web Architecture

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   Flutter Web App   │────▶│  Cloudflare Worker   │────▶│    ESV API      │
│ (Firebase Hosting)  │     │   (Audio Proxy)      │     │  (Audio Data)   │
└─────────────────────┘     └──────────────────────┘     └─────────────────┘
         │
         ▼
┌─────────────────────┐
│   Azure Speech API  │
│ (Pronunciation)     │
└─────────────────────┘
```

---

## Pending Tasks

### Task 5: Word Study Integration
**Status**: Not started
**Description**: Integrate Gemini API for keyword extraction from verses

### Task 6: Advanced Feedback UI
**Status**: Not started
**Description**: Enhanced pronunciation feedback display

### Task 7: Daily Streak Gamification
**Status**: Not started
**Description**: Implement streak tracking and rewards

### Task 8: iOS App Store Deployment
**Status**: Not started
**Description**: macOS 환경에서 iOS 빌드 및 앱스토어 배포

---

## API Configuration

### Azure Speech Services ✓
- **Region**: Korea Central
- **Pricing**: F0 (Free - 5 hours/month)
- **Features**: Pronunciation Assessment, Prosody, Miscue Detection

### ESV API ✓
- **Audio**: Via Cloudflare Worker proxy (web), Direct (mobile)
- **Text**: Direct API call

### Gemini API ✓
- **Usage**: AI 튜터 피드백 생성

### ElevenLabs API ✓
- **Usage**: 일반 TTS (단어 학습용)

---

## Key Files Reference

### Config
| File | Purpose |
|------|---------|
| `lib/config/app_config.dart` | **NEW** 웹/모바일 설정 분기 |
| `.env` | API 키 (모바일용) |
| `firebase.json` | Firebase 설정 |

### Models
| File | Purpose |
|------|---------|
| `lib/models/learning_stage.dart` | 3-stage learning enum with thresholds |
| `lib/models/verse_progress.dart` | Verse-level progress tracking |

### Services
| File | Purpose |
|------|---------|
| `lib/services/tts_service.dart` | TTS with web proxy support |
| `lib/services/recording_service.dart` | 웹/모바일 녹음 (record 패키지) |
| `lib/services/pronunciation/azure_pronunciation_service.dart` | 발음 평가 |
| `lib/services/pronunciation/audio_loader.dart` | 플랫폼별 오디오 로딩 |

### Proxy & Build
| File | Purpose |
|------|---------|
| `cloudflare-worker/worker.js` | ESV Audio CORS 프록시 |
| `build_web.ps1` | Windows 웹 빌드 스크립트 |
| `build_web.sh` | Mac/Linux 웹 빌드 스크립트 |

---

## Build & Deploy Commands

```bash
# Android 빌드
flutter build apk

# 연결된 기기에서 실행
flutter run

# Web 빌드
flutter build web --release

# Firebase Hosting 배포
firebase deploy --only hosting --project bible-speak

# Cloudflare Worker 배포
# dash.cloudflare.com에서 Quick Edit 사용
```

---

## Environment Variables

`.env` 파일:
```
ESV_API_KEY=...
GEMINI_API_KEY=...
ELEVENLABS_API_KEY=...
AZURE_SPEECH_KEY=...
AZURE_SPEECH_REGION=koreacentral
```

### 빌드 시 환경 변수 주입
웹 빌드 시 `--dart-define`으로 API 키를 주입합니다:

```bash
# Windows (PowerShell)
.\build_web.ps1

# Mac/Linux
./build_web.sh
```

빌드 스크립트가 `.env` 파일에서 자동으로 키를 읽어 주입합니다.

---

## Web Limitations

| 기능 | 웹 지원 | 비고 |
|------|---------|------|
| 성경 텍스트 로딩 | ✅ | Firestore |
| 오디오 재생 | ✅ | Cloudflare Worker 프록시 |
| 녹음 | ✅ | Web Audio API |
| 발음 평가 | ✅ | Azure Speech API |
| 로컬 캐시 | ❌ | 웹 미지원 |

---

## Next Steps

1. **단어 학습**: Gemini API로 핵심 단어 추출
2. **게이미피케이션**: 연속 학습 스트릭, 달란트 시스템
3. **피드백 UI 개선**: 음파 시각화, 단어별 정확도 표시
4. **iOS 배포**: macOS 환경 필요

---

## Session Continuity (다음 세션용 요약)

### 마지막 세션 작업 (2026-01-27)

**목표**: iPhone 사용자가 웹 브라우저로 앱 테스트 가능하게 하기

**완료된 작업**:

1. **웹 배포 완료**
   - Firebase Hosting: https://bible-speak.web.app
   - Cloudflare Worker (CORS 프록시): https://bible-speak-proxy.tlsdygksdev.workers.dev

2. **웹 녹음 기능 구현**
   - `record` 패키지로 웹 녹음 (opus/webm 포맷)
   - `AudioLoader`로 blob URL에서 오디오 바이트 추출
   - Azure Speech API 웹 오디오 처리 (Content-Type: audio/webm; codecs=opus)
   - VersePracticeScreen 웹 녹음 활성화

3. **보안 개선**
   - API 키 하드코딩 제거 (GitHub push 차단 해결)
   - `--dart-define`으로 빌드 시점 주입
   - 빌드 스크립트 생성 (`build_web.ps1`, `build_web.sh`)

### 주요 파일 변경

| 파일 | 변경 내용 |
|------|----------|
| `lib/config/app_config.dart` | `String.fromEnvironment` 사용 |
| `lib/screens/practice/verse_practice_screen.dart` | 웹 녹음 활성화, blob URL 재생 |
| `lib/services/recording_service.dart` | opus/webm 포맷 지원 |
| `lib/services/pronunciation/azure_pronunciation_service.dart` | 웹 오디오 Content-Type |
| `build_web.ps1`, `build_web.sh` | 빌드 스크립트 생성 |

### 테스트 상태

- ✅ 웹 오디오 재생 (ESV API via Cloudflare Worker)
- ✅ 웹 녹음 (opus/webm)
- ✅ 웹 발음 평가 (Azure Speech API)
- ⚠️ iOS 앱 미배포 (macOS 환경 필요)

### 다음 작업 제안

1. 웹에서 녹음 테스트 및 발음 평가 확인
2. 단어 학습 기능 구현 (Gemini API)
3. 게이미피케이션 (스트릭, 달란트)
4. iOS 앱스토어 배포 준비 (macOS 필요)
