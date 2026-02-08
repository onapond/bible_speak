# Bible Speak Development Progress

**Last Updated**: 2026-02-07
**Last Commit**: Claude Code hooks/skills setup + CLAUDE.md rules update

---

## Project Overview

**Bible Speak** (바이블 스픽) is an AI-powered English Bible memorization app built with Flutter. The app uses a 3-stage learning system inspired by language learning apps like "Speak".

### Core Learning Flow
1. **Stage 1: Listen & Repeat** (듣고 따라하기) - 70% pass threshold
2. **Stage 2: Key Expressions** (핵심 표현) - 75% pass threshold
3. **Stage 3: Real Speak** (실전 암송) - 80% pass threshold

### Deployment URLs
- **Web App**: https://bible-speak.web.app
- **Audio Proxy**: https://bible-speak-proxy.tlsdygksdev.workers.dev

---

## Development Roadmap

```
Phase 1-4: 기본 인프라 ✅
    │
    ├── iOS/Android 권한 설정
    ├── Firestore 데이터 구조
    ├── 3단계 학습 모델
    └── 기획/기술 문서화

Task 1: Roadmap UI ✅ (2026-01-26)
    │
    └── Speak 스타일 구절 로드맵 화면

Task 2: Azure Speech API ✅ (2026-01-27)
    │
    └── 발음 평가 기능 구현

Task 3: Web Deployment ✅ (2026-01-27)
    │
    ├── Firebase Hosting 배포
    ├── Cloudflare Worker (CORS 프록시)
    └── 보안 API 키 관리 (--dart-define)

Task 4: Web Recording ✅ (2026-01-27)
    │
    └── 웹 브라우저 녹음 기능 활성화

Task 5: Audio Fix & Optimization ✅ (2026-01-27)
    │
    ├── WAV 포맷으로 웹 녹음 (Azure 호환)
    ├── 통과 기준 조정 (70/75/80%)
    └── 병렬 로딩 최적화

Task 6-10: 게이미피케이션 & 소셜 ✅ (2026-01-28~30)
    │
    ├── 연속 학습 (Streak) 시스템
    ├── 업적 및 레벨 시스템
    ├── 달란트 샵
    ├── 그룹 챌린지/채팅
    └── 찌르기 시스템

Task 11: Firestore 안전 패턴 ✅ (2026-01-31)
    │
    └── update() → set(merge:true) 전환 (13개 서비스)

Task 12: Riverpod 도입 ✅ (2026-02-05)
    │
    ├── lib/providers/ 폴더 생성
    ├── core_providers, auth_provider, progress_provider
    └── Tier 1 화면 마이그레이션 (7개)

Task 13: Parchment 테마 강화 ✅ (2026-02-06)
    │
    ├── texture_provider.dart
    ├── parchment_texture_overlay.dart
    └── Perlin 노이즈 + 그레인 노이즈

Task 14: PWA 버그 수정 ✅ (2026-02-06)
    │
    └── 무한 새로고침 → sessionStorage 플래그

Task 15: Claude Code 툴링 ✅ (2026-02-07)
    │
    ├── Hook 수정 (python3 → node)
    ├── 커스텀 스킬 5개 (deploy, commit, diagnose, session-start, perf-optimize)
    └── CLAUDE.md 규칙 강화 (report 추천)

Task 16: iOS Deployment (예정)
    │
    └── App Store 배포 (macOS 필요)

Task 17: 텍스처 설정 UI (예정)
    │
    └── 설정 화면에서 텍스처 강도 조절 / 토글

Task 18: 발음 피드백 UI 강화 (예정)
    │
    └── 음파 시각화, 단어별 피드백 표시
```

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
- [x] blob URL에서 오디오 데이터 로드 (`AudioLoader`)
- [x] 웹에서 "내 목소리" 재생 기능 (`UrlSource`)
- [x] `--dart-define`으로 보안 API 키 관리
- [x] 빌드 스크립트 생성 (`build_web.ps1`, `build_web.sh`)

### Task 5: Web Audio Fix & Performance Optimization (2026-01-27)
- [x] 웹 녹음 형식 WAV로 변경 (opus/webm → wav)
- [x] Azure가 웹 오디오 정상 인식 (0점 → 90점)
- [x] 통과 기준 조정: Stage 1 (70%), Stage 2 (75%), Stage 3 (80%)
- [x] API 타임아웃 단축: 45초 → 15초
- [x] 재시도 최적화: 3회/2초 → 2회/1초
- [x] 한글 번역 병렬 로딩 (`Future.wait`)
- [x] 진행도 데이터 병렬 로딩 (`Future.wait`)

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

### Task 16: iOS App Store Deployment
**Status**: Not started
**Description**: macOS 환경에서 iOS 빌드 및 앱스토어 배포

### Task 17: 텍스처 설정 UI
**Status**: Not started
**Description**: 설정 화면에서 텍스처 강도 조절 슬라이더 및 토글 기능 추가

### Task 18: 발음 피드백 UI 강화
**Status**: Not started
**Description**: 음파 시각화, 단어별 발음 점수 표시 등 피드백 UI 개선

---

## API Configuration

### Azure Speech Services ✓
- **Region**: Korea Central
- **Pricing**: F0 (Free - 5 hours/month)
- **Features**: Pronunciation Assessment, Prosody, Miscue Detection
- **Audio Format**: WAV (PCM 16-bit, 16kHz, mono)

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
| `lib/config/app_config.dart` | 웹/모바일 설정 분기 |
| `.env` | API 키 (모바일용) |
| `firebase.json` | Firebase 설정 |

### Models
| File | Purpose |
|------|---------|
| `lib/models/learning_stage.dart` | 3-stage learning enum (70/75/80%) |
| `lib/models/verse_progress.dart` | Verse-level progress tracking |

### Services
| File | Purpose |
|------|---------|
| `lib/services/tts_service.dart` | TTS with web proxy support |
| `lib/services/recording_service.dart` | 웹(WAV)/모바일(WAV) 녹음 |
| `lib/services/pronunciation/azure_pronunciation_service.dart` | 발음 평가 (15초 타임아웃) |
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
# Web 빌드 (권장 - API 키 자동 주입)
# Windows
.\build_web.ps1

# Mac/Linux
./build_web.sh

# Firebase Hosting 배포
firebase deploy --only hosting

# Android 빌드
flutter build apk

# 연결된 기기에서 실행
flutter run
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

빌드 스크립트가 `.env` 파일에서 자동으로 키를 읽어 `--dart-define`으로 주입합니다.

---

## Platform Support

| 기능 | Android | iOS | Web |
|------|---------|-----|-----|
| 성경 텍스트 | ✅ | ✅ | ✅ |
| 오디오 재생 | ✅ | ✅ | ✅ (프록시) |
| 녹음 | ✅ WAV | ✅ WAV | ✅ WAV |
| 발음 평가 | ✅ | ✅ | ✅ |
| 로컬 캐시 | ✅ | ✅ | ❌ |

---

## Session Continuity (다음 세션용 요약)

### 마지막 세션 작업 (2026-02-07)

**목표**: Claude Code 개발 도구 강화

**완료 사항**:
1. Hook 수정 — python3 → node (Windows 호환)
2. 커스텀 스킬 5개 생성 (deploy, commit, diagnose, session-start, perf-optimize)
3. CLAUDE.md에 report 추천 규칙 6개 추가
4. .gitignore 정리 (hooks/skills 추적)

### 주요 커밋

```
1597520 docs: Add session summary for 2026-02-07
e1ec490 docs: Add report-recommended rules to CLAUDE.md
2a9625a feat: Add custom Claude skills
db44eae fix: Use node instead of python3 for Claude hook JSON parsing
```

### 다음 작업 제안

1. iOS 앱스토어 배포 (macOS 필요)
2. 텍스처 설정 UI (강도 조절/토글)
3. 발음 피드백 UI 강화 (음파 시각화)
