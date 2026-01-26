# Bible Speak Development Progress

**Last Updated**: 2026-01-26
**Last Commit**: `1b6ecf8` - feat: Add Speak-style verse roadmap UI

---

## Project Overview

**Bible Speak** (바이블 스픽) is an AI-powered English Bible memorization app built with Flutter. The app uses a 3-stage learning system inspired by language learning apps like "Speak".

### Core Learning Flow
1. **Stage 1: Listen & Repeat** (듣고 따라하기) - 70% pass threshold
2. **Stage 2: Key Expressions** (핵심 표현) - 80% pass threshold
3. **Stage 3: Real Speak** (실전 암송) - 85% pass threshold

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

---

## Pending Tasks

### Task 2: Word Study Integration
**Status**: Not started
**Description**: Integrate Gemini API for keyword extraction from verses
- Extract key vocabulary from each verse
- Show word definitions and usage examples
- Track vocabulary learning progress

### Task 3: Advanced Feedback UI
**Status**: Not started
**Description**: Enhanced pronunciation feedback display
- Visual waveform comparison
- Word-by-word accuracy breakdown
- Improvement suggestions

### Task 4: Daily Streak Gamification
**Status**: Not started
**Description**: Implement streak tracking and rewards
- Daily login streak counter
- Talent (달란트) reward system
- Achievement badges

---

## Current Blocker: Pronunciation API

### Issue
The app needs a pronunciation assessment API for speech recognition and scoring.

### Original Plan: Azure Speech Services
- Microsoft authentication was failing with user's credit card
- Azure setup abandoned

### New Plan: Google Cloud Speech-to-Text
**Status**: User setting up Google Cloud account

**Setup Steps**:
1. Go to https://console.cloud.google.com
2. Create project "bible-speak"
3. Link billing (new accounts get $300 free credits)
4. Enable Speech-to-Text API
5. Create API key
6. Add to `.env`: `GOOGLE_CLOUD_API_KEY=your_key_here`

**Code Changes Required**:
Once API key is obtained, modify:
- `lib/services/pronunciation/azure_pronunciation_service.dart` → rename/replace
- Create `lib/services/pronunciation/google_speech_service.dart`
- Update service registration in app initialization

---

## Key Files Reference

### Models
| File | Purpose |
|------|---------|
| `lib/models/learning_stage.dart` | 3-stage learning enum with thresholds |
| `lib/models/verse_progress.dart` | Verse-level progress tracking |
| `lib/domain/models/bible/bible_models.dart` | Bible data structures |

### Screens
| File | Purpose |
|------|---------|
| `lib/screens/study/chapter_selection_screen.dart` | Chapter roadmap with curved path |
| `lib/screens/study/verse_roadmap_screen.dart` | **NEW** Verse-level roadmap UI |
| `lib/screens/practice/verse_practice_screen.dart` | Main practice screen with 3 stages |

### Services
| File | Purpose |
|------|---------|
| `lib/services/progress_service.dart` | Firestore progress sync |
| `lib/services/bible_data_service.dart` | Bible data from Firestore |
| `lib/services/tts_service.dart` | Text-to-speech |
| `lib/services/pronunciation/azure_pronunciation_service.dart` | **NEEDS REPLACEMENT** |

---

## Build Commands

```bash
# Android build
flutter build apk

# Run on connected device
flutter run

# Analyze code
flutter analyze

# iOS build (requires macOS)
cd ios && pod install && cd ..
flutter build ios --no-codesign
```

---

## Environment Variables

Required in `.env` file:
```
FIREBASE_API_KEY=...
GOOGLE_CLOUD_API_KEY=...  # Pending setup
```

---

## Next Steps for Future Sessions

1. **If Google Cloud API key is ready**: Implement Google Speech service
2. **If API not ready**: Continue with Task 2 (Word Study) or Task 4 (Gamification)
3. **For iOS testing**: Need macOS environment

---

## Architecture Notes

- **State Management**: StatefulWidget with setState (no external state management)
- **Backend**: Firebase/Firestore
- **Authentication**: Firebase Auth via `AuthService`
- **Navigation**: Standard Navigator push/pop
- **Theme**: Dark theme with blue/purple gradient accents
