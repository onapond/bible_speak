# 웹 배포 가이드

## 개요

Bible Speak 웹앱은 Firebase Hosting에 배포되고, 외부 유료 API는 인증된
Firebase Functions를 통해 호출합니다.

```text
Flutter Web ── Firebase ID token ──▶ Firebase Functions ──▶ ESV/Azure/Gemini/ElevenLabs
```

Cloudflare, Render, Vercel의 과거 익명 프록시는 폐기되었습니다. 해당 배포가
남아 있다면 저장소의 tombstone 버전으로 재배포하거나 프로젝트를 비활성화해야
합니다.

## 최초 서버 설정

API 키는 Flutter의 `.env` 또는 `--dart-define`에 넣지 않습니다. 노출된 과거
키를 각 공급자 콘솔에서 폐기한 뒤 새 값을 Functions Secret에 저장합니다.

```bash
firebase functions:secrets:set ESV_API_KEY
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set AZURE_SPEECH_KEY
firebase functions:secrets:set ELEVENLABS_API_KEY
firebase functions:secrets:set APPLE_APP_ID
firebase functions:secrets:set APPLE_IAP_KEY_ID
firebase functions:secrets:set APPLE_IAP_ISSUER_ID
firebase functions:secrets:set APPLE_IAP_PRIVATE_KEY
firebase deploy --only functions --project bible-speak
```

Azure 리전은 기본적으로 `koreacentral`, Gemini 모델은 기본적으로
`gemini-2.5-flash`를 사용합니다. 다른 값이 필요하면 서버 런타임 환경의
`AZURE_SPEECH_REGION`, `GEMINI_MODEL`을 설정합니다.

## 인앱 구독 서버 검증 설정

클라이언트는 결제 이벤트만으로 프리미엄을 활성화하지 않습니다.
`verifySubscriptionPurchase`가 Google Play Developer API 또는 App Store Server
API에서 상품 ID, 활성 상태, 만료일, 취소·환불 여부를 검증한 뒤 Firestore를
갱신합니다. 구매 원본 데이터는 Firestore에 저장하지 않고 해시된 소유권 키만
사용하며, 같은 구매를 다른 앱 계정에 연결할 수 없습니다.

### Google Play

1. Google Play Android Developer API를 프로젝트에서 활성화합니다.
2. 배포된 Functions의 런타임 서비스 계정을 Play Console 사용자로 추가합니다.
3. Bible Speak 앱의 주문·구독 조회에 필요한 권한을 부여합니다.
4. Play Console 구독 상품 ID를 아래 값과 정확히 일치시킵니다.
   - `bible_speak_premium_monthly`
   - `bible_speak_premium_yearly`

### App Store

1. App Store Connect의 앱 숫자 ID를 `APPLE_APP_ID`에 저장합니다.
2. Users and Access → Integrations → In-App Purchase에서 키를 생성합니다.
3. Key ID, Issuer ID, `.p8` 키 원문을 각각 `APPLE_IAP_KEY_ID`,
   `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_PRIVATE_KEY`에 저장합니다.
4. App Store Connect 구독 상품 ID를 Android와 동일한 두 값으로 설정합니다.

StoreKit 2 거래는 Apple 서명과 인증서 체인을 직접 검증합니다. iOS 13/14의
StoreKit 1 영수증은 영수증에서 거래 ID만 추출한 뒤, 인증된 App Store Server
API에서 최신 구독 거래를 다시 조회합니다. 저장소의 `functions/certs`에는 Apple
공식 PKI 루트 인증서만 포함되며 개인 키는 포함되지 않습니다.

### Firestore Rules

`firestore.rules`가 개발·운영의 공통 규칙 원본입니다. 공개 읽기·쓰기를 금지하고,
결제·사용량 경로는 Admin SDK만 접근하며 사용자 쓰기는 본인 문서로 제한합니다.
규칙은 개발 프로젝트에서 Emulator/실앱 회귀 검증 후 운영으로 승격합니다.

- `purchaseClaims/{claimId}`
- `internalApiUsage/{userId}/days/{date}`
- `users/{userId}/subscription/current`
- `users/{userId}`의 `isPremium`, `subscriptionExpiry`

## 웹 빌드와 배포

```bash
flutter pub get
./build_web.sh development
./scripts/deploy_environment.sh development web
```

Windows에서는 다음 스크립트를 사용합니다.

```powershell
.\build_web.ps1 -Environment development
```

운영 빌드·배포는 `master`에서만 가능합니다.

```bash
BIBLE_SPEAK_PROD_CONFIRM=bible-speak \
  ./scripts/deploy_environment.sh production web
```

배포 래퍼는 하네스의 웹 대상 전체 검증을 실행하고, 현재 브랜치에 맞는 웹 산출물과
메타데이터를 새로 만든 뒤 배포합니다. Android와 iOS는 각 대상의 릴리스 작업에서
별도로 전체 검증합니다.

기본 Functions 프로젝트와 다른 서버를 사용할 때만 공개 환경 변수
`API_BASE_URL`을 지정합니다. 공급자 비밀키는 어떤 클라이언트 빌드 명령에도
전달하지 않습니다.

## 인증 및 제한

- ESV 본문·오디오, Azure 발음 평가, Gemini 피드백, ElevenLabs TTS 요청은
  Firebase 로그인 ID 토큰이 필요합니다.
- Functions는 사용자별 KST 일일 호출 제한을 적용합니다.
- 클라이언트 요청 본문과 텍스트 길이, 오디오 크기를 서버에서 검증합니다.

## 배포 전 확인

1. 과거에 커밋된 모든 공급자 키가 폐기되었는지 확인합니다.
2. `cd functions && npm test`를 실행합니다.
3. `node --check functions/index.js`로 문법을 검사합니다.
4. 로그인 후 본문, 오디오, 녹음 평가, AI 피드백을 각각 확인합니다.
5. 로그아웃 상태에서 프록시 요청이 `401`을 반환하는지 확인합니다.
6. Play License Tester와 App Store Sandbox 계정으로 월간·연간 구매 및 복원을
   각각 확인하고, 만료·취소 영수증이 프리미엄을 활성화하지 않는지 확인합니다.
7. Firestore Rules에서 결제·사용량 서버 전용 경로의 클라이언트 쓰기가 거부되는지
   Rules Playground 또는 Emulator로 확인합니다.

## 관련 파일

- `lib/config/app_config.dart`: 공개 서버 URL만 보유
- `lib/services/api/authenticated_api_client.dart`: Firebase ID 토큰 첨부
- `functions/index.js`: 인증 프록시와 알림 함수
- `functions/purchase_verification.js`: Play/App Store 구독 서버 검증
- `build_web.sh`, `build_web.ps1`: 웹 빌드
- `firebase.json`: Hosting/Functions 설정
- `.firebaserc`: 명시적 `dev`/`prod` 프로젝트 별칭
- `firestore.rules`: 버전 관리되는 공통 보안 규칙
- `scripts/deploy_environment.sh`: 브랜치·빌드·프로젝트 배포 가드
