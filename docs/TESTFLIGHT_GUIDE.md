# TestFlight 배포 가이드

> Windows에서 iOS 앱을 TestFlight에 배포하는 방법

## 사전 준비

### 1. Apple Developer 계정
- [Apple Developer Program](https://developer.apple.com/programs/) 가입 필요 ($99/년)
- Apple ID 2단계 인증 활성화

### 2. App Store Connect 앱 생성
1. [App Store Connect](https://appstoreconnect.apple.com) 접속
2. "My Apps" → "+" → "New App"
3. 정보 입력:
   - Platform: iOS
   - Name: **바이블스픽**
   - Primary Language: Korean
   - Bundle ID: `com.onapond.biblespeak`
   - SKU: `biblespeak-001`

### 3. 인증서 및 프로비저닝 프로파일
App Store Connect에서:
1. Certificates, Identifiers & Profiles 이동
2. **Certificates**: iOS Distribution 인증서 생성
3. **Identifiers**: App ID 등록 (`com.onapond.biblespeak`)
4. **Profiles**: App Store 배포용 프로파일 생성

---

## 방법 1: Codemagic (권장)

### Step 1: Codemagic 설정
1. [codemagic.io](https://codemagic.io) 가입 (GitHub/GitLab 연동)
2. "Add application" → 프로젝트 선택
3. "Flutter App" 선택

### Step 2: iOS 코드 서명 설정
Codemagic 대시보드에서:

```yaml
# codemagic.yaml
workflows:
  ios-release:
    name: iOS Release
    max_build_duration: 60
    instance_type: mac_mini_m1

    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.onapond.biblespeak
      vars:
        APP_STORE_CONNECT_ISSUER_ID: $APP_STORE_CONNECT_ISSUER_ID
        APP_STORE_CONNECT_KEY_IDENTIFIER: $APP_STORE_CONNECT_KEY_IDENTIFIER
        APP_STORE_CONNECT_PRIVATE_KEY: $APP_STORE_CONNECT_PRIVATE_KEY
      flutter: stable

    scripts:
      - name: Get Flutter packages
        script: flutter pub get

      - name: Build iOS
        script: |
          flutter build ipa --release \
            --build-name=1.0.0 \
            --build-number=$PROJECT_BUILD_NUMBER \
            --export-options-plist=/Users/builder/export_options.plist

    artifacts:
      - build/ios/ipa/*.ipa

    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
        beta_groups:
          - Internal Testers
```

### Step 3: App Store Connect API 키 생성
1. App Store Connect → Users and Access → Keys
2. "+" 클릭 → "App Manager" 역할 선택
3. 다운로드된 `.p8` 파일 저장
4. Codemagic에 등록:
   - Issuer ID
   - Key ID
   - Private Key (.p8 내용)

### Step 4: 빌드 실행
1. Codemagic 대시보드에서 "Start new build"
2. Branch 선택 (master)
3. Workflow 선택 (ios-release)
4. "Start build" 클릭

빌드 완료 시 자동으로 TestFlight에 업로드됩니다.

---

## 방법 2: GitHub Actions

### Step 1: 시크릿 설정
GitHub Repository → Settings → Secrets:

| Secret Name | 설명 |
|------------|------|
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | .p8 파일 Base64 인코딩 |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | 배포 인증서 |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | 인증서 비밀번호 |
| `IOS_PROVISIONING_PROFILE_BASE64` | 프로비저닝 프로파일 |

### Step 2: Workflow 파일 생성

```yaml
# .github/workflows/ios-release.yml
name: iOS Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: stable

      - name: Install dependencies
        run: flutter pub get

      - name: Install Apple Certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.IOS_DISTRIBUTION_CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.IOS_DISTRIBUTION_CERTIFICATE_PASSWORD }}
          PROFILE_BASE64: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
        run: |
          # 인증서 설치
          CERTIFICATE_PATH=$RUNNER_TEMP/certificate.p12
          echo -n "$CERTIFICATE_BASE64" | base64 --decode -o $CERTIFICATE_PATH

          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          security create-keychain -p "" $KEYCHAIN_PATH
          security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
          security unlock-keychain -p "" $KEYCHAIN_PATH
          security import $CERTIFICATE_PATH -P "$CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
          security list-keychain -d user -s $KEYCHAIN_PATH

          # 프로비저닝 프로파일 설치
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo -n "$PROFILE_BASE64" | base64 --decode -o ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

      - name: Build IPA
        run: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

      - name: Upload to TestFlight
        env:
          API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}
        run: |
          mkdir -p ~/.appstoreconnect/private_keys
          echo -n "$API_KEY_BASE64" | base64 --decode -o ~/.appstoreconnect/private_keys/AuthKey_$API_KEY_ID.p8

          xcrun altool --upload-app \
            --type ios \
            --file build/ios/ipa/*.ipa \
            --apiKey $API_KEY_ID \
            --apiIssuer $ISSUER_ID
```

---

## 방법 3: Mac에서 수동 빌드

Mac이 있다면 직접 빌드 가능:

```bash
# 1. Flutter 프로젝트로 이동
cd /path/to/bible_speak

# 2. 의존성 설치
flutter pub get

# 3. iOS 빌드 (Archive)
flutter build ipa --release

# 4. Xcode에서 업로드
# Xcode → Window → Organizer → Distribute App → App Store Connect
```

---

## TestFlight 테스터 초대

### 내부 테스터 (최대 100명)
1. App Store Connect → TestFlight → Internal Testing
2. "+" → 테스터 이메일 입력
3. 즉시 테스트 가능 (심사 불필요)

### 외부 테스터 (최대 10,000명)
1. App Store Connect → TestFlight → External Testing
2. 그룹 생성 → 테스터 초대
3. **Beta App Review 필요** (1-2일 소요)

---

## 체크리스트

### 빌드 전
- [ ] Bundle ID 확인: `com.onapond.biblespeak`
- [ ] 버전 번호 설정 (pubspec.yaml)
- [ ] 앱 아이콘 준비 완료
- [ ] Info.plist 권한 설명 작성

### App Store Connect
- [ ] 앱 생성 완료
- [ ] 앱 정보 입력 (설명, 스크린샷)
- [ ] 개인정보 처리방침 URL 설정
- [ ] 연령 등급 설정

### TestFlight
- [ ] 테스트 정보 입력
- [ ] 베타 테스터 그룹 생성
- [ ] 테스터 초대

---

## 버전 관리

```yaml
# pubspec.yaml
version: 1.0.0+1  # 버전명+빌드번호
```

- **버전명** (1.0.0): 사용자에게 표시
- **빌드번호** (+1): 매 업로드마다 증가 필수

TestFlight 재업로드 시:
```bash
flutter build ipa --build-number=2
```

---

## 문제 해결

### "Missing Compliance" 경고
앱이 암호화를 사용하는 경우 Export Compliance 설정 필요:

```xml
<!-- ios/Runner/Info.plist -->
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### 프로비저닝 프로파일 오류
1. Xcode → Preferences → Accounts → 팀 선택
2. "Download Manual Profiles" 클릭
3. 또는 Codemagic의 자동 서명 사용

---

## 참고 자료

- [Flutter iOS 배포 가이드](https://docs.flutter.dev/deployment/ios)
- [Codemagic Flutter 문서](https://docs.codemagic.io/flutter/flutter-projects/)
- [App Store Connect 도움말](https://developer.apple.com/help/app-store-connect/)
