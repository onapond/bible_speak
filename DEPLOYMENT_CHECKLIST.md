# 바이블스픽 스토어 배포 체크리스트

## 현재 설정 상태

### 앱 정보
| 항목 | 값 |
|------|-----|
| 앱 이름 | 바이블스픽 |
| Android Package | com.onapond.biblespeak |
| iOS Bundle ID | com.onapond.biblespeak |
| 버전 | 1.0.0+1 |

---

## Android 배포

### 자동 설정됨 (완료)
- [x] Package Name: `com.onapond.biblespeak`
- [x] 앱 이름: `바이블스픽`
- [x] minSdk: 24 (Android 7.0+)
- [x] 권한 설정 (INTERNET, RECORD_AUDIO, BILLING, POST_NOTIFICATIONS)
- [x] ProGuard 최적화 활성화
- [x] FCM 알림 채널 설정

### 수동 작업 필요
- [ ] **키스토어 생성**
  ```bash
  keytool -genkey -v -keystore bible_speak_upload.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias bible_speak
  ```

- [ ] **key.properties 생성** (`android/key.properties`)
  ```properties
  storePassword=YOUR_PASSWORD
  keyPassword=YOUR_PASSWORD
  keyAlias=bible_speak
  storeFile=/absolute/path/to/bible_speak_upload.jks
  ```

- [ ] **앱 아이콘 교체** (현재 Flutter 기본 아이콘)
  - `android/app/src/main/res/mipmap-*/ic_launcher.png`
  - 권장: https://romannurik.github.io/AndroidAssetStudio/

- [ ] **스크린샷 준비** (5-8장)
  - 휴대전화: 1080x1920 ~ 1440x2560 px
  - 태블릿 (선택): 1280x800 px 이상

- [ ] **Google Play Console 설정**
  - 개발자 계정 등록 ($25)
  - 앱 등록 및 메타데이터 입력
  - 구독 상품 등록

### 빌드 명령어
```bash
# AAB 파일 생성 (Play Store용)
flutter build appbundle --release

# 출력: build/app/outputs/bundle/release/app-release.aab
```

---

## iOS 배포

### 자동 설정됨 (완료)
- [x] Bundle ID: `com.onapond.biblespeak`
- [x] 앱 이름: `바이블스픽`
- [x] 마이크/음성인식 권한 설명
- [x] 백그라운드 모드 (audio, remote-notification)

### 수동 작업 필요 (macOS 필요)
- [ ] **Apple Developer 계정** ($99/년)
- [ ] **Xcode에서 Signing 설정**
  - Team 선택
  - Automatically manage signing 활성화

- [ ] **앱 아이콘 교체**
  - `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
  - 1024x1024 필수 (App Store용)

- [ ] **스크린샷 준비**
  - iPhone 6.7": 1290x2796 px
  - iPhone 6.5": 1284x2778 px
  - iPad Pro 12.9": 2048x2732 px

- [ ] **App Store Connect 설정**
  - 앱 등록 및 메타데이터 입력
  - 인앱 구매 상품 등록
  - 앱 심사 제출

### 빌드 명령어 (macOS)
```bash
# IPA 파일 생성
flutter build ipa --release

# 또는 Xcode에서 Product > Archive
```

---

## 인앱 구매 상품

| 제품 ID | 유형 | 가격 |
|---------|------|------|
| bible_speak_premium_monthly | 구독 (월간) | ₩4,900 |
| bible_speak_premium_yearly | 구독 (연간) | ₩39,000 |

---

## 필수 법적 문서

- [ ] **개인정보처리방침**
  - URL: https://onapond.com/privacy
  - 수집 정보, 사용 목적, 제3자 제공 (Firebase, Azure)

- [ ] **이용약관**
  - URL: https://onapond.com/terms
  - 서비스 이용 조건, 구독/환불 정책

---

## 스토어 메타데이터

### 앱 설명 (한국어)
```
하루 10분, AI 튜터와 영어 성경 한 구절!

바이블스픽은 AI 발음 코칭 기술로 영어 성경을 효과적으로 암송할 수 있도록 도와주는 앱입니다.

주요 기능:
• 3단계 쉐도잉 학습 (듣고 따라하기 → 핵심 표현 → 실전 암송)
• AI 발음 평가 (정확도, 유창성, 억양 분석)
• 음소(Phoneme) 단위 피드백으로 정확한 발음 교정
• 소셜 기능 (그룹 챌린지, 친구와 함께)
• 게이미피케이션 (연속 학습, 달란트, 업적)

지원 성경:
• ESV (English Standard Version) 오디오 지원
• 말라기, 빌립보서, 시편 등

프리미엄 구독:
• 월간: ₩4,900
• 연간: ₩39,000 (33% 할인)
```

### 키워드
```
영어성경,성경암송,영어암송,성경공부,영어발음,AI튜터,쉐도잉,Bible,ESV,발음교정
```

### 카테고리
- iOS: 교육 (기본) / 라이프스타일 (보조)
- Android: 교육

---

## 심사 시 주의사항

### iOS
1. 스크린샷이 실제 앱과 일치해야 함
2. 구독 가격/조건 앱 내에 명시
3. 테스트 계정 제공 (로그인 필요 시)

### Android
1. 마이크 권한 사용 이유 설명
2. 데이터 안전 섹션 정확히 기재
3. targetSdkVersion 최신 유지
