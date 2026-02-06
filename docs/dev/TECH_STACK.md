# 바이블 스픽 - 기술 스택 명세서

## 기술 스택

| 분류 | 기술 | 버전/비고 |
|------|------|-----------|
| Framework | Flutter | SDK >=3.0.0 |
| Language | Dart | - |
| Backend | Firebase | Firestore, Auth |
| TTS | ElevenLabs API | 원어민 음성 |
| 발음 평가 | Azure Speech SDK | 음소별 정확도, 유창성, 운율 |
| AI | Google Gemini | 피드백 생성 |
| 성경 API | ESV API | 영어 성경 텍스트 |
| 로컬 저장 | SharedPreferences | 점수/진척도 |
| 오디오 | audioplayers, flutter_sound | 재생/녹음 |

## 폴더 구조

```
lib/
├── main.dart                 # 앱 진입점
├── firebase_options.dart     # Firebase 설정
│
├── services/pronunciation/   # 발음 평가 (신규)
│   ├── azure_pronunciation_service.dart  # Azure Speech 연동
│   └── pronunciation_feedback_service.dart # 피드백 생성
│
├── data/                     # 정적 데이터
│   ├── bible_data.dart       # 성경책 메타데이터, 한글 매핑
│   ├── korean_verses.dart    # 말라기 한글 번역
│   ├── korean_ephesians.dart # 에베소서 한글 번역
│   ├── korean_hebrews_1.dart # 히브리서 1장 한글
│   ├── korean_hebrews_2.dart # 히브리서 2장 한글
│   └── words/
│       └── malachi_words.dart # 말라기 단어 데이터
│
├── models/                   # 데이터 모델
│   ├── user_model.dart       # UserModel (uid, name, groupId, talants)
│   ├── group_model.dart      # GroupModel (id, name, memberCount)
│   ├── bible_word.dart       # BibleWord (단어, 뜻, 품사, 예문)
│   └── word_progress.dart    # WordProgress, WordStatus enum
│
├── services/                 # 비즈니스 로직
│   ├── auth_service.dart     # 인증, 사용자 관리, 달란트
│   ├── group_service.dart    # 그룹 CRUD, 랭킹 조회
│   ├── esv_service.dart      # ESV API 호출 (성경 텍스트)
│   ├── tts_service.dart      # ElevenLabs TTS (캐싱 포함)
│   ├── stt_service.dart      # Google STT 호출
│   ├── recording_service.dart # 마이크 녹음 (flutter_sound)
│   ├── accuracy_service.dart # 정확도 평가 알고리즘
│   ├── gemini_service.dart   # Gemini AI 피드백
│   ├── progress_service.dart # 구절별 점수 저장 (SharedPrefs)
│   ├── word_service.dart     # 단어 데이터 제공
│   └── word_progress_service.dart # 단어 학습 진척도
│
└── screens/                  # UI 화면
    ├── splash_screen.dart    # 스플래시 (인증 체크)
    ├── auth/
    │   └── profile_setup_screen.dart # 프로필 설정
    ├── home/
    │   └── main_menu_screen.dart     # 메인 메뉴 (4개 카드)
    ├── study/
    │   ├── book_selection_screen.dart    # 성경책 선택
    │   └── chapter_selection_screen.dart # 장 선택
    ├── practice/
    │   └── verse_practice_screen.dart    # 암송 연습 (핵심 화면)
    ├── word_study/
    │   ├── word_study_home_screen.dart   # 단어 공부 홈
    │   ├── word_list_screen.dart         # 단어 목록
    │   ├── word_detail_screen.dart       # 단어 상세
    │   ├── flashcard_screen.dart         # 플래시카드
    │   ├── quiz_screen.dart              # 퀴즈
    │   └── quiz_result_screen.dart       # 퀴즈 결과
    └── ranking/
        └── ranking_screen.dart           # 그룹 랭킹
```

## 주요 서비스 설명

### AuthService (auth_service.dart)
- Firebase Auth 익명 로그인
- Firestore users 컬렉션 관리
- 달란트 추가/조회

### EsvService (esv_service.dart)
- ESV API로 장 전체 구절 로드
- `VerseText` 모델 반환 (verse, english, korean?)

### TTSService (tts_service.dart)
- ElevenLabs API로 음성 생성
- 로컬 캐싱 (path_provider)
- 재생 속도 조절

### AccuracyService (accuracy_service.dart)
- 원문 vs 음성인식 텍스트 비교
- 단어별 정확도 계산
- `EvaluationResult` 반환

### ProgressService (progress_service.dart)
- SharedPreferences로 구절별 최고 점수 저장
- 키 형식: `score_{book}_{chapter}_{verse}`

## Firebase 구조

```
Firestore
├── users/{oddsZE4gHq...}
│   ├── uid: string
│   ├── name: string
│   ├── groupId: string
│   └── talants: number
│
└── groups/{group1}
    ├── name: string
    └── memberCount: number
```

## API 키 관리
- `.env` 파일에 저장 (gitignore 처리됨)
- `flutter_dotenv`로 런타임 로드
- `dotenv.env['KEY_NAME']`으로 접근

## 빌드 명령어
```bash
flutter analyze          # 코드 분석
flutter build apk        # Android APK
flutter build ios        # iOS (Mac 필요)
flutter run              # 개발 실행
```
