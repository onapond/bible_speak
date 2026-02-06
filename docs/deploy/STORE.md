# 바이블스픽 스토어 배포 가이드

> 통합 문서: 배포 가이드 + 스토어 리스팅 + 스크린샷

---

## 1. 앱 정보

| 항목 | iOS | Android |
|------|-----|---------|
| 앱 이름 | 바이블스픽 | 바이블스픽 |
| 부제목 | AI 영어성경 암송 | AI 영어성경 암송 |
| Bundle ID | com.onapond.biblespeak | com.onapond.biblespeak |
| 버전 | 1.0.0 | 1.0.0 (versionCode: 1) |
| 카테고리 | 교육 / 참고 | 교육 |
| 연령 등급 | 4+ | 전체이용가 |

---

## 2. 사전 준비

### 2.1 개발자 계정
- **Apple Developer Program**: $99/년 - https://developer.apple.com
- **Google Play Console**: $25 일회성 - https://play.google.com/console

### 2.2 앱 아이콘

**iOS** (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`)
| 크기 | 파일명 | 용도 |
|------|--------|------|
| 1024x1024 | Icon-App-1024x1024@1x.png | App Store |
| 180x180 | Icon-App-60x60@3x.png | iPhone |

**Android** (`android/app/src/main/res/`)
| 폴더 | 크기 |
|------|------|
| mipmap-xxxhdpi | 192x192 |
| mipmap-xxhdpi | 144x144 |
| mipmap-xhdpi | 96x96 |

> **Tip**: https://romannurik.github.io/AndroidAssetStudio/

---

## 3. 스토어 리스팅

### 3.1 앱 설명 (한국어)

**짧은 설명 (80자)**
```
AI 발음 코칭으로 영어 성경을 쉽고 재미있게 암송하세요. 하루 10분이면 충분합니다.
```

**전체 설명**
```
하루 10분, AI 튜터와 영어 성경 한 구절!

바이블스픽은 AI 발음 코칭 기술로 영어 성경을 효과적으로 암송할 수 있도록 도와주는 앱입니다.

주요 기능:
- 3단계 쉐도잉 학습 (듣고 따라하기 → 핵심 표현 → 실전 암송)
- AI 발음 평가 (정확도, 유창성, 억양 분석)
- 음소(Phoneme) 단위 피드백으로 정확한 발음 교정
- 스마트 복습 (Spaced Repetition)
- 그룹 챌린지 기능

지원 성경:
- ESV (English Standard Version) 오디오 지원

프리미엄 구독:
- 월간: ₩4,900
- 연간: ₩39,000 (33% 할인)

개인정보처리방침: https://onapond.com/privacy
이용약관: https://onapond.com/terms
```

### 3.2 키워드
```
성경암송,영어성경,발음교정,AI학습,바이블,암기,영어공부,성경읽기,QT,말씀암송
```

### 3.3 What's New (v1.0.0)
```
바이블스픽 첫 출시!

- AI 발음 코칭으로 영어 성경 암송
- 3단계 학습 시스템
- 스마트 복습 (Spaced Repetition)
- 업적 및 레벨 시스템
- 그룹 챌린지 기능
```

---

## 4. 스크린샷

### 4.1 필요 사이즈

**iOS App Store**
| 디바이스 | 해상도 | 필수 |
|----------|--------|------|
| iPhone 6.7" | 1290 x 2796 px | 필수 |
| iPhone 6.5" | 1284 x 2778 px | 필수 |
| iPad Pro 12.9" | 2048 x 2732 px | 권장 |

**Google Play**
| 디바이스 | 해상도 | 필수 |
|----------|--------|------|
| Phone | 1080 x 1920 px (최소) | 필수 |

### 4.2 촬영할 화면 (5-8장)

| # | 화면 | 헤드라인 |
|---|------|----------|
| 1 | 온보딩 | 하루 10분, AI와 성경 암송 |
| 2 | 메인 메뉴 | 매일 꾸준히, 성장하는 나 |
| 3 | 암송 연습 | 듣고, 따라하고, 외우기 |
| 4 | AI 피드백 | AI가 발음을 코칭해요 |
| 5 | 학습 통계 | 나의 성장 기록 |
| 6 | 복습 | 잊기 전에 복습 알림 |
| 7 | 업적 | 성취감을 느껴보세요 |
| 8 | 그룹 | 함께하면 더 재미있어요 |

### 4.3 촬영 방법

```bash
# Android 에뮬레이터
adb exec-out screencap -p > screenshot_1.png

# iOS 시뮬레이터
# Cmd + S (시뮬레이터에서)
```

---

## 5. 인앱 구매

| 제품 ID | 유형 | 가격 |
|---------|------|------|
| bible_speak_premium_monthly | 자동 갱신 구독 | ₩4,900 |
| bible_speak_premium_yearly | 자동 갱신 구독 | ₩39,000 |

**구독 그룹**: "Bible Speak Premium"

---

## 6. iOS 배포

### 6.1 빌드
```bash
flutter build ipa --release
```

### 6.2 Xcode 설정
1. **Signing & Capabilities**
   - Team: 본인 개발자 팀 선택
   - Bundle Identifier: `com.onapond.biblespeak`
   - Automatically manage signing: ON

2. **Capabilities 추가**
   - In-App Purchase
   - Background Modes > Audio

### 6.3 App Store Connect
https://appstoreconnect.apple.com

---

## 7. Android 배포

### 7.1 키스토어 생성
```bash
keytool -genkey -v -keystore ~/bible_speak_upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias bible_speak
```

### 7.2 key.properties
```properties
storePassword=<비밀번호>
keyPassword=<비밀번호>
keyAlias=bible_speak
storeFile=<키스토어 절대 경로>
```

> **주의**: key.properties와 .jks 파일은 Git에 커밋하지 마세요!

### 7.3 빌드
```bash
flutter build appbundle --release
# 출력: build/app/outputs/bundle/release/app-release.aab
```

### 7.4 Google Play Console
https://play.google.com/console

---

## 8. 법적 문서

| 문서 | URL |
|------|-----|
| 개인정보처리방침 | https://onapond.com/privacy |
| 이용약관 | https://onapond.com/terms |

---

## 9. 심사 주의사항

### iOS
- 스크린샷이 실제 앱과 일치해야 함
- 구독 가격/갱신 조건 명시 필요
- 로그인 필수 시 테스트 계정 제공

### Android
- 마이크 권한 사용 이유 명시
- targetSdkVersion 최신 유지
- 데이터 안전 섹션 정확히 기재

---

## 10. 빌드 명령어 요약

```bash
# iOS
flutter build ipa --release

# Android
flutter build appbundle --release

# 버전 올리기 (pubspec.yaml)
# version: 1.0.1+2

# 분석
flutter analyze
```
