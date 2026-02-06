# 바이블스픽 개발 세션 요약
> 2026년 1월 29일 작업 내역

## 프로젝트 개요

**바이블스픽 (BibleSpeak)**은 AI 발음 코칭으로 영어 성경을 암송하는 Flutter 앱입니다.

### 기술 스택
- **프레임워크**: Flutter 3.x (Android, iOS, Web)
- **백엔드**: Firebase (Auth, Firestore, Storage, FCM)
- **음성 인식**: Azure Speech Services
- **TTS**: ESV API
- **AI 피드백**: Google Gemini
- **오프라인**: Hive

### Bundle ID
- `com.onapond.biblespeak`

---

## 오늘 완료된 작업

### 1. 스토어 배포 준비

#### 스크린샷 도우미
- `lib/screens/admin/screenshot_helper_screen.dart` 생성
- 프로필 화면 → 관리자 도구에서 접근 가능
- 핵심 화면 6개로 빠른 이동 (온보딩, 메인, 암송, 통계, 복습, 업적)

#### TestFlight/Codemagic 설정
- `docs/TESTFLIGHT_GUIDE.md` - 상세 배포 가이드
- `codemagic.yaml` - CI/CD 설정 파일
- `ios/ExportOptions.plist` - App Store 배포 옵션
- `ios/Runner/Info.plist` - ITSAppUsesNonExemptEncryption 추가

#### 스토어 메타데이터
- `docs/STORE_LISTING.md` 생성
- 앱 설명 (한국어/영어)
- 키워드, What's New
- 스크린샷 캡션
- 연령 등급 질문지
- 인앱 구매 정보

### 2. 버그 수정 및 최적화

#### Warning 해결 (flutter analyze)
- `member_list_card.dart` - 미사용 필드 제거
- `main_menu_screen.dart` - 불필요한 `!` 연산자 수정
- `tutor_coordinator.dart` - 미사용 메서드 제거
- `streak_widget.dart` - Dead code 제거, `withOpacity` → `withValues`

#### 웹 네비게이션 버그 수정
- `splash_screen.dart` - 온보딩 완료 후 네비게이션 context 문제 해결
- SplashScreen context 대신 MaterialPageRoute builder context 사용

### 3. 앱 최적화

#### Android 빌드
| 타입 | 크기 |
|------|------|
| Fat APK | 57.6 MB |
| Split APK (arm) | 20.2 MB |
| Split APK (arm64) | 22.3 MB |
| AAB | 47.8 MB |

#### 웹 빌드
- API 키를 `--dart-define`으로 빌드에 포함
- 빌드 크기: 33 MB (CanvasKit 27 MB 포함)

### 4. 문서화

#### 종합 앱 문서
- `docs/APP_DOCUMENTATION.md` (541줄)
- 모든 기능, 화면, 서비스, 모델 문서화
- 3단계 학습, SM-2 복습, 게이미피케이션 상세 설명

### 5. 웹 배포

- **URL**: https://bible-speak.web.app
- Firebase Hosting 사용
- API 키 포함 빌드 배포 완료

---

## 현재 상태

### 완료된 기능
- [x] 3단계 학습 시스템 (Listen & Repeat → Key Expressions → Real Speak)
- [x] AI 발음 평가 (Azure Speech Services)
- [x] AI 피드백 (Google Gemini)
- [x] 스마트 복습 (SM-2 알고리즘)
- [x] 연속 학습 (Streak) 시스템
- [x] 업적 및 레벨 시스템
- [x] 탈란트 샵
- [x] 그룹 챌린지
- [x] 그룹 채팅
- [x] 푸시 알림 (FCM)
- [x] 오프라인 지원 (Hive)
- [x] 온보딩 튜토리얼

### 배포 상태
| 플랫폼 | 상태 |
|--------|------|
| Android | APK 빌드 완료, 테스트 완료 |
| iOS | 빌드 설정 완료, TestFlight 대기 |
| Web | Firebase Hosting 배포 완료 |

---

## 다음 단계 (TODO)

### 즉시 가능
1. [ ] 웹 버그 테스트 (온보딩 네비게이션, ESV 로딩)
2. [ ] 실제 스크린샷 촬영
3. [ ] 앱 아이콘 최종 확인

### 스토어 배포 필요
4. [ ] Apple Developer 계정으로 TestFlight 배포
5. [ ] Google Play Console 내부 테스트 트랙 배포
6. [ ] 베타 테스터 피드백 수집
7. [ ] 스토어 심사 제출

---

## 주요 파일 위치

### 설정 파일
```
├── pubspec.yaml              # 앱 설정, 의존성
├── firebase.json             # Firebase 설정
├── codemagic.yaml            # CI/CD 설정
├── assets/.env               # API 키 (git 제외)
└── lib/config/app_config.dart # 앱 설정 클래스
```

### 핵심 화면
```
lib/screens/
├── splash_screen.dart           # 스플래시
├── onboarding/onboarding_screen.dart # 온보딩
├── home/main_menu_screen.dart   # 메인 메뉴
├── practice/verse_practice_screen.dart # 암송 연습 (핵심)
├── review/review_screen.dart    # 복습
├── stats/stats_dashboard_screen.dart # 통계
└── achievement/achievement_screen.dart # 업적
```

### 핵심 서비스
```
lib/services/
├── auth_service.dart            # 인증
├── tts_service.dart             # TTS (ESV 오디오)
├── recording_service.dart       # 녹음
├── pronunciation/azure_pronunciation_service.dart # 발음 평가
├── gemini_service.dart          # AI 피드백
├── review_service.dart          # 복습 (SM-2)
└── social/streak_service.dart   # 연속 학습
```

### 문서
```
docs/
├── APP_DOCUMENTATION.md         # 종합 앱 문서
├── STORE_LISTING.md             # 스토어 메타데이터
├── TESTFLIGHT_GUIDE.md          # iOS 배포 가이드
├── SCREENSHOT_GUIDE.md          # 스크린샷 가이드
├── DEPLOYMENT_CHECKLIST.md      # 배포 체크리스트
└── legal/                       # 법적 문서
    ├── PRIVACY_POLICY.md
    └── TERMS_OF_SERVICE.md
```

---

## 알려진 이슈

### 해결됨
- [x] 온보딩 "시작하기" 버튼 네비게이션 안됨 → context 문제 수정
- [x] 웹 빌드 시 API 키 누락 → dart-define으로 해결

### 확인 필요
- [ ] ESV 오디오 프록시 동작 확인 (`https://bible-speak-proxy.tlsdygksdev.workers.dev`)
- [ ] 웹에서 Azure Speech 발음 평가 동작 확인

---

## 빌드 명령어

### Android
```bash
# Split APK (권장)
flutter build apk --release --split-per-abi

# AAB (Play Store)
flutter build appbundle --release
```

### iOS
```bash
flutter build ipa --release
```

### Web (API 키 포함)
```bash
flutter build web --release \
  --dart-define=ESV_API_KEY=xxx \
  --dart-define=GEMINI_API_KEY=xxx \
  --dart-define=AZURE_SPEECH_KEY=xxx \
  --dart-define=AZURE_SPEECH_REGION=koreacentral
```

### 웹 배포
```bash
firebase deploy --only hosting
```

---

## Git 커밋 히스토리 (오늘)

```
de95934 fix: Fix onboarding navigation context issue on web
557f80c docs: Add comprehensive app documentation
56fd358 fix: Resolve all warning-level issues from flutter analyze
db0eb5b docs: Add store listing metadata for App Store and Play Store
18ec2b6 docs: Add TestFlight deployment guide and Codemagic CI/CD config
fec609a feat: Add screenshot helper for store deployment
```

---

## 연락처

- **개발사**: Onapond
- **이메일**: support@onapond.com
- **GitHub**: https://github.com/onapond/bible_speak

---

*문서 작성일: 2026년 1월 29일*
*다음 세션에서 이 문서를 참고하여 작업을 이어갈 수 있습니다.*
