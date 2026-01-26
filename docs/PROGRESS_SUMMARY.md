# 바이블 스픽 2.0 - 개발 진행 요약

**작성일**: 2025년 1월 26일
**버전**: 1.0.0
**저장소**: https://github.com/onapond/bible_speak

---

## 프로젝트 개요

**바이블 스픽**은 AI 발음 코칭 기술을 활용한 영어 성경 암송 학습 앱입니다.

### 핵심 가치
- 하루 10분, AI 튜터와 영어 성경 한 구절
- 3단계 쉐도잉 학습 (듣고 따라하기 → 핵심 표현 → 실전 암송)
- 실시간 발음 교정 (음소 단위 피드백)

---

## 구현 완료 현황

### Phase 1: iOS 권한 + 3단계 학습 모델 ✓

**iOS 권한 설정** (`ios/Runner/Info.plist`)
- NSMicrophoneUsageDescription: 마이크 권한
- NSSpeechRecognitionUsageDescription: 음성 인식 권한
- UIBackgroundModes: 백그라운드 오디오 재생

**3단계 학습 모델**
| 파일 | 설명 |
|------|------|
| `lib/models/learning_stage.dart` | 학습 단계 enum (listenRepeat, keyExpressions, realSpeak) |
| `lib/models/verse_progress.dart` | 구절별 진행 상태 모델 |
| `lib/services/progress_service.dart` | Firestore + SharedPreferences 하이브리드 저장 |

**학습 단계 통과 조건**
- Stage 1 (듣고 따라하기): 70% 이상
- Stage 2 (핵심 표현): 80% 이상
- Stage 3 (실전 암송): 85% 이상 → 구절 완료

---

### Phase 2: 로드맵 UI ✓

**파일**: `lib/screens/study/chapter_selection_screen.dart`

**구현 내용**
- Speak 스타일 지그재그 노드 레이아웃
- CustomPainter로 곡선 커넥터 (실선/점선)
- 챕터 상태별 시각화 (완료/진행중/잠금)
- 하단 시트 상세 패널

```
[완료] ─── [진행중] ─── [잠금] ─── [잠금]
  ●          ◐           ○          ○
 1장        2장         3장        4장
```

---

### Phase 3: 오디오 스트리밍 최적화 ✓

**TTS Service** (`lib/services/tts_service.dart`)
- 다음 구절 프리로딩 (대기 시간 감소)
- 재시도 로직 (3회, 지수 백오프)
- 캐시 만료 (30일)
- 캐시 크기 관리 (100MB 제한, 자동 정리)

**Azure 발음 평가** (`lib/services/pronunciation/azure_pronunciation_service.dart`)
- 재시도 로직 (3회) + 상세 에러 처리
- 45초 타임아웃 관리
- 오프라인 감지
- 파일 크기 검증
- 인식 상태 처리 (NoMatch, InitialSilenceTimeout, BabbleTimeout)
- 음소별 발음 팁 추가
- 연결 테스트 메서드 (`testConnection()`)

---

### Phase 4: 인앱 결제 ✓

**새로 생성된 파일**
| 파일 | 설명 |
|------|------|
| `lib/models/subscription.dart` | 구독 플랜, 프리미엄 기능, 무료 제한 |
| `lib/services/iap_service.dart` | iOS/Android 인앱 결제 서비스 |
| `lib/screens/subscription/subscription_screen.dart` | 프리미엄 구독 화면 UI |
| `lib/widgets/paywall_dialog.dart` | 페이월 다이얼로그 + 가드 유틸 |

**가격 정책**
| 플랜 | 가격 | Product ID |
|------|------|------------|
| 무료 | ₩0 | - |
| 월간 프리미엄 | ₩4,900 | `bible_speak_premium_monthly` |
| 연간 프리미엄 | ₩39,000 (33% 할인) | `bible_speak_premium_yearly` |

**무료 제한**
- 일일 3구절 학습 제한
- 말라기 1장만 접근 가능
- 기본 발음 평가만 제공

---

### 스토어 배포 준비 ✓

**Android 설정** (`android/app/build.gradle.kts`)
- `applicationId`: `com.onapond.biblespeak`
- `minSdk`: 24 (Android 7.0+)
- 릴리스 서명 설정
- ProGuard 난독화 설정

**문서**
- `docs/STORE_DEPLOYMENT.md`: 완전한 배포 가이드
- `docs/BUSINESS_PLAN.md`: 사업 기획서
- `docs/FEATURE_SPEC.md`: 기능 설계서
- `docs/TECH_ARCHITECTURE.md`: 기술 아키텍처
- `docs/MARKETING_PLAN.md`: 마케팅 전략

---

### 앱 아이콘 ✓

**디자인 요소**
- 배경: 딥 퍼플 그라데이션 (#1A1A2E)
- 메인: 흰색 펼쳐진 성경책
- 포인트: 골드 마이크 + 음파 (#FFD700)

**생성된 아이콘**
| 플랫폼 | 파일 수 | 위치 |
|--------|---------|------|
| Android | 12개 | `android/app/src/main/res/` |
| iOS | 14개 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Web | 3개 | `web/` |
| Windows | 1개 | `windows/runner/resources/` |
| macOS | 7개 | `macos/Runner/Assets.xcassets/` |

---

## 빌드 상태

| 플랫폼 | 상태 | 출력 |
|--------|------|------|
| Android APK | ✓ 성공 | `build/app/outputs/flutter-apk/app-release.apk` (53MB) |
| Android AAB | 미테스트 | `flutter build appbundle --release` |
| iOS | macOS 필요 | `flutter build ipa --release` |

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.x / Dart |
| 백엔드 | Firebase (Auth, Firestore) |
| TTS | ElevenLabs API |
| 발음 평가 | Azure Speech SDK (REST) |
| 성경 API | ESV API |
| AI 피드백 | Google Gemini |
| 인앱 결제 | in_app_purchase 패키지 |

---

## 프로젝트 구조

```
bible_speak/
├── lib/
│   ├── models/
│   │   ├── learning_stage.dart      # 학습 단계 enum
│   │   ├── verse_progress.dart      # 구절 진행 모델
│   │   └── subscription.dart        # 구독 모델
│   ├── services/
│   │   ├── progress_service.dart    # 진행 상태 관리
│   │   ├── tts_service.dart         # TTS 서비스
│   │   ├── iap_service.dart         # 인앱 결제
│   │   └── pronunciation/
│   │       └── azure_pronunciation_service.dart
│   ├── screens/
│   │   ├── study/
│   │   │   └── chapter_selection_screen.dart  # 로드맵 UI
│   │   ├── practice/
│   │   │   └── verse_practice_screen.dart     # 학습 화면
│   │   └── subscription/
│   │       └── subscription_screen.dart       # 구독 화면
│   └── widgets/
│       └── paywall_dialog.dart      # 페이월 다이얼로그
├── assets/
│   └── icon/
│       ├── app_icon.png             # 메인 아이콘
│       └── app_icon_foreground.png  # Android 적응형
├── android/
│   └── app/
│       ├── build.gradle.kts         # Android 빌드 설정
│       ├── proguard-rules.pro       # ProGuard 규칙
│       └── google-services.json     # Firebase 설정
├── ios/
│   └── Runner/
│       └── Info.plist               # iOS 권한 설정
└── docs/
    ├── BUSINESS_PLAN.md
    ├── FEATURE_SPEC.md
    ├── TECH_ARCHITECTURE.md
    ├── MARKETING_PLAN.md
    ├── STORE_DEPLOYMENT.md
    └── PROGRESS_SUMMARY.md          # 이 문서
```

---

## 커밋 히스토리

| 커밋 | 내용 |
|------|------|
| `f170f28` | fix: Android release build configuration |
| `26ccd30` | feat: Generate app icons for all platforms |
| `116c2d3` | feat: Add app icon design and launcher icons setup |
| `fc7409c` | feat: Store deployment preparation |
| `a7395b2` | feat: Phase 4 - In-app purchase integration |
| `f9fdd88` | feat: Phase 3 - Audio streaming optimization |
| `817b56b` | feat: Phase 2 - Roadmap UI |
| 이전 | Phase 1 및 기획 문서 |

---

## 배포 전 남은 작업

### 필수
- [ ] Firebase Console에서 새 패키지명으로 앱 등록 (`com.onapond.biblespeak`)
- [ ] 새 `google-services.json` 다운로드 및 교체
- [ ] 개인정보처리방침 페이지 작성 (https://onapond.com/privacy)
- [ ] 이용약관 페이지 작성 (https://onapond.com/terms)
- [ ] Apple Developer 계정 가입 ($99/년)
- [ ] Google Play Console 계정 가입 ($25)

### 스토어 등록
- [ ] App Store Connect에서 인앱 구매 상품 등록
- [ ] Google Play Console에서 구독 상품 등록
- [ ] 스크린샷 촬영 및 업로드
- [ ] 앱 설명 및 키워드 입력
- [ ] 심사 제출

---

## 빌드 명령어

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store용)
flutter build appbundle --release

# iOS (macOS에서만)
flutter build ipa --release

# 분석
flutter analyze

# 아이콘 재생성
dart run flutter_launcher_icons
```

---

## 연락처

개발: Claude Code (AI Assistant)
프로젝트 소유자: onapond
