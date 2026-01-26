# 바이블 스픽 (Bible Speak) - 기획 명세서

## 프로젝트 개요
영어 성경 암송 학습 앱. 사용자가 영어 성경 구절을 듣고, 따라 말하고, 정확도를 평가받아 암송을 완성하는 앱.

## 주요 기능

### 1. 암송 연습 (메인 기능)
- **성경책/장 선택**: 말라기, 에베소서, 히브리서 등 지원
- **구절 학습 플로우**:
  1. 영어 원문 + 한글 번역 표시
  2. TTS로 원어민 발음 듣기 (속도 조절 0.5x~1.5x)
  3. 마이크로 암송 녹음
  4. STT로 텍스트 변환 → 정확도 평가
  5. AI 피드백 제공 (Gemini)
- **진척도 관리**: 구절별 최고 점수 저장, 85% 이상 시 "암기 완료"

### 2. 단어 공부
- **단어 목록**: 장별 핵심 단어 제공
- **플래시카드**: 영어 ↔ 한글 뜻 학습
- **퀴즈**: 영→한 4지선다 테스트
- **학습 상태**: 미학습 / 학습중 / 암기완료

### 3. 달란트 시스템
- 암송 70% 이상 달성 시 달란트 +1 획득
- 그룹별 달란트 랭킹 표시

### 4. 사용자/그룹 관리
- 닉네임 + 그룹 선택으로 간단 가입
- 그룹별 멤버 및 달란트 합산 조회

## 화면 구조 (Screen Flow)

```
SplashScreen
    ├── (미로그인) ProfileSetupScreen → MainMenuScreen
    └── (로그인됨) MainMenuScreen
                      ├── 암송 연습 → BookSelectionScreen → ChapterSelectionScreen → VersePracticeScreen
                      ├── 단어 공부 → WordStudyHomeScreen → WordListScreen → WordDetailScreen
                      │                                        ├── FlashcardScreen
                      │                                        └── QuizScreen → QuizResultScreen
                      ├── 랭킹 → RankingScreen
                      └── 설정 (BottomSheet)
```

## 지원 성경 (현재)
| 책 | 영문명 | 장 수 | 한글 번역 |
|----|--------|-------|-----------|
| 말라기 | Malachi | 4장 | O (1장) |
| 에베소서 | Ephesians | 6장 | O (1장) |
| 히브리서 | Hebrews | 13장 | O (1-2장) |

## 점수 체계
- **정확도**: 단어 일치율 기반 (대소문자/구두점 무시)
- **등급**: A+ (95%+), A (85%+), B+ (75%+), B (60%+), C (40%+), D

## 환경 변수 (.env)
```
ESV_API_KEY=xxx              # ESV 성경 API
ELEVENLABS_API_KEY=xxx       # TTS API
GEMINI_API_KEY=xxx           # AI 피드백
AZURE_SPEECH_KEY=xxx         # Azure 발음 평가 (필수)
AZURE_SPEECH_REGION=koreacentral  # Azure 리전
```

## Azure Speech 설정 방법
1. https://portal.azure.com 접속
2. "Speech" 리소스 생성 (무료 F0 티어: 월 5시간)
3. 키와 리전을 .env에 입력
