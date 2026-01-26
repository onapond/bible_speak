# 바이블 스픽 2.0 - 상업화 리팩토링 제안서

**작성일**: 2025년 1월 26일
**목적**: MVP에서 상업용 확장 가능한 앱으로 전환

---

## 목차

1. [현재 구조 분석](#1-현재-구조-분석)
2. [Firestore 스키마 설계](#2-firestore-스키마-설계)
3. [하이브리드 오디오 아키텍처](#3-하이브리드-오디오-아키텍처)
4. [TutorCoordinator 클래스 설계](#4-tutorcoordinator-클래스-설계)
5. [제안 디렉토리 구조](#5-제안-디렉토리-구조)
6. [마이그레이션 계획](#6-마이그레이션-계획)
7. [확인 필요 사항](#7-확인-필요-사항)

---

## 1. 현재 구조 분석

### 1.1 현재 데이터 구조 (lib/data/)

| 파일 | 내용 | 문제점 |
|------|------|--------|
| `korean_verses.dart` | 말라기, 빌립보서 한글 번역 | 하드코딩 |
| `korean_ephesians.dart` | 에베소서 한글 번역 | 하드코딩 |
| `korean_hebrews_1.dart` | 히브리서 1-7장 | 하드코딩 |
| `korean_hebrews_2.dart` | 히브리서 8-13장 | 하드코딩 |
| `bible_data.dart` | 책 메타데이터 | 확장 어려움 |
| `malachi_words.dart` | 말라기 1장 단어 | 하드코딩 |

### 1.2 현재 오디오 처리

```
현재 플로우:
ESV API (실시간 호출) → 로컬 캐시 → 재생

문제점:
- API 호출 비용 증가
- 네트워크 의존성
- 일관성 없는 응답 시간
```

### 1.3 현재 피드백 시스템

```
Azure 발음 평가 → 점수 표시 (단순)

문제점:
- 개인화된 피드백 없음
- 격려 메시지 부족
- Speak 앱 대비 UX 열세
```

---

## 2. Firestore 스키마 설계

### 2.1 전체 구조

```
📦 Firestore Database
│
├── 📁 bible (Collection)
│   ├── 📄 malachi (Document)
│   │   ├── id: "malachi"
│   │   ├── nameKo: "말라기"
│   │   ├── nameEn: "Malachi"
│   │   ├── testament: "OT"
│   │   ├── chapterCount: 4
│   │   ├── totalVerses: 55
│   │   ├── order: 39
│   │   ├── audioBaseUrl: "gs://bible-speak.../malachi/"
│   │   └── isFree: true
│   │   │
│   │   └── 📁 chapters (Sub-collection)
│   │       ├── 📄 1 (Document)
│   │       │   ├── chapter: 1
│   │       │   ├── verseCount: 14
│   │       │   ├── audioUrl: "gs://.../malachi_1.mp3"
│   │       │   │
│   │       │   └── 📁 verses (Sub-collection)
│   │       │       ├── 📄 1
│   │       │       │   ├── verse: 1
│   │       │       │   ├── textEn: "The oracle of the word..."
│   │       │       │   ├── textKo: "여호와께서 말라기를 통하여..."
│   │       │       │   ├── audioUrl: "gs://.../malachi_1_1.mp3"
│   │       │       │   ├── audioStart: 0.0  (초 단위)
│   │       │       │   ├── audioEnd: 5.2
│   │       │       │   └── keyWords: ["oracle", "burden", "Malachi"]
│   │       │       └── 📄 2...
│   │       └── 📄 2...
│   │
│   ├── 📄 ephesians
│   ├── 📄 hebrews
│   └── 📄 philippians
│
├── 📁 vocabulary (Collection)
│   └── 📄 malachi_1 (Document)
│       └── words: [
│           {
│             id: "malachi_oracle",
│             word: "oracle",
│             pronunciation: "/ˈɔːrəkl/",
│             partOfSpeech: "noun",
│             meanings: ["신탁", "예언"],
│             difficulty: 3,
│             memoryTip: "oral(입) + cle = 입으로 전하는 신탁"
│           }
│       ]
│
├── 📁 users (Collection) - 기존 유지
│   └── 📄 {uid}
│       ├── profile: {...}
│       ├── subscription: {...}
│       └── 📁 progress (Sub-collection)
│
└── 📁 audio_cache (Collection) - 오디오 메타데이터
    └── 📄 malachi_1_1
        ├── storageUrl: "gs://..."
        ├── durationMs: 5200
        ├── sizeBytes: 52000
        └── lastUpdated: timestamp
```

### 2.2 Book Document 상세

```javascript
// bible/malachi
{
  id: "malachi",
  nameKo: "말라기",
  nameEn: "Malachi",
  nameEsv: "Malachi",  // ESV API용
  testament: "OT",      // OT | NT
  chapterCount: 4,
  totalVerses: 55,
  order: 39,            // 성경 순서
  description: "구약의 마지막 선지서...",
  audioBaseUrl: "gs://bible-speak.appspot.com/audio/esv/malachi/",
  isFree: true,         // 무료 콘텐츠 여부
  isPremium: false,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### 2.3 Verse Document 상세

```javascript
// bible/malachi/chapters/1/verses/1
{
  verse: 1,
  textEn: "The oracle of the word of the LORD to Israel by Malachi.",
  textKo: "말라기를 통하여 이스라엘에게 임한 여호와의 말씀의 경고라",

  // 오디오 정보
  audioUrl: "gs://bible-speak.appspot.com/audio/esv/malachi/malachi_1_1.mp3",
  audioStart: 0.0,      // 챕터 통합 오디오 사용 시
  audioEnd: 5.2,
  audioDurationMs: 5200,

  // 학습 메타데이터
  keyWords: ["oracle", "burden", "LORD", "Malachi"],
  difficulty: 2,        // 1-5

  // 타임스탬프
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### 2.4 Vocabulary Document 상세

```javascript
// vocabulary/malachi_1
{
  bookId: "malachi",
  chapter: 1,
  words: [
    {
      id: "malachi_1_oracle",
      word: "oracle",
      pronunciation: "/ˈɔːrəkl/",
      partOfSpeech: "noun",
      meanings: ["신탁", "예언", "신의 말씀"],
      difficulty: 3,
      memoryTip: "oral(입으로 말하는) + cle = 입으로 전하는 신의 말씀",
      verses: [
        {
          book: "malachi",
          chapter: 1,
          verse: 1,
          excerpt: "The oracle of the word of the LORD",
          excerptKo: "여호와의 말씀의 경고"
        }
      ],
      audioUrl: "gs://.../words/oracle.mp3"  // 선택적
    },
    // ... 더 많은 단어
  ],
  updatedAt: timestamp
}
```

---

## 3. 하이브리드 오디오 아키텍처

### 3.1 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                    Audio Service Layer                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐    ┌──────────────────────────┐  │
│  │  BibleAudioService   │    │   TutorAudioService      │  │
│  │  (Primary)           │    │   (Secondary)            │  │
│  ├──────────────────────┤    ├──────────────────────────┤  │
│  │ Source: Firebase     │    │ Source: ElevenLabs       │  │
│  │         Storage      │    │                          │  │
│  │                      │    │ Purpose:                 │  │
│  │ Content:             │    │ - AI Tutor voice         │  │
│  │ - Pre-recorded ESV   │    │ - Encouraging feedback   │  │
│  │ - Native speaker     │    │ - Pronunciation tips     │  │
│  │ - Verse-level MP3s   │    │                          │  │
│  │                      │    │ Trigger:                 │  │
│  │ Benefits:            │    │ - After pronunciation    │  │
│  │ - Consistent quality │    │   evaluation             │  │
│  │ - No API cost/verse  │    │ - Personalized feedback  │  │
│  │ - Offline support    │    │                          │  │
│  └──────────────────────┘    └──────────────────────────┘  │
│           │                            │                    │
│           ▼                            ▼                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Local Cache Manager                      │  │
│  │  - 100MB limit, 30-day expiration                    │  │
│  │  - Priority: Bible audio > Tutor audio               │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Firebase Storage 구조

```
gs://bible-speak.appspot.com/
│
├── audio/
│   ├── esv/                          # 성경 오디오
│   │   ├── malachi/
│   │   │   ├── malachi_1_1.mp3       # 구절별 오디오
│   │   │   ├── malachi_1_2.mp3
│   │   │   ├── malachi_1_full.mp3    # 챕터 전체 (선택)
│   │   │   └── ...
│   │   ├── ephesians/
│   │   ├── hebrews/
│   │   └── philippians/
│   │
│   └── words/                        # 단어 발음 (선택)
│       ├── oracle.mp3
│       ├── burden.mp3
│       └── ...
│
├── tutor/                            # AI 튜터 캐시 (선택)
│   └── feedback/
│       └── {hash}.mp3
│
└── assets/                           # 앱 에셋
    ├── images/
    └── sounds/
```

### 3.3 BibleAudioService 인터페이스

```dart
abstract class BibleAudioService {
  /// 구절 오디오 재생
  Future<void> playVerse({
    required String bookId,
    required int chapter,
    required int verse,
    double playbackRate = 1.0,
  });

  /// 다음 구절 프리로딩
  Future<void> preloadNextVerse({
    required String bookId,
    required int chapter,
    required int verse,
  });

  /// 오디오 일시정지
  Future<void> pause();

  /// 오디오 재개
  Future<void> resume();

  /// 오디오 정지
  Future<void> stop();

  /// 재생 속도 변경
  Future<void> setPlaybackRate(double rate);

  /// 캐시 상태 확인
  Future<bool> isCached(String bookId, int chapter, int verse);

  /// 챕터 전체 프리로딩
  Future<void> preloadChapter(String bookId, int chapter);
}
```

### 3.4 TutorAudioService 인터페이스

```dart
abstract class TutorAudioService {
  /// AI 튜터 피드백 음성 생성 및 재생
  Future<void> speakFeedback(String feedbackText);

  /// 단어 발음 재생
  Future<void> speakWord(String word);

  /// 발음 팁 재생
  Future<void> speakTip(String tipText);
}
```

---

## 4. TutorCoordinator 클래스 설계

### 4.1 플로우 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                    TutorCoordinator                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Input: PronunciationResult (Azure JSON)                    │
│  ├── overallScore: 72                                       │
│  ├── accuracyScore: 68                                      │
│  ├── fluencyScore: 75                                       │
│  ├── words: [{word: "oracle", score: 45, error: "Mispron"}] │
│  └── phonemes: [{phoneme: "θ", score: 30}]                  │
│                                                              │
│                         │                                    │
│                         ▼                                    │
│  ┌────────────────────────────────────────────────────┐     │
│  │              Analysis Module                        │     │
│  │  - 가장 약한 단어 식별                              │     │
│  │  - 문제 음소 추출                                   │     │
│  │  - 개선 포인트 우선순위                             │     │
│  └────────────────────────────────────────────────────┘     │
│                         │                                    │
│                         ▼                                    │
│  ┌────────────────────────────────────────────────────┐     │
│  │              Gemini 1.5 Flash                       │     │
│  │                                                     │     │
│  │  System Prompt:                                     │     │
│  │  "You are a warm, encouraging Korean English tutor │     │
│  │   helping a student memorize Bible verses.          │     │
│  │   - Always be positive and supportive              │     │
│  │   - Give ONE specific, actionable tip              │     │
│  │   - Use casual Korean (반말 or 존댓말)             │     │
│  │   - Max 50 characters                              │     │
│  │   - Include one emoji"                             │     │
│  │                                                     │     │
│  │  User Prompt:                                       │     │
│  │  "Student's result:                                 │     │
│  │   - Overall: 72%                                    │     │
│  │   - Weakest word: 'oracle' (45%)                   │     │
│  │   - Problem phoneme: 'ɔː' (30%)                    │     │
│  │   Generate encouraging feedback."                   │     │
│  │                                                     │     │
│  │  Response Example:                                  │     │
│  │  "잘했어요! 'oracle'은 '오러클'이 아니라           │     │
│  │   '어러클'로 발음해보세요 😊"                       │     │
│  └────────────────────────────────────────────────────┘     │
│                         │                                    │
│                         ▼                                    │
│  Output: TutorFeedback                                      │
│  ├── message: "잘했어요! 'oracle'은..."                     │
│  ├── audioUrl: (ElevenLabs generated, optional)             │
│  ├── focusWord: "oracle"                                    │
│  ├── focusPhoneme: "ɔː"                                     │
│  └── encouragementLevel: "positive"                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 TutorCoordinator 클래스

```dart
class TutorCoordinator {
  final GeminiFeedbackService _geminiService;
  final TutorAudioService _tutorAudioService;

  /// 발음 결과 분석 및 피드백 생성
  Future<TutorFeedback> generateFeedback(PronunciationResult result) async {
    // 1. 분석
    final analysis = _analyzeResult(result);

    // 2. Gemini로 피드백 생성
    final message = await _geminiService.generateEncouragement(
      overallScore: result.overallScore,
      weakestWord: analysis.weakestWord,
      problemPhoneme: analysis.problemPhoneme,
    );

    // 3. 피드백 객체 반환
    return TutorFeedback(
      message: message,
      focusWord: analysis.weakestWord,
      focusPhoneme: analysis.problemPhoneme,
      encouragementLevel: _getEncouragementLevel(result.overallScore),
    );
  }

  /// 피드백 음성 재생 (선택적)
  Future<void> speakFeedback(TutorFeedback feedback) async {
    await _tutorAudioService.speakFeedback(feedback.message);
  }
}
```

### 4.3 TutorFeedback 모델

```dart
class TutorFeedback {
  final String message;           // 격려 메시지
  final String? focusWord;        // 집중해야 할 단어
  final String? focusPhoneme;     // 문제 음소
  final String? audioUrl;         // 음성 URL (선택)
  final EncouragementLevel level; // 격려 수준
  final DateTime createdAt;

  // 팩토리 메서드
  factory TutorFeedback.forScore(int score, String message) {...}
}

enum EncouragementLevel {
  celebrate,  // 90+ "완벽해요!"
  positive,   // 70-89 "잘했어요!"
  encourage,  // 50-69 "조금만 더!"
  support,    // <50 "괜찮아요, 다시 해봐요!"
}
```

### 4.4 Speak 스타일 팝업 UI

```
┌─────────────────────────────────────────┐
│                                         │
│  ╭─────────────────────────────────╮   │
│  │                                 │   │
│  │         🎓                      │   │
│  │                                 │   │
│  │    AI 튜터가 말해요             │   │
│  │                                 │   │
│  │  "잘했어요! 'oracle'은          │   │
│  │   '오러클'이 아니라             │   │
│  │   '어러클'로 발음해보세요 😊"   │   │
│  │                                 │   │
│  │  ┌─────────┐  ┌─────────┐      │   │
│  │  │🔊 듣기  │  │  확인   │      │   │
│  │  └─────────┘  └─────────┘      │   │
│  │                                 │   │
│  ╰─────────────────────────────────╯   │
│                                         │
└─────────────────────────────────────────┘
```

---

## 5. 제안 디렉토리 구조

### 5.1 전체 구조

```
lib/
│
├── core/                              # 공통 유틸리티
│   ├── constants/
│   │   ├── app_constants.dart         # 앱 상수
│   │   ├── firestore_paths.dart       # Firestore 경로 상수
│   │   └── storage_paths.dart         # Storage 경로 상수
│   ├── errors/
│   │   ├── app_exception.dart         # 커스텀 예외
│   │   └── error_handler.dart         # 에러 핸들링
│   └── utils/
│       ├── audio_utils.dart           # 오디오 유틸
│       └── text_utils.dart            # 텍스트 유틸
│
├── data/                              # 🔄 데이터 레이어 (리팩토링)
│   ├── repositories/                  # Repository 구현
│   │   ├── bible_repository.dart      # 성경 데이터 접근
│   │   ├── bible_repository_impl.dart
│   │   ├── vocabulary_repository.dart # 단어 데이터 접근
│   │   ├── progress_repository.dart   # 진행 상태 접근
│   │   └── audio_repository.dart      # 오디오 파일 접근
│   ├── datasources/
│   │   ├── remote/
│   │   │   ├── firestore_datasource.dart
│   │   │   └── storage_datasource.dart
│   │   └── local/
│   │       ├── cache_datasource.dart
│   │       └── preferences_datasource.dart
│   └── mappers/
│       ├── bible_mapper.dart          # Firestore ↔ Model
│       ├── verse_mapper.dart
│       └── progress_mapper.dart
│
├── domain/                            # 도메인 레이어
│   ├── models/                        # 모델 클래스
│   │   ├── bible/
│   │   │   ├── book.dart
│   │   │   ├── chapter.dart
│   │   │   └── verse.dart
│   │   ├── learning/
│   │   │   ├── learning_stage.dart
│   │   │   ├── verse_progress.dart
│   │   │   └── word_progress.dart
│   │   ├── user/
│   │   │   ├── user_model.dart
│   │   │   └── subscription.dart
│   │   ├── pronunciation/
│   │   │   ├── pronunciation_result.dart
│   │   │   └── phoneme_result.dart
│   │   └── feedback/
│   │       └── tutor_feedback.dart    # NEW
│   └── usecases/                      # 비즈니스 로직
│       ├── bible/
│       │   ├── get_books_usecase.dart
│       │   ├── get_chapters_usecase.dart
│       │   └── get_verse_usecase.dart
│       ├── learning/
│       │   ├── evaluate_pronunciation_usecase.dart
│       │   ├── save_progress_usecase.dart
│       │   └── get_progress_usecase.dart
│       └── feedback/
│           └── generate_feedback_usecase.dart
│
├── services/                          # 🔄 서비스 레이어 (리팩토링)
│   ├── audio/
│   │   ├── bible_audio_service.dart   # NEW: Firebase Storage 기반
│   │   ├── tutor_audio_service.dart   # NEW: ElevenLabs 피드백용
│   │   └── audio_cache_manager.dart   # NEW: 통합 캐시 관리
│   ├── pronunciation/
│   │   ├── azure_pronunciation_service.dart  # 기존 유지
│   │   └── pronunciation_analyzer.dart       # NEW: 분석 로직
│   ├── feedback/
│   │   ├── tutor_coordinator.dart     # NEW: 핵심 클래스
│   │   └── gemini_feedback_service.dart
│   ├── recording_service.dart         # 기존 유지
│   ├── auth_service.dart              # 기존 유지
│   ├── progress_service.dart          # Repository 사용
│   └── iap_service.dart               # 기존 유지
│
├── presentation/                      # 프레젠테이션 레이어
│   ├── screens/
│   │   ├── splash/
│   │   │   └── splash_screen.dart
│   │   ├── auth/
│   │   │   └── profile_setup_screen.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart       # NEW: 로드맵 스타일
│   │   │   └── widgets/
│   │   │       ├── roadmap_widget.dart
│   │   │       ├── daily_goal_card.dart
│   │   │       └── streak_widget.dart
│   │   ├── study/
│   │   │   ├── book_selection_screen.dart
│   │   │   ├── chapter_roadmap_screen.dart
│   │   │   └── verse_practice_screen.dart
│   │   ├── word_study/
│   │   │   ├── word_study_home_screen.dart
│   │   │   ├── word_list_screen.dart
│   │   │   ├── word_detail_screen.dart
│   │   │   ├── flashcard_screen.dart
│   │   │   ├── quiz_screen.dart
│   │   │   └── quiz_result_screen.dart
│   │   ├── ranking/
│   │   │   └── ranking_screen.dart
│   │   ├── subscription/
│   │   │   └── subscription_screen.dart
│   │   └── profile/
│   │       └── profile_screen.dart
│   ├── widgets/
│   │   ├── common/
│   │   │   ├── loading_widget.dart
│   │   │   └── error_widget.dart
│   │   ├── feedback/
│   │   │   ├── tutor_popup.dart       # NEW: Speak 스타일
│   │   │   └── score_display.dart
│   │   ├── audio/
│   │   │   ├── audio_player_widget.dart
│   │   │   └── waveform_widget.dart
│   │   └── paywall/
│   │       └── paywall_dialog.dart
│   └── providers/                     # 상태 관리 (선택)
│       ├── bible_provider.dart
│       ├── learning_provider.dart
│       └── user_provider.dart
│
├── config/
│   ├── firebase_options.dart
│   ├── app_config.dart
│   └── theme/
│       ├── app_theme.dart
│       └── app_colors.dart
│
└── main.dart
```

### 5.2 주요 변경 사항

| 기존 | 변경 | 이유 |
|------|------|------|
| `lib/data/*.dart` (하드코딩) | `data/repositories/` | Firestore로 마이그레이션 |
| `lib/models/` | `domain/models/` | 도메인 분리 |
| `lib/services/tts_service.dart` | `services/audio/bible_audio_service.dart` | 역할 분리 |
| 없음 | `services/feedback/tutor_coordinator.dart` | AI 튜터 피드백 |
| `lib/screens/` | `presentation/screens/` | 프레젠테이션 레이어 분리 |

---

## 6. 마이그레이션 계획

### 6.1 우선순위 매트릭스

| 순서 | 작업 | 영향도 | 복잡도 | 예상 시간 |
|------|------|--------|--------|-----------|
| 1 | Firestore 스키마 생성 | 높음 | 중간 | 2-3시간 |
| 2 | 데이터 마이그레이션 스크립트 | 높음 | 중간 | 2-3시간 |
| 3 | BibleRepository 구현 | 높음 | 낮음 | 2시간 |
| 4 | Firebase Storage 오디오 업로드 | 높음 | 중간 | 3-4시간 |
| 5 | BibleAudioService 구현 | 높음 | 중간 | 3시간 |
| 6 | TutorCoordinator 구현 | 중간 | 중간 | 2-3시간 |
| 7 | TutorPopup UI 구현 | 낮음 | 낮음 | 1-2시간 |
| 8 | 로드맵 홈 화면 UI | 중간 | 중간 | 3-4시간 |

### 6.2 Phase 1: 데이터 마이그레이션 (1주)

```
Week 1:
├── Day 1-2: Firestore 스키마 설계 확정 & 컬렉션 생성
├── Day 3-4: 하드코딩 데이터 → Firestore 마이그레이션
├── Day 5: BibleRepository 구현
├── Day 6: VocabularyRepository 구현
└── Day 7: 기존 화면에서 Repository 사용하도록 수정
```

### 6.3 Phase 2: 오디오 리팩토링 (1주)

```
Week 2:
├── Day 1-2: ESV 오디오 파일 준비 & Firebase Storage 업로드
├── Day 3-4: BibleAudioService 구현
├── Day 5: AudioCacheManager 구현
├── Day 6: TutorAudioService 구현 (ElevenLabs)
└── Day 7: VersePracticeScreen에 통합
```

### 6.4 Phase 3: AI 튜터 피드백 (3-4일)

```
Week 3 (Part 1):
├── Day 1: TutorCoordinator 구현
├── Day 2: GeminiFeedbackService 개선
├── Day 3: TutorPopup UI 구현
└── Day 4: VersePracticeScreen에 통합
```

### 6.5 Phase 4: 홈 화면 리팩토링 (3-4일)

```
Week 3 (Part 2):
├── Day 5: 로드맵 위젯 디자인
├── Day 6: HomeScreen 구현
└── Day 7: 네비게이션 수정 & 테스트
```

---

## 7. 확인 필요 사항

### 7.1 기술적 결정

1. **Firestore 스키마**
   - 제안된 구조가 적합한가요?
   - 추가로 필요한 필드가 있나요?

2. **오디오 소스**
   - ESV MP3를 직접 녹음/구매할 예정인가요?
   - ESV API를 계속 사용하면서 캐싱할 예정인가요?
   - Firebase Storage 비용 고려 필요

3. **디렉토리 구조**
   - Clean Architecture 스타일 vs 현재 구조 유지?
   - Provider vs Riverpod vs Bloc?

### 7.2 비즈니스 결정

4. **TutorCoordinator 음성**
   - ElevenLabs 음성 출력이 필요한가요?
   - 텍스트만으로 충분한가요?
   - API 비용 고려

5. **무료 콘텐츠 범위**
   - 현재: 말라기 1장
   - 변경 계획 있나요?

6. **오프라인 지원**
   - 프리미엄 기능으로 제한?
   - 무료 사용자도 일부 지원?

### 7.3 다음 단계

구조 확정 후:
1. Firestore 스키마 생성 스크립트 작성
2. 데이터 마이그레이션 실행
3. Repository 패턴 구현
4. 서비스 리팩토링

---

## 부록: 기존 코드 참조

### A. 현재 지원 성경 (bible_data.dart)

```dart
static final List<BibleBook> supportedBooks = [
  BibleBook(id: 'malachi', nameKo: '말라기', nameEn: 'Malachi', chapters: 4, testament: 'OT'),
  BibleBook(id: 'philippians', nameKo: '빌립보서', nameEn: 'Philippians', chapters: 4, testament: 'NT'),
  BibleBook(id: 'hebrews', nameKo: '히브리서', nameEn: 'Hebrews', chapters: 13, testament: 'NT'),
  BibleBook(id: 'ephesians', nameKo: '에베소서', nameEn: 'Ephesians', chapters: 6, testament: 'NT'),
];
```

### B. 현재 학습 단계 (learning_stage.dart)

```dart
enum LearningStage {
  listenRepeat(1, '듣고 따라하기', 'Listen & Repeat', 70.0),
  keyExpressions(2, '핵심 표현', 'Key Expressions', 80.0),
  realSpeak(3, '실전 암송', 'Real Speak', 85.0);
}
```

### C. 현재 발음 평가 메트릭

- Accuracy Score (정확도)
- Fluency Score (유창성)
- Completeness Score (완성도)
- Prosody Score (운율)
- Phoneme-level feedback (음소별 피드백)

---

**문서 작성**: Claude Code (AI Assistant)
**버전**: 1.0
**최종 수정**: 2025년 1월 26일
