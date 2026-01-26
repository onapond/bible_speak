# 바이블 스픽 2.0 - 기술 아키텍처 명세서

## 1. 시스템 개요

### 1.1 아키텍처 다이어그램

```
┌──────────────────────────────────────────────────────────────────┐
│                         Flutter Application                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                      Presentation Layer                      │ │
│  │   Screens (UI) ──── Widgets ──── State (Provider/Riverpod)  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                               │                                   │
│                               ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                       Business Layer                         │ │
│  │   AuthService │ ProgressService │ LearningService │ ...      │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                               │                                   │
│                               ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                         Data Layer                           │ │
│  │   Repositories ──── Models ──── DTOs                         │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                        External Services                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │ Firebase │ │  Azure   │ │ElevenLabs│ │  Gemini  │ │  ESV   │ │
│  │Auth+Store│ │ Speech   │ │   TTS    │ │    AI    │ │  API   │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 기술 스택 상세

| 분류 | 기술 | 버전 | 용도 |
|------|------|------|------|
| Framework | Flutter | 3.19+ | 크로스 플랫폼 앱 |
| Language | Dart | 3.3+ | 앱 로직 |
| State | Provider / Riverpod | 2.x | 상태 관리 |
| Backend | Firebase | - | 인증, 데이터베이스 |
| TTS | ElevenLabs API | v1 | 원어민 음성 합성 |
| STT/Pron | Azure Speech | REST API | 발음 평가 |
| AI | Google Gemini | 1.5 Flash | 피드백 생성 |
| Bible | ESV API | v3 | 영어 성경 텍스트 |
| Audio | just_audio + record | - | 오디오 재생/녹음 |
| Storage | Hive / SharedPrefs | - | 로컬 캐싱 |
| Analytics | Firebase Analytics | - | 사용자 분석 |
| Crash | Firebase Crashlytics | - | 오류 모니터링 |

---

## 2. 폴더 구조 (Clean Architecture)

```
lib/
├── main.dart                      # 앱 진입점
├── app.dart                       # MaterialApp 설정
├── firebase_options.dart          # Firebase 설정
│
├── core/                          # 공통 유틸리티
│   ├── constants/
│   │   ├── app_colors.dart        # 색상 정의
│   │   ├── app_text_styles.dart   # 텍스트 스타일
│   │   └── api_constants.dart     # API 엔드포인트
│   ├── errors/
│   │   ├── exceptions.dart        # 커스텀 예외
│   │   └── failures.dart          # 실패 타입
│   ├── utils/
│   │   ├── validators.dart        # 입력 검증
│   │   └── formatters.dart        # 포맷 유틸
│   └── extensions/
│       └── string_extensions.dart # String 확장
│
├── data/                          # 데이터 레이어
│   ├── models/                    # 데이터 모델
│   │   ├── user_model.dart
│   │   ├── verse_model.dart
│   │   ├── progress_model.dart
│   │   ├── pronunciation_result.dart
│   │   └── learning_stage.dart
│   ├── repositories/              # 저장소 구현
│   │   ├── auth_repository.dart
│   │   ├── verse_repository.dart
│   │   └── progress_repository.dart
│   ├── datasources/               # 데이터 소스
│   │   ├── remote/
│   │   │   ├── firebase_datasource.dart
│   │   │   ├── esv_datasource.dart
│   │   │   └── azure_datasource.dart
│   │   └── local/
│   │       ├── cache_datasource.dart
│   │       └── audio_cache.dart
│   └── static/                    # 정적 데이터
│       ├── bible_books.dart       # 성경책 메타
│       └── korean_translations/   # 한글 번역
│           ├── malachi.dart
│           ├── ephesians.dart
│           └── hebrews.dart
│
├── domain/                        # 비즈니스 로직
│   ├── entities/                  # 엔티티
│   │   ├── user.dart
│   │   ├── verse.dart
│   │   └── progress.dart
│   ├── usecases/                  # 유스케이스
│   │   ├── auth/
│   │   │   ├── sign_in.dart
│   │   │   └── sign_out.dart
│   │   ├── learning/
│   │   │   ├── get_verse.dart
│   │   │   ├── evaluate_pronunciation.dart
│   │   │   └── update_progress.dart
│   │   └── group/
│   │       ├── join_group.dart
│   │       └── get_ranking.dart
│   └── repositories/              # 저장소 인터페이스
│       ├── i_auth_repository.dart
│       └── i_progress_repository.dart
│
├── services/                      # 외부 서비스 연동
│   ├── auth_service.dart          # Firebase Auth
│   ├── tts_service.dart           # ElevenLabs TTS
│   ├── pronunciation/             # 발음 평가
│   │   ├── azure_pronunciation_service.dart
│   │   └── pronunciation_feedback_service.dart
│   ├── gemini_service.dart        # AI 피드백
│   ├── esv_service.dart           # ESV API
│   └── analytics_service.dart     # 분석
│
├── presentation/                  # UI 레이어
│   ├── providers/                 # 상태 관리
│   │   ├── auth_provider.dart
│   │   ├── learning_provider.dart
│   │   └── progress_provider.dart
│   ├── screens/                   # 화면
│   │   ├── splash/
│   │   ├── onboarding/
│   │   ├── home/
│   │   ├── study/
│   │   ├── practice/
│   │   ├── word_study/
│   │   ├── ranking/
│   │   └── settings/
│   └── widgets/                   # 공통 위젯
│       ├── common/
│       │   ├── app_button.dart
│       │   ├── app_card.dart
│       │   └── loading_overlay.dart
│       ├── roadmap/
│       │   ├── roadmap_node.dart
│       │   └── roadmap_path.dart
│       └── pronunciation/
│           ├── waveform_display.dart
│           └── score_gauge.dart
│
└── config/                        # 설정
    ├── routes.dart                # 라우팅
    ├── themes.dart                # 테마
    └── injection.dart             # 의존성 주입
```

---

## 3. 핵심 데이터 모델

### 3.1 User (사용자)

```dart
class UserModel {
  final String uid;
  final String name;
  final String? groupId;
  final int talants;
  final bool isPremium;
  final DateTime? subscriptionExpiry;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  // Firestore 변환
  factory UserModel.fromFirestore(DocumentSnapshot doc);
  Map<String, dynamic> toFirestore();
}
```

### 3.2 Verse (구절)

```dart
class VerseModel {
  final String bookId;      // 'malachi', 'ephesians', etc.
  final int chapter;
  final int verse;
  final String englishText;
  final String? koreanText;
  final List<String> keyWords;  // Stage 2 빈칸용
  final String? audioUrl;       // 캐시된 TTS URL

  String get reference => '$bookId $chapter:$verse';
}
```

### 3.3 Progress (진척도)

```dart
class ProgressModel {
  final String bookId;
  final int chapter;
  final int verse;
  final LearningStage currentStage;  // stage1, stage2, stage3
  final Map<LearningStage, StageProgress> stages;
  final bool isCompleted;
  final DateTime? completedAt;
}

class StageProgress {
  final int attempts;
  final double bestScore;
  final double lastScore;
  final DateTime? lastAttemptAt;
}

enum LearningStage {
  listenRepeat,    // Stage 1: 듣고 따라하기
  keyExpressions,  // Stage 2: 핵심 표현
  realSpeak,       // Stage 3: 실전 암송
}
```

### 3.4 PronunciationResult (발음 결과)

```dart
class PronunciationResult {
  final double accuracyScore;     // 0-100
  final double fluencyScore;      // 0-100
  final double prosodyScore;      // 0-100
  final double overallScore;      // 가중 평균
  final String recognizedText;
  final List<WordScore> words;
  final String grade;             // A+, A, B+, B, C, D

  bool get passedStage1 => overallScore >= 70;
  bool get passedStage2 => overallScore >= 80;
  bool get passedStage3 => overallScore >= 85;
}

class WordScore {
  final String word;
  final double accuracyScore;
  final List<PhonemeScore> phonemes;
  final bool needsPractice;  // < 70%
}

class PhonemeScore {
  final String phoneme;
  final double score;
  final String? koreanHint;  // e.g., "ㄹ 발음"
}
```

---

## 4. API 통합 상세

### 4.1 Azure Speech - 발음 평가

```dart
class AzurePronunciationService {
  final String subscriptionKey;
  final String region;

  Future<PronunciationResult> evaluatePronunciation({
    required String audioPath,
    required String referenceText,
  }) async {
    // 1. 오디오 파일을 WAV 16kHz로 변환
    final audioData = await _prepareAudio(audioPath);

    // 2. REST API 호출
    final response = await http.post(
      Uri.parse('https://$region.stt.speech.microsoft.com/'
          'speech/recognition/conversation/cognitiveservices/v1'
          '?language=en-US'),
      headers: {
        'Ocp-Apim-Subscription-Key': subscriptionKey,
        'Content-Type': 'audio/wav',
        'Pronunciation-Assessment': _buildAssessmentConfig(referenceText),
      },
      body: audioData,
    );

    // 3. 결과 파싱
    return PronunciationResult.fromAzureResponse(response.body);
  }

  String _buildAssessmentConfig(String referenceText) {
    final config = {
      'ReferenceText': referenceText,
      'GradingSystem': 'HundredMark',
      'Granularity': 'Phoneme',
      'EnableMiscue': true,
    };
    return base64Encode(utf8.encode(jsonEncode(config)));
  }
}
```

### 4.2 ElevenLabs TTS

```dart
class TTSService {
  static const String baseUrl = 'https://api.elevenlabs.io/v1';
  static const String voiceId = 'EXAVITQu4vr4xnSDxMaL'; // Rachel (American)

  final String apiKey;
  final AudioCacheService _cache;

  Future<String> getAudioUrl({
    required String text,
    double speed = 1.0,
  }) async {
    // 캐시 확인
    final cacheKey = _getCacheKey(text, speed);
    final cached = await _cache.get(cacheKey);
    if (cached != null) return cached;

    // API 호출
    final response = await http.post(
      Uri.parse('$baseUrl/text-to-speech/$voiceId/stream'),
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_monolingual_v1',
        'voice_settings': {
          'stability': 0.75,
          'similarity_boost': 0.75,
          'speed': speed,
        },
      }),
    );

    // 로컬 저장 및 캐싱
    final path = await _saveAudio(response.bodyBytes, cacheKey);
    await _cache.set(cacheKey, path);
    return path;
  }
}
```

### 4.3 Gemini AI 피드백

```dart
class GeminiService {
  static const String model = 'gemini-1.5-flash';

  Future<String> generateFeedback({
    required PronunciationResult result,
    required String verseText,
  }) async {
    final prompt = '''
당신은 영어 발음 코치입니다. 한국인 학습자가 영어 성경 구절을 암송했습니다.

구절: "$verseText"
인식된 텍스트: "${result.recognizedText}"
정확도: ${result.accuracyScore}%
유창성: ${result.fluencyScore}%
운율: ${result.prosodyScore}%

틀린 단어:
${result.words.where((w) => w.accuracyScore < 80).map((w) =>
  '- ${w.word}: ${w.accuracyScore}%').join('\n')}

한국어로 짧고 격려하는 피드백을 제공해주세요.
구체적인 발음 교정 팁 1-2개를 포함해주세요.
''';

    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/'
          'models/$model:generateContent'),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [{'parts': [{'text': prompt}]}],
        'generationConfig': {
          'maxOutputTokens': 200,
          'temperature': 0.7,
        },
      }),
    );

    return _extractText(response.body);
  }
}
```

---

## 5. Firestore 스키마

### 5.1 컬렉션 구조

```
firestore/
├── users/{uid}
│   ├── name: string
│   ├── groupId: string?
│   ├── talants: number
│   ├── isPremium: boolean
│   ├── subscriptionExpiry: timestamp?
│   ├── createdAt: timestamp
│   └── lastActiveAt: timestamp
│
├── users/{uid}/progress/{bookId}
│   └── chapters: map
│       └── {chapterNum}: map
│           └── verses: map
│               └── {verseNum}: map
│                   ├── currentStage: number (1-3)
│                   ├── stages: map
│                   │   └── {stageNum}: map
│                   │       ├── attempts: number
│                   │       ├── bestScore: number
│                   │       └── lastAttemptAt: timestamp
│                   ├── isCompleted: boolean
│                   └── completedAt: timestamp?
│
├── groups/{groupId}
│   ├── name: string
│   ├── code: string (6자리 초대 코드)
│   ├── createdBy: string (uid)
│   ├── memberCount: number
│   └── createdAt: timestamp
│
└── leaderboard/{period}_{groupId}  (예: weekly_group123)
    ├── period: string ('weekly' | 'monthly')
    ├── startDate: timestamp
    ├── endDate: timestamp
    └── rankings: array
        └── { uid, name, talants, rank }
```

### 5.2 Firestore 보안 규칙

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자 데이터: 본인만 읽기/쓰기
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // 진척도 서브컬렉션
      match /progress/{bookId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // 그룹: 멤버만 읽기, 생성자만 쓰기
    match /groups/{groupId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null
        && resource.data.createdBy == request.auth.uid;
    }

    // 리더보드: 인증 사용자 읽기
    match /leaderboard/{docId} {
      allow read: if request.auth != null;
      allow write: if false; // Cloud Functions로만 쓰기
    }
  }
}
```

---

## 6. 상태 관리 (Provider/Riverpod)

### 6.1 Provider 구조

```dart
// auth_provider.dart
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
}

// learning_provider.dart
final currentVerseProvider = StateProvider<VerseModel?>((ref) => null);

final pronunciationResultProvider = StateProvider<PronunciationResult?>((ref) => null);

final learningStageProvider = StateProvider<LearningStage>((ref) => LearningStage.listenRepeat);

// progress_provider.dart
final progressProvider = FutureProvider.family<ProgressModel?, String>((ref, verseKey) async {
  final service = ref.read(progressServiceProvider);
  return service.getProgress(verseKey);
});
```

### 6.2 의존성 주입

```dart
// injection.dart
final getIt = GetIt.instance;

void setupDependencies() {
  // 외부 서비스
  getIt.registerLazySingleton(() => FirebaseAuth.instance);
  getIt.registerLazySingleton(() => FirebaseFirestore.instance);

  // 데이터 소스
  getIt.registerLazySingleton(() => FirebaseDataSource(getIt()));
  getIt.registerLazySingleton(() => AzureDataSource());
  getIt.registerLazySingleton(() => AudioCacheService());

  // 저장소
  getIt.registerLazySingleton(() => AuthRepository(getIt()));
  getIt.registerLazySingleton(() => ProgressRepository(getIt()));

  // 서비스
  getIt.registerLazySingleton(() => AuthService(getIt()));
  getIt.registerLazySingleton(() => TTSService(getIt()));
  getIt.registerLazySingleton(() => AzurePronunciationService());
  getIt.registerLazySingleton(() => GeminiService());
}
```

---

## 7. 오디오 처리

### 7.1 녹음 설정

```dart
class RecordingService {
  late final Record _recorder;

  Future<void> init() async {
    _recorder = Record();
  }

  Future<void> start() async {
    if (await _recorder.hasPermission()) {
      await _recorder.start(
        encoder: AudioEncoder.wav,    // Azure 호환
        samplingRate: 16000,          // Azure 권장
        numChannels: 1,               // 모노
        bitRate: 256000,
      );
    }
  }

  Future<String?> stop() async {
    return await _recorder.stop();    // 파일 경로 반환
  }
}
```

### 7.2 오디오 재생 (스트리밍)

```dart
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playUrl(String url, {double speed = 1.0}) async {
    await _player.setUrl(url);
    await _player.setSpeed(speed);
    await _player.play();
  }

  Future<void> playLocal(String path, {double speed = 1.0}) async {
    await _player.setFilePath(path);
    await _player.setSpeed(speed);
    await _player.play();
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get stateStream => _player.playerStateStream;
}
```

### 7.3 오디오 캐싱

```dart
class AudioCacheService {
  static const String cacheDir = 'audio_cache';
  static const Duration maxAge = Duration(days: 30);

  Future<String?> get(String key) async {
    final file = await _getFile(key);
    if (await file.exists()) {
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) < maxAge) {
        return file.path;
      }
    }
    return null;
  }

  Future<void> set(String key, String sourcePath) async {
    final file = await _getFile(key);
    await File(sourcePath).copy(file.path);
  }

  Future<void> clearOld() async {
    final dir = await _getCacheDir();
    final files = await dir.list().toList();
    for (final file in files) {
      if (file is File) {
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified) > maxAge) {
          await file.delete();
        }
      }
    }
  }
}
```

---

## 8. 오프라인 지원

### 8.1 캐싱 전략

| 데이터 | 캐시 위치 | 만료 |
|--------|----------|------|
| 구절 텍스트 | Hive | 영구 (수동 업데이트) |
| TTS 오디오 | 파일 시스템 | 30일 |
| 진척도 | Hive + Firestore | 실시간 동기화 |
| 사용자 정보 | SharedPrefs | 로그인 시 갱신 |

### 8.2 동기화 로직

```dart
class SyncService {
  final FirebaseFirestore _firestore;
  final HiveBox _localBox;

  // 앱 시작 시 호출
  Future<void> syncOnStartup() async {
    if (await _hasNetwork()) {
      await _uploadPendingChanges();
      await _downloadRemoteChanges();
    }
  }

  // 오프라인 변경사항 저장
  Future<void> saveOfflineChange(String key, Map<String, dynamic> data) async {
    await _localBox.put(key, data);
    await _localBox.put('pending_$key', true);
  }

  // 연결 복구 시 업로드
  Future<void> _uploadPendingChanges() async {
    final pendingKeys = _localBox.keys.where((k) => k.startsWith('pending_'));
    for (final pendingKey in pendingKeys) {
      final key = pendingKey.replaceFirst('pending_', '');
      final data = _localBox.get(key);
      await _firestore.doc(key).set(data, SetOptions(merge: true));
      await _localBox.delete(pendingKey);
    }
  }
}
```

---

## 9. 성능 최적화

### 9.1 앱 시작 최적화

```dart
void main() async {
  // 1. 필수 초기화만 동기 실행
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());

  // 2. 나머지는 비동기로 백그라운드 실행
  _initializeInBackground();
}

Future<void> _initializeInBackground() async {
  await Future.wait([
    setupDependencies(),
    _preloadFonts(),
    _warmupCache(),
  ]);
}
```

### 9.2 이미지/에셋 최적화

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/images/1x/
    - assets/images/2x/
    - assets/images/3x/
```

### 9.3 메모리 관리

```dart
class VersePracticeScreen extends ConsumerStatefulWidget {
  @override
  void dispose() {
    // 오디오 플레이어 해제
    _audioPlayer.dispose();
    // 녹음기 해제
    _recorder.dispose();
    super.dispose();
  }
}
```

---

## 10. 테스트 전략

### 10.1 테스트 구조

```
test/
├── unit/
│   ├── services/
│   │   ├── pronunciation_service_test.dart
│   │   └── progress_service_test.dart
│   └── models/
│       └── pronunciation_result_test.dart
├── widget/
│   ├── screens/
│   │   └── verse_practice_screen_test.dart
│   └── widgets/
│       └── roadmap_node_test.dart
└── integration/
    └── learning_flow_test.dart
```

### 10.2 Mock 전략

```dart
// Azure 발음 서비스 Mock
class MockAzurePronunciationService extends Mock
    implements AzurePronunciationService {
  @override
  Future<PronunciationResult> evaluate(String audio, String text) async {
    return PronunciationResult(
      accuracyScore: 85.0,
      fluencyScore: 80.0,
      prosodyScore: 75.0,
      words: [],
    );
  }
}
```

---

## 11. CI/CD 파이프라인

### 11.1 GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test

  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: build/app/outputs/flutter-apk/app-release.apk

  build-ios:
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build ios --release --no-codesign
```

### 11.2 배포 체크리스트

- [ ] `flutter analyze` 통과
- [ ] 모든 테스트 통과
- [ ] 버전 번호 업데이트 (pubspec.yaml)
- [ ] 환경 변수 프로덕션 값 확인
- [ ] Android: 서명 키 적용
- [ ] iOS: 프로비저닝 프로파일 확인
- [ ] 스토어 메타데이터 업데이트
