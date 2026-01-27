# Bible Speak Development Progress

**Last Updated**: 2026-01-27
**Last Commit**: Web deployment with Cloudflare Worker audio proxy

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

### Task 4: Word Study Integration
**Status**: Not started
**Description**: Integrate Gemini API for keyword extraction from verses

### Task 5: Advanced Feedback UI
**Status**: Not started
**Description**: Enhanced pronunciation feedback display

### Task 6: Daily Streak Gamification
**Status**: Not started
**Description**: Implement streak tracking and rewards

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

### Proxy
| File | Purpose |
|------|---------|
| `cloudflare-worker/worker.js` | ESV Audio CORS 프록시 |

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

`.env` 파일 (모바일용):
```
ESV_API_KEY=...
GEMINI_API_KEY=...
ELEVENLABS_API_KEY=...
AZURE_SPEECH_KEY=...
AZURE_SPEECH_REGION=koreacentral
```

웹에서는 `AppConfig`에 하드코딩된 값 사용 (dotenv 미지원)

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
