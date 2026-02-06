# 웹 배포 가이드

## 개요

Bible Speak 앱은 Flutter Web을 지원하며, Firebase Hosting을 통해 배포됩니다.

**배포 URL:** https://bible-speak.web.app

## 아키텍처

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   Flutter Web App   │────▶│  Cloudflare Worker   │────▶│    ESV API      │
│ (Firebase Hosting)  │     │   (Audio Proxy)      │     │  (Audio Data)   │
└─────────────────────┘     └──────────────────────┘     └─────────────────┘
```

### 왜 프록시가 필요한가?

ESV API는 브라우저에서 직접 호출 시 CORS(Cross-Origin Resource Sharing) 정책으로 인해 차단됩니다.
Cloudflare Worker가 프록시 역할을 하여 CORS 헤더를 추가합니다.

## 구성 요소

### 1. Flutter Web App
- **위치:** Firebase Hosting
- **URL:** https://bible-speak.web.app
- **빌드:** `flutter build web --release`
- **배포:** `firebase deploy --only hosting`

### 2. Cloudflare Worker (Audio Proxy)
- **위치:** Cloudflare Workers
- **URL:** https://bible-speak-proxy.tlsdygksdev.workers.dev
- **역할:** ESV Audio API CORS 프록시

## 배포 방법

### Flutter Web 배포

**보안 빌드 (권장)**: API 키를 `--dart-define`으로 주입

```bash
# Windows (PowerShell)
.\build_web.ps1

# Mac/Linux
./build_web.sh

# Firebase 배포
firebase deploy --only hosting --project bible-speak
```

빌드 스크립트가 `.env` 파일에서 API 키를 읽어 빌드 시 주입합니다.

### Cloudflare Worker 배포

1. https://dash.cloudflare.com 접속
2. Workers & Pages > bible-speak-proxy 선택
3. Quick Edit 클릭
4. `cloudflare-worker/worker.js` 코드 붙여넣기
5. Save and Deploy 클릭

## 환경 설정

### AppConfig (lib/config/app_config.dart)

`--dart-define`을 통해 빌드 시점에 API 키가 주입됩니다:

```dart
class AppConfig {
  // 빌드 시점에 --dart-define으로 주입
  static const String _envEsvApiKey = String.fromEnvironment('ESV_API_KEY');
  static const String _envAzureSpeechKey = String.fromEnvironment('AZURE_SPEECH_KEY');
  // ...

  // 웹: --dart-define 값 사용
  // 모바일: flutter_dotenv로 .env 파일 로드
  static String get esvApiKey => kIsWeb ? _envEsvApiKey : dotenv.env['ESV_API_KEY'] ?? '';
}
```

### API 키 관리

| API | 웹 | 모바일 |
|-----|-----|--------|
| ESV API | `--dart-define` (빌드 시) | `.env` 파일 (런타임) |
| Azure Speech | `--dart-define` (빌드 시) | `.env` 파일 (런타임) |
| Gemini | `--dart-define` (빌드 시) | `.env` 파일 (런타임) |
| ElevenLabs | `--dart-define` (빌드 시) | `.env` 파일 (런타임) |

### 빌드 스크립트

| 파일 | 플랫폼 | 설명 |
|------|--------|------|
| `build_web.ps1` | Windows | `.env` 읽어서 `--dart-define` 주입 |
| `build_web.sh` | Mac/Linux | `.env` 읽어서 `--dart-define` 주입 |

> ⚠️ **보안 주의:** API 키가 빌드된 JS 파일에 포함됩니다. 프로덕션 환경에서는 백엔드 프록시를 통해 API 키를 숨기는 것을 권장합니다.

## 웹 제한 사항

| 기능 | 웹 지원 | 비고 |
|------|---------|------|
| 성경 텍스트 로딩 | ✅ | Firestore 사용 |
| 오디오 재생 | ✅ | Cloudflare Worker 프록시 필요 |
| 녹음 | ✅ | Web Audio API 사용 |
| 발음 평가 | ✅ | Azure Speech API |
| 로컬 캐시 | ❌ | 웹에서 미지원 |

## 트러블슈팅

### CORS 오류
```
Access to fetch at '...' has been blocked by CORS policy
```
→ Cloudflare Worker가 올바르게 배포되었는지 확인

### .env 로드 실패
```
📌 ESV_API_KEY: null...
```
→ 웹에서는 정상. AppConfig가 하드코딩된 값을 사용함

### 오디오 재생 안 됨
1. Cloudflare Worker URL 확인
2. Worker 코드에 CORS 헤더 확인
3. 브라우저 콘솔에서 오류 확인

## 웹 녹음 기능

웹에서 녹음은 Web Audio API를 사용합니다:

| 항목 | 모바일 | 웹 |
|------|--------|-----|
| 오디오 포맷 | WAV (PCM 16-bit) | WebM (opus) |
| 샘플링 레이트 | 16kHz | 16kHz |
| 결과 형태 | 파일 경로 | Blob URL |

### 웹 녹음 흐름

1. `RecordingService.startRecording()` - opus/webm 포맷으로 녹음 시작
2. `RecordingService.stopRecording()` - Blob URL 반환
3. `AudioLoader.load(blobUrl)` - HTTP GET으로 바이트 데이터 추출
4. `AzurePronunciationService.evaluate()` - `audio/webm; codecs=opus` 헤더로 전송

## 관련 파일

| 파일 | 설명 |
|------|------|
| `lib/config/app_config.dart` | 웹/모바일 설정 분기 |
| `lib/services/recording_service.dart` | 웹/모바일 녹음 서비스 |
| `lib/services/pronunciation/audio_loader.dart` | 플랫폼별 오디오 로딩 |
| `cloudflare-worker/worker.js` | Cloudflare Worker 코드 |
| `build_web.ps1` | Windows 빌드 스크립트 |
| `build_web.sh` | Mac/Linux 빌드 스크립트 |
| `firebase.json` | Firebase Hosting 설정 |
| `.firebaserc` | Firebase 프로젝트 설정 |
