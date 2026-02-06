# 바이블스픽 - 프로젝트 현재 상태

> 최종 업데이트: 2026년 2월 6일

---

## 프로젝트 개요

**바이블스픽 (BibleSpeak)** 은 AI 발음 코칭 기술을 활용한 영어 성경 암송 학습 앱입니다.

### 핵심 가치
- 하루 10분, AI 튜터와 영어 성경 한 구절
- 3단계 쉐도잉 학습 (듣고 따라하기 → 핵심 표현 → 실전 암송)
- 실시간 발음 교정 (음소 단위 피드백)

### Bundle ID
- `com.onapond.biblespeak`

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.x / Dart |
| 상태 관리 | Riverpod (주력) + Provider (레거시) |
| 백엔드 | Firebase (Auth, Firestore, Storage, FCM) |
| 음성 인식 | Azure Speech Services (Korea Central) |
| TTS | ESV API (성경), ElevenLabs (일반) |
| AI 피드백 | Google Gemini |
| 인앱 결제 | in_app_purchase 패키지 |
| 오디오 | audioplayers, record 패키지 |
| 오프라인 | Hive |

---

## 배포 상태

| 플랫폼 | 상태 | URL/파일 |
|--------|------|----------|
| **Web** | 배포 완료 | https://bible-speak.web.app |
| **Android** | 빌드 완료 | `build/app/outputs/bundle/release/app-release.aab` (47.8MB) |
| **iOS** | 빌드 설정 완료 | TestFlight 대기 (macOS 필요) |

### 관련 URL
- 웹앱: https://bible-speak.web.app
- Firebase Console: https://console.firebase.google.com/project/bible-speak
- ESV Audio Proxy: https://bible-speak-proxy.tlsdygksdev.workers.dev
- GitHub: https://github.com/onapond/bible_speak

---

## 완료된 기능

### 핵심 학습
- [x] 3단계 학습 시스템 (Listen & Repeat → Key Expressions → Real Speak)
- [x] AI 발음 평가 (Azure Speech Services)
- [x] AI 피드백 (Google Gemini)
- [x] 스마트 복습 (SM-2 알고리즘)
- [x] ESV 성경 오디오 재생

### 게이미피케이션
- [x] 연속 학습 (Streak) 시스템 + 마일스톤 보상
- [x] 업적 및 레벨 시스템
- [x] 달란트 샵
- [x] 아침 만나 (Early Bird 보너스)

### 소셜
- [x] 그룹 챌린지 (성전 쌓기)
- [x] 그룹 채팅
- [x] 활동 피드 (반응 시스템)
- [x] 찌르기 시스템 (비활성 멤버 격려)

### 인프라
- [x] Firebase 인증 (익명, Google, Apple)
- [x] 푸시 알림 (FCM)
- [x] 오프라인 지원 (Hive)
- [x] 온보딩 튜토리얼
- [x] PWA 업데이트 시스템

### 인앱 결제
- [x] 월간 프리미엄: ₩4,900
- [x] 연간 프리미엄: ₩39,000 (33% 할인)

### 아키텍처 개선 (2026-02-05~06)
- [x] Riverpod 상태 관리 (Phase 1-2 + Tier 1)
- [x] Parchment 테마 시스템 (코드 기반 텍스처)
- [x] PWA 무한 새로고침 버그 수정 (sessionStorage 플래그)

---

## 미구현/계획 중인 기능

| 기능 | 상태 | 참고 문서 |
|------|------|----------|
| 단어 공부 | 기획 완료 | `docs/단어공부_기획서.md` |
| iOS TestFlight 배포 | 대기 중 | macOS 환경 필요 |
| Play Store 배포 | 대기 중 | AAB 파일 준비 완료 |

---

## 알려진 이슈

### 해결 필요
- [ ] 기존 익명 사용자 데이터 마이그레이션 (Firebase Console 수동 작업)
- [ ] ReviewService getStats()에서 totalReviews/totalCorrect는 0 반환 (집계 쿼리 한계)

### 해결됨 (최근)
- [x] PWA 무한 새로고침 루프 → sessionStorage 플래그 (2026-02-06)
- [x] iOS PWA 업데이트 문제 → 서비스 워커 + SKIP_WAITING 구현
- [x] 메모리 누수 → 서비스 싱글톤화, dispose 보완
- [x] Firestore update 실패 → set(merge: true) 패턴 적용
- [x] 웹 녹음 0점 문제 → WAV 형식으로 변경

---

## 빌드 명령어

### 웹 빌드 (필수: API 키 주입)
```powershell
powershell -ExecutionPolicy Bypass -File build_web.ps1
```

### 웹 배포
```bash
firebase deploy --only hosting
```

### Android
```bash
# Split APK (테스트용)
flutter build apk --release --split-per-abi

# AAB (Play Store용)
flutter build appbundle --release
```

### iOS (macOS에서만)
```bash
flutter build ipa --release
```

### 분석
```bash
flutter analyze
```

---

## 주요 파일 구조

```
bible_speak/
├── lib/
│   ├── providers/                        # Riverpod providers (NEW)
│   │   ├── core_providers.dart
│   │   ├── auth_provider.dart
│   │   └── texture_provider.dart
│   ├── screens/
│   │   ├── home/main_menu_screen.dart      # 메인 메뉴
│   │   ├── practice/verse_practice_screen.dart  # 암송 연습 (핵심)
│   │   ├── review/review_screen.dart       # 복습
│   │   ├── stats/stats_dashboard_screen.dart   # 통계
│   │   └── social/community_screen.dart    # 커뮤니티
│   ├── services/
│   │   ├── pronunciation/azure_pronunciation_service.dart  # 발음 평가
│   │   ├── social/streak_service.dart      # 연속 학습
│   │   ├── review_service.dart             # 복습 (SM-2)
│   │   └── tts_service.dart                # TTS
│   ├── models/
│   │   ├── learning_stage.dart             # 학습 단계
│   │   ├── verse_progress.dart             # 진행 상태
│   │   └── user_streak.dart                # 스트릭
│   └── widgets/
│       ├── social/                         # 소셜 위젯
│       └── ux_widgets.dart                 # UX 위젯 모음
├── docs/
│   ├── CHANGELOG.md                        # 변경 이력
│   ├── PROJECT_STATUS.md                   # 이 문서
│   ├── BUG_FIXES.md                        # 버그 패턴
│   ├── APP_DOCUMENTATION.md                # 종합 앱 문서
│   └── FEATURE_SPEC.md                     # 기능 설계서
└── web/
    ├── index.html                          # PWA 설정 포함
    └── custom_service_worker.js            # 업데이트 처리
```

---

## 환경 설정

### API 키 (.env 파일)
```
ESV_API_KEY=...
GEMINI_API_KEY=...
ELEVENLABS_API_KEY=...
AZURE_SPEECH_KEY=...
AZURE_SPEECH_REGION=koreacentral
```

### Android 서명 키
- 위치: `android/upload-keystore.jks`
- 설정: `android/key.properties`
- 템플릿: `android/key.properties.template`

---

## 플랫폼별 기능 지원

| 기능 | Android | iOS | Web |
|------|---------|-----|-----|
| 성경 텍스트 | ✅ | ✅ | ✅ |
| 오디오 재생 | ✅ | ✅ | ✅ (프록시) |
| 녹음 | ✅ WAV | ✅ WAV | ✅ WAV |
| 발음 평가 | ✅ | ✅ | ✅ |
| 로컬 캐시 | ✅ | ✅ | ❌ |
| 푸시 알림 | ✅ | ✅ | ❌ |

---

## 연락처

- **개발사**: Onapond
- **이메일**: support@onapond.com
- **GitHub**: https://github.com/onapond/bible_speak
