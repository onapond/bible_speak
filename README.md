# 🎤 말라기 암송 앱 - 마일스톤 2 설치 가이드

## 📋 개요

ElevenLabs TTS + STT를 활용한 성경 암송 앱

### ✅ 마일스톤 1 (완료)
- ElevenLabs TTS로 구절 듣기
- 오디오 캐싱 (비용 절감)

### ✅ 마일스톤 2 (현재)
- 마이크 녹음
- ElevenLabs STT로 음성 → 텍스트 변환
- 정확도 평가 및 피드백

---

## 📦 패키지 설치

```bash
cd C:\dev\bible_speak
flutter pub get
```

---

## ⚙️ 플랫폼별 설정

### 🤖 Android 설정

**파일**: `android/app/src/main/AndroidManifest.xml`

`<manifest>` 태그 안에 권한 추가:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### 🍎 iOS 설정

**파일**: `ios/Runner/Info.plist`

`<dict>` 태그 안에 추가:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>암송 연습을 위해 음성을 녹음합니다.</string>
```

---

## 🔑 API 키 설정

ElevenLabs API 키가 이미 코드에 입력되어 있습니다.

**확인 위치**:
- `lib/elevenlabs_tts_service.dart` - 5번째 줄
- `lib/elevenlabs_stt_service.dart` - 12번째 줄

**권한 확인**:
1. https://elevenlabs.io/app/api-keys 접속
2. 해당 API 키 클릭
3. "Text to Speech" → Access ✅
4. "Speech to Text" → Access ✅ (새로 확인!)

---

## 🚀 실행 방법

### 웹 테스트 (제한적)
```bash
flutter run -d web-server
```
⚠️ **주의**: 웹에서는 녹음 후 STT 변환이 제한됩니다!

### 📱 Android 테스트 (권장)
```bash
# USB로 폰 연결 후
flutter devices    # 연결 확인
flutter run        # 앱 설치 및 실행
```

### 🍎 iOS 테스트
```bash
# Mac + Xcode 필요
flutter run -d ios
```

---

## 💰 비용 정보

| 기능 | 무료 한도 | 월 비용 (초과 시) |
|------|----------|-----------------|
| TTS (듣기) | 10,000자/월 | $5/30,000자 |
| STT (녹음) | 2시간 30분/월 | $0.40/시간 |

### 💡 암송 앱 기준 예상 사용량
- 30초 녹음 × 300회 = 2.5시간 (무료 범위 내!)
- 말라기 1-2장 전체 TTS ≈ 2,000자

---

## 📂 파일 구조

```
bible_speak/
├── lib/
│   ├── main.dart                    # 메인 UI
│   ├── elevenlabs_tts_service.dart  # TTS 서비스 (마일스톤 1)
│   ├── elevenlabs_stt_service.dart  # STT 서비스 (마일스톤 2) ✨ NEW
│   ├── recording_service.dart       # 녹음 서비스 (마일스톤 2) ✨ NEW
│   └── accuracy_evaluator.dart      # 정확도 평가 (마일스톤 2) ✨ NEW
├── pubspec.yaml                     # 패키지 의존성
├── android_permissions_guide.xml    # Android 권한 가이드
└── ios_permissions_guide.plist      # iOS 권한 가이드
```

---

## 🔧 문제 해결

### ❌ "마이크 권한을 허용해주세요"
- Android: 설정 → 앱 → bible_speak → 권한 → 마이크 허용
- iOS: 설정 → bible_speak → 마이크 허용

### ❌ STT API 401 에러
1. ElevenLabs 대시보드 → API Keys
2. "Speech to Text" 권한이 활성화되어 있는지 확인
3. 권한이 없으면 새 API 키 생성

### ❌ STT API 429 에러 (한도 초과)
- 무료 한도: 2시간 30분/월
- 다음 달까지 대기 또는 유료 플랜 업그레이드

### ❌ 웹에서 STT가 작동하지 않음
- 웹 브라우저는 녹음 파일을 Blob URL로 처리하여 API 전송이 제한됨
- **해결**: Android/iOS 앱으로 테스트

---

## 📝 다음 단계 (마일스톤 3 예정)

- [ ] 말라기 전체 장 추가
- [ ] 단어 힌트 기능 (첫 글자 보여주기)
- [ ] 학습 진행률 저장
- [ ] 오프라인 모드 (캐싱 강화)

---

## 📞 도움이 필요하면?

새 채팅에서 이 프롬프트로 시작하세요:

```
# 말라기 암송 앱 - 마일스톤 2 지원

현재 상황: [에러 메시지 또는 문제 설명]

파일: [문제가 발생한 파일명]
```
