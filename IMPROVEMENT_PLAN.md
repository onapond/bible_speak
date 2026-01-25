# 바이블 스픽 개선 계획서

## 현재 문제점 분석

### 1. AI 튜터 - 사실상 작동 안 함
**현재 상태:**
- `GeminiService`가 단순 피드백 생성기 역할만 함
- 틀린 단어 목록 + 점수 → 1-2문장 격려 메시지
- "튜터"가 아니라 "점수 코멘터"

**부족한 점:**
- 대화형 코칭 없음 (일회성 피드백)
- 개인화된 학습 경로 없음
- 발음 교정 가이드 없음 (어떻게 발음해야 하는지)
- 학습 이력 기반 추천 없음
- 틀린 패턴 분석 없음

### 2. 영어 음성 인식 - 정확도 낮음
**현재 상태:**
- ElevenLabs Scribe API 사용 (일반 STT)
- API 키 하드코딩 (보안 문제!)
- 단순 텍스트 변환만 수행

**부족한 점:**
- 발음 평가 전문 API가 아님
- 음소(phoneme) 단위 분석 불가
- 강세, 억양, 리듬 평가 불가
- 한국인 영어 발음 특화 아님
- STT 오류 = 모든 평가 오류

### 3. 정확도 평가 - 텍스트 비교만
**현재 상태:**
- `AccuracyService`가 Levenshtein 거리로 텍스트 비교
- STT 결과물에 전적으로 의존

**문제:**
- "correctly" 발음해도 STT가 "correctly"로 못 잡으면 틀림
- 실제 발음 품질과 무관한 점수

---

## 개선 방안

### Phase 1: 발음 평가 정확도 개선 (필수)

#### 옵션 A: Azure Speech SDK (추천)
```
장점:
- 발음 평가 전문 API (Pronunciation Assessment)
- 음소별 정확도, 강세, 유창성, 완전성 점수
- 실시간 피드백 가능
- 한국인 영어 학습에 최적화 가능

비용:
- 무료 티어: 월 5시간
- 유료: $1/오디오 시간
```

#### 옵션 B: SpeechAce API
```
장점:
- 발음 평가 특화 서비스
- 음소별 점수 + 교정 제안
- 영어 학습용으로 설계됨

비용:
- 유료 ($0.002~$0.01/요청)
```

#### 옵션 C: Google Cloud Speech + AI 후처리
```
현재 방식 개선:
- Google Cloud STT로 교체 (정확도 높음)
- 여러 번 인식 후 최고 결과 선택
- Gemini로 발음 힌트 생성
```

### Phase 2: AI 튜터 에이전트화

#### 현재 → 목표
```
현재: 점수 → "잘했어요!" (일회성)
목표: 대화형 코칭 에이전트
```

#### 구현 방향

**1. 학습 세션 관리**
```dart
class TutorSession {
  List<PracticeAttempt> attempts;  // 시도 이력
  List<String> weakWords;          // 취약 단어
  List<String> weakPhonemes;       // 취약 음소
  int sessionStreak;               // 연속 학습일
}
```

**2. 대화형 피드백**
```
[1차 시도] 70%
AI: "전체적으로 좋아요! 'righteousness'에서 'right-' 부분이
    'light'처럼 들렸어요. 입술을 더 둥글게 하고 'r' 발음을
    강하게 해보세요. 다시 해볼까요?"

[2차 시도] 85%
AI: "훨씬 좋아졌어요! 이번엔 완벽했어요.
    다음 구절로 넘어갈까요, 아니면 한 번 더 연습할까요?"
```

**3. 개인화된 학습 경로**
```
- 취약 음소 집중 연습
- 비슷한 발음 단어 묶어서 학습
- 난이도 자동 조절
- 복습 주기 알림
```

**4. 발음 가이드**
```
단어: "righteousness"
발음: /ˌraɪtʃəsnəs/
한글 힌트: "라이-쳐스-니스"
입모양: [이미지/애니메이션]
주의점: 한국인이 자주 틀리는 'r' vs 'l' 구분
```

### Phase 3: 기술 스택 개선

#### 추가 필요 패키지
```yaml
dependencies:
  # 발음 평가 (선택)
  azure_speech_sdk: ^x.x.x      # Azure 사용 시

  # 대화형 AI
  langchain: ^x.x.x             # 또는 직접 구현

  # 로컬 저장 강화
  hive: ^x.x.x                  # 학습 이력 저장

  # 오프라인 지원
  flutter_tts: ^x.x.x           # 기본 TTS (오프라인)
```

#### 새로운 서비스 구조
```
lib/services/
├── pronunciation/
│   ├── azure_pronunciation_service.dart  # Azure 발음 평가
│   ├── pronunciation_result.dart         # 결과 모델
│   └── phoneme_analyzer.dart             # 음소 분석
├── tutor/
│   ├── tutor_agent.dart                  # AI 튜터 에이전트
│   ├── tutor_session.dart                # 세션 관리
│   ├── learning_path.dart                # 학습 경로
│   └── feedback_generator.dart           # 피드백 생성
└── analytics/
    ├── learning_analytics.dart           # 학습 분석
    └── weak_point_detector.dart          # 취약점 감지
```

---

## 우선순위 로드맵

### 즉시 해결 (보안)
- [ ] STT API 키 하드코딩 제거 → `.env`로 이동

### 단기 (1-2주)
- [ ] Azure Speech SDK 또는 SpeechAce 통합
- [ ] 음소별 발음 점수 표시
- [ ] 발음 가이드 UI 추가

### 중기 (3-4주)
- [ ] AI 튜터 대화형 피드백
- [ ] 학습 이력 저장 및 분석
- [ ] 취약 음소/단어 집중 연습

### 장기 (1-2개월)
- [ ] 개인화된 학습 경로
- [ ] 발음 교정 애니메이션
- [ ] 오프라인 모드

---

## 비용 예상

| 서비스 | 무료 티어 | 유료 예상 |
|--------|-----------|-----------|
| Azure Speech | 월 5시간 | ~$30/월 (활성 사용자 100명) |
| Gemini | 월 60 요청/분 | ~$10/월 |
| ElevenLabs TTS | 월 10,000자 | ~$5/월 |
| Firebase | 무료 | 무료 (현재 규모) |

---

## 결론

현재 앱은 **"암송 점수 측정기"**이지 **"AI 튜터"**가 아닙니다.

진정한 AI 튜터가 되려면:
1. **발음 평가 전문 API** 도입 (Azure/SpeechAce)
2. **대화형 코칭** 구현 (Gemini 활용 강화)
3. **학습 분석 및 개인화** 추가

가장 임팩트 있는 첫 단계: **Azure Pronunciation Assessment API 통합**
