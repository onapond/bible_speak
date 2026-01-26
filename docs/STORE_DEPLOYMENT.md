# 바이블 스픽 - 스토어 배포 가이드

## 앱 정보

| 항목 | iOS | Android |
|------|-----|---------|
| 앱 이름 | 바이블스픽 | 바이블스픽 |
| 부제목 | AI 영어성경 암송 | AI 영어성경 암송 \| 발음 코칭 |
| Bundle ID | com.onapond.biblespeak | com.onapond.biblespeak |
| 버전 | 1.0.0 | 1.0.0 (versionCode: 1) |

---

## 1. 사전 준비

### 1.1 개발자 계정
- **Apple Developer Program**: $99/년 - https://developer.apple.com
- **Google Play Console**: $25 일회성 - https://play.google.com/console

### 1.2 앱 아이콘 준비 (필수)

#### iOS 앱 아이콘
`ios/Runner/Assets.xcassets/AppIcon.appiconset/` 에 저장

| 크기 | 파일명 | 용도 |
|------|--------|------|
| 1024x1024 | Icon-App-1024x1024@1x.png | App Store |
| 180x180 | Icon-App-60x60@3x.png | iPhone |
| 120x120 | Icon-App-60x60@2x.png | iPhone |
| 167x167 | Icon-App-83.5x83.5@2x.png | iPad Pro |
| 152x152 | Icon-App-76x76@2x.png | iPad |
| 80x80 | Icon-App-40x40@2x.png | Spotlight |

#### Android 앱 아이콘
`android/app/src/main/res/` 폴더에 저장

| 폴더 | 크기 | 파일명 |
|------|------|--------|
| mipmap-mdpi | 48x48 | ic_launcher.png |
| mipmap-hdpi | 72x72 | ic_launcher.png |
| mipmap-xhdpi | 96x96 | ic_launcher.png |
| mipmap-xxhdpi | 144x144 | ic_launcher.png |
| mipmap-xxxhdpi | 192x192 | ic_launcher.png |

> **Tip**: https://romannurik.github.io/AndroidAssetStudio/ 에서 자동 생성 가능

---

## 2. iOS 배포

### 2.1 Xcode 설정

```bash
# iOS 폴더로 이동
cd ios

# CocoaPods 설치/업데이트
pod install --repo-update

# Xcode에서 열기
open Runner.xcworkspace
```

**Xcode에서 설정할 항목:**
1. **Signing & Capabilities**
   - Team: 본인 개발자 팀 선택
   - Bundle Identifier: `com.onapond.biblespeak`
   - Automatically manage signing: ON

2. **Capabilities 추가**
   - In-App Purchase
   - Background Modes > Audio, AirPlay, and Picture in Picture

3. **Build Settings**
   - iOS Deployment Target: 14.0

### 2.2 앱 아카이브 생성

```bash
# 프로젝트 루트에서
flutter build ipa --release
```

또는 Xcode에서:
1. Product > Archive
2. Archives 창에서 Distribute App 선택
3. App Store Connect > Upload 선택

### 2.3 App Store Connect 설정

https://appstoreconnect.apple.com

#### 앱 정보
```
앱 이름: 바이블스픽
부제목: AI 영어성경 암송
카테고리: 교육 (기본) / 라이프스타일 (보조)
콘텐츠 등급: 4+
```

#### 인앱 구매 상품 등록
| 제품 ID | 유형 | 가격 |
|---------|------|------|
| bible_speak_premium_monthly | 자동 갱신 구독 | ₩4,900 |
| bible_speak_premium_yearly | 자동 갱신 구독 | ₩39,000 |

**구독 그룹**: "Bible Speak Premium"

#### 스크린샷 (필수)
- iPhone 6.7": 1290 x 2796 px (iPhone 15 Pro Max)
- iPhone 6.5": 1284 x 2778 px (iPhone 14 Plus)
- iPad Pro 12.9": 2048 x 2732 px

#### 앱 설명 (한국어)
```
하루 10분, AI 튜터와 영어 성경 한 구절!

바이블스픽은 AI 발음 코칭 기술로 영어 성경을 효과적으로 암송할 수 있도록 도와주는 앱입니다.

주요 기능:
- 3단계 쉐도잉 학습 (듣고 따라하기 → 핵심 표현 → 실전 암송)
- AI 발음 평가 (정확도, 유창성, 억양 분석)
- 음소(Phoneme) 단위 피드백으로 정확한 발음 교정
- 진행 상황 시각화 로드맵

지원 성경:
- ESV (English Standard Version) 오디오 지원
- 말라기, 에베소서, 히브리서 등

프리미엄 구독:
- 월간: ₩4,900
- 연간: ₩39,000 (33% 할인)

구독 조건:
- 구독료는 확인 후 iTunes 계정으로 청구됩니다
- 현재 기간 종료 24시간 전에 자동 갱신이 꺼지지 않으면 구독이 자동 갱신됩니다
- 구독은 구매 후 계정 설정에서 관리할 수 있습니다

개인정보처리방침: https://onapond.com/privacy
이용약관: https://onapond.com/terms
```

#### 키워드
```
영어성경,성경암송,영어암송,성경공부,영어발음,AI튜터,쉐도잉,Bible,ESV
```

---

## 3. Android 배포

### 3.1 키스토어 생성

```bash
# 키스토어 생성 (최초 1회)
keytool -genkey -v -keystore ~/bible_speak_upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias bible_speak

# key.properties 파일 생성 (android/ 폴더에)
```

`android/key.properties` 파일 생성:
```properties
storePassword=<키스토어 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=bible_speak
storeFile=<키스토어 파일 절대 경로>
```

> **주의**: key.properties와 .jks 파일은 절대 Git에 커밋하지 마세요!

### 3.2 릴리스 빌드

```bash
# AAB 파일 생성 (Play Store 업로드용)
flutter build appbundle --release

# 출력 위치: build/app/outputs/bundle/release/app-release.aab
```

### 3.3 Google Play Console 설정

https://play.google.com/console

#### 앱 정보
```
앱 이름: 바이블스픽
간단한 설명: AI 발음 코칭으로 영어 성경 암송
카테고리: 교육
콘텐츠 등급: 전체이용가
```

#### 인앱 상품 등록
수익 창출 > 제품 > 구독

| 제품 ID | 이름 | 가격 |
|---------|------|------|
| bible_speak_premium_monthly | 월간 프리미엄 | ₩4,900 |
| bible_speak_premium_yearly | 연간 프리미엄 | ₩39,000 |

#### 스크린샷 (필수)
- 휴대전화: 1080 x 1920 ~ 1440 x 2560 px
- 7인치 태블릿: 1024 x 600 px 이상
- 10인치 태블릿: 1280 x 800 px 이상

#### 상세 설명 (한국어)
```
하루 10분, AI 튜터와 영어 성경 한 구절!

바이블스픽은 AI 발음 코칭 기술을 활용하여 영어 성경을 효과적으로 암송할 수 있도록 도와주는 학습 앱입니다.

[주요 기능]
★ 3단계 쉐도잉 학습
   - 1단계: 듣고 따라하기 (전체 자막)
   - 2단계: 핵심 표현 (빈칸 채우기)
   - 3단계: 실전 암송 (자막 없이)

★ AI 발음 평가
   - Azure Speech 기반 정확한 발음 분석
   - 정확도, 유창성, 억양 점수 제공
   - 음소(Phoneme) 단위 세밀한 피드백

★ 시각적 학습 로드맵
   - 진행 상황 한눈에 파악
   - 성취감을 주는 단계별 언락 시스템

[지원 콘텐츠]
• ESV (English Standard Version) 성경
• 네이티브 오디오 지원
• 말라기, 에베소서, 히브리서 등

[구독 안내]
• 무료: 말라기 1장, 하루 3구절
• 프리미엄 월간: ₩4,900
• 프리미엄 연간: ₩39,000 (33% 할인)

[프리미엄 혜택]
• 전체 성경 콘텐츠 이용
• 무제한 학습
• 상세 발음 분석 (음소, 유창성, 운율)
• 광고 제거
• 오프라인 모드

문의: support@onapond.com
```

---

## 4. 필수 법적 문서

### 4.1 개인정보처리방침
웹페이지로 작성 필요: `https://onapond.com/privacy`

필수 포함 내용:
- 수집하는 개인정보 항목
- 개인정보 수집 목적
- 개인정보 보유 기간
- 제3자 제공 여부 (Firebase, Azure 등)
- 연락처

### 4.2 이용약관
웹페이지로 작성 필요: `https://onapond.com/terms`

필수 포함 내용:
- 서비스 이용 조건
- 구독 및 결제 조건
- 환불 정책
- 면책 조항

---

## 5. 배포 체크리스트

### iOS
- [ ] Apple Developer 계정 가입
- [ ] App Store Connect에 앱 등록
- [ ] 번들 ID 설정: com.onapond.biblespeak
- [ ] 앱 아이콘 1024x1024 업로드
- [ ] 스크린샷 업로드 (6.7", 6.5", iPad)
- [ ] 앱 설명, 키워드 입력
- [ ] 인앱 구매 상품 등록
- [ ] 개인정보처리방침 URL 입력
- [ ] 앱 심사 제출

### Android
- [ ] Google Play Developer 계정 가입
- [ ] Play Console에 앱 등록
- [ ] 키스토어 생성 및 보관
- [ ] key.properties 설정
- [ ] 앱 아이콘 업로드
- [ ] 스크린샷 업로드
- [ ] 상세 설명 입력
- [ ] 구독 상품 등록
- [ ] 개인정보처리방침 URL 입력
- [ ] 내부 테스트 → 비공개 테스트 → 프로덕션

---

## 6. 빌드 명령어 요약

```bash
# iOS 빌드
flutter build ipa --release

# Android 빌드
flutter build appbundle --release

# 버전 올리기 (pubspec.yaml)
# version: 1.0.1+2  (버전명+빌드번호)

# 분석 실행
flutter analyze

# 테스트 실행
flutter test
```

---

## 7. 심사 주의사항

### iOS 심사 자주 거절되는 이유
1. **메타데이터 문제**: 스크린샷이 실제 앱과 다름
2. **구독 설명 부족**: 가격, 갱신 조건 명시 필요
3. **개인정보처리방침 누락**: 접근 가능한 URL 필수
4. **로그인 필수 시**: 테스트 계정 제공 필요

### Android 심사 자주 거절되는 이유
1. **권한 설명 부족**: 마이크 권한 사용 이유 명시
2. **타겟 API 버전**: targetSdkVersion 최신 유지
3. **데이터 안전 섹션**: 수집 데이터 정확히 기재

---

## 문의

기술 지원: support@onapond.com
