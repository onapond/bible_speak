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

```bash
# 빌드
flutter build web --release

# Firebase 배포
firebase deploy --only hosting --project bible-speak
```

### Cloudflare Worker 배포

1. https://dash.cloudflare.com 접속
2. Workers & Pages > bible-speak-proxy 선택
3. Quick Edit 클릭
4. `cloudflare-worker/worker.js` 코드 붙여넣기
5. Save and Deploy 클릭

## 환경 설정

### AppConfig (lib/config/app_config.dart)

웹과 모바일에서 다른 설정을 사용합니다:

```dart
// 웹: 하드코딩된 값 사용 (dotenv가 웹에서 작동하지 않음)
// 모바일: .env 파일에서 로드
```

### API 키 관리

| API | 웹 | 모바일 |
|-----|-----|--------|
| ESV API | AppConfig에 하드코딩 | .env 파일 |
| Azure Speech | AppConfig에 하드코딩 | .env 파일 |
| Gemini | AppConfig에 하드코딩 | .env 파일 |
| ElevenLabs | AppConfig에 하드코딩 | .env 파일 |

> ⚠️ **보안 주의:** 프로덕션 환경에서는 백엔드 프록시를 통해 API 키를 숨겨야 합니다.

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

## 관련 파일

- `lib/config/app_config.dart` - 웹/모바일 설정 분기
- `cloudflare-worker/worker.js` - Cloudflare Worker 코드
- `firebase.json` - Firebase Hosting 설정
- `.firebaserc` - Firebase 프로젝트 설정
