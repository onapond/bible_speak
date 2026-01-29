# 바이블스픽 (BibleSpeak) 앱 문서

> AI 발음 코칭으로 영어 성경을 암송하는 학습 앱

---

## 1. 앱 개요

### 1.1 목적
바이블스픽은 **영어 성경 암송**을 돕는 모바일/웹 앱입니다. AI 기반 발음 평가와 과학적인 반복 학습(Spaced Repetition)을 통해 사용자가 효과적으로 성경 구절을 암기하고 발음을 교정할 수 있도록 지원합니다.

### 1.2 핵심 가치
- **AI 발음 코칭**: Azure Speech Services를 활용한 실시간 발음 분석
- **3단계 학습 시스템**: 듣기 → 따라하기 → 암송의 체계적 학습 과정
- **스마트 복습**: SM-2 알고리즘 기반 간격 반복 학습
- **게이미피케이션**: 업적, 레벨, 탈란트 보상 시스템
- **소셜 기능**: 그룹 챌린지, 친구, 넛지(격려) 시스템

### 1.3 지원 플랫폼
| 플랫폼 | 상태 |
|--------|------|
| Android | ✅ 지원 |
| iOS | ✅ 지원 |
| Web | ✅ 지원 |

### 1.4 기술 스택
- **프레임워크**: Flutter 3.x
- **백엔드**: Firebase (Auth, Firestore, Storage, FCM)
- **음성 인식**: Azure Speech Services
- **TTS**: ESV API (성경 오디오)
- **AI 피드백**: Google Gemini
- **오프라인**: Hive (로컬 캐싱)

---

## 2. 사용자 시스템

### 2.1 인증
- Firebase Authentication 기반
- 이메일/비밀번호 로그인
- 익명 로그인 지원

### 2.2 사용자 역할
| 역할 | 설명 | 권한 |
|------|------|------|
| `admin` | 전체 관리자 | 모든 기능 + 관리자 도구 |
| `leader` | 그룹 리더 | 그룹 관리, 멤버 관리 |
| `member` | 일반 멤버 | 기본 학습 기능 |

### 2.3 사용자 데이터
```
UserModel
├── uid: 고유 ID
├── name: 이름
├── email: 이메일
├── groupId: 소속 그룹
├── role: 역할 (admin/leader/member)
├── talants: 보유 탈란트 (인앱 재화)
├── completedVerses: 완료한 구절 목록
└── createdAt: 가입일
```

---

## 3. 학습 시스템

### 3.1 3단계 학습 (Learning Stages)

바이블스픽의 핵심 학습 방법론입니다.

| 단계 | 이름 | 설명 | 통과 기준 |
|------|------|------|----------|
| **Stage 1** | 듣고 따라하기 (Listen & Repeat) | 전체 자막을 보며 원어민 발음을 듣고 따라합니다 | 70점 이상 |
| **Stage 2** | 핵심 표현 (Key Expressions) | 일부 단어가 빈칸으로 표시됩니다. 기억하며 따라합니다 | 75점 이상 |
| **Stage 3** | 실전 암송 (Real Speak) | 자막 없이 완전히 암송합니다 | 80점 이상 |

### 3.2 학습 흐름
```
1. 성경책 선택 (Book Selection)
   └── 요한복음, 히브리서, 빌립보서 등

2. 장 선택 (Chapter Selection)
   └── 각 책의 장 목록

3. 구절 로드맵 (Verse Roadmap)
   └── 구절별 진행 상황 확인

4. 암송 연습 (Verse Practice)
   ├── Stage 1: 듣고 따라하기
   ├── Stage 2: 빈칸 채우기
   └── Stage 3: 완전 암송

5. AI 발음 평가
   ├── 전체 점수
   ├── 단어별 정확도
   └── AI 코멘트 및 개선점
```

### 3.3 발음 평가 시스템

#### 3.3.1 Azure Speech Services 연동
- 실시간 음성 녹음
- 발음 정확도 분석
- 단어별 점수 제공

#### 3.3.2 평가 항목
| 항목 | 설명 |
|------|------|
| AccuracyScore | 발음 정확도 |
| FluencyScore | 유창성 |
| CompletenessScore | 완성도 |
| PronScore | 종합 발음 점수 |

#### 3.3.3 AI 피드백 (Gemini)
- 발음 평가 결과를 바탕으로 맞춤형 피드백 생성
- 개선이 필요한 부분 구체적 안내
- 격려 메시지 제공

### 3.4 TTS (Text-to-Speech)
- ESV API를 통한 원어민 성경 오디오 제공
- 웹 환경 인메모리 캐싱 (최근 10개 구절)
- 오디오 프리로딩으로 지연 시간 최소화

---

## 4. 복습 시스템 (Spaced Repetition)

### 4.1 SM-2 알고리즘
과학적으로 검증된 간격 반복 학습 알고리즘을 적용합니다.

#### 핵심 변수
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `easinessFactor` | 난이도 계수 | 2.5 |
| `interval` | 다음 복습까지 일수 | 1 |
| `repetitions` | 연속 성공 횟수 | 0 |

#### 복습 품질 등급
| 등급 | 값 | 설명 |
|------|---|------|
| `forgot` | 0 | 완전히 잊음 |
| `needHint` | 1 | 힌트 필요 |
| `hard` | 2 | 어렵게 기억 |
| `normal` | 3 | 보통 |
| `easy` | 4 | 쉬움 |
| `perfect` | 5 | 완벽 |

### 4.2 복습 레벨
| 레벨 | 이름 | 조건 |
|------|------|------|
| 1 | 시작 | interval < 3일 |
| 2 | 학습 중 | interval 3-6일 |
| 3 | 익숙 | interval 7-13일 |
| 4 | 숙련 | interval 14-29일 |
| 5 | 마스터 | interval 30일+ |

### 4.3 복습 알림
- 복습 예정일에 푸시 알림
- 앱 내 복습 필요 구절 표시
- 복습 세션 결과 통계

---

## 5. 게이미피케이션

### 5.1 탈란트 (Talant)
앱 내 재화 시스템입니다. 성경의 '달란트' 비유에서 착안했습니다.

#### 획득 방법
- 일일 학습 완료
- 연속 학습 보너스
- 업적 달성
- 그룹 챌린지 완료
- 얼리버드 보너스 (오전 6시 이전 학습)

#### 사용처
- 탈란트 샵에서 아이템 구매
- 뱃지, 테마 등 커스터마이징

### 5.2 업적 시스템 (Achievements)

#### 업적 카테고리
| 카테고리 | 아이콘 | 설명 |
|----------|--------|------|
| 연속 학습 | 🔥 | 연속 학습일 기반 |
| 구절 암송 | 📖 | 완료한 구절 수 기반 |
| 탈란트 | 💰 | 획득한 탈란트 기반 |
| 소셜 | 👥 | 소셜 활동 기반 |
| 특별 | ⭐ | 특수 조건 달성 |

#### 업적 등급
| 등급 | 색상 | 난이도 |
|------|------|--------|
| 브론즈 | 🟤 | 입문 |
| 실버 | ⚪ | 중급 |
| 골드 | 🟡 | 고급 |
| 플래티넘 | ⚫ | 전문가 |
| 다이아 | 💎 | 마스터 |

#### 주요 업적 예시
| 업적명 | 조건 | 보상 |
|--------|------|------|
| 첫 걸음 | 3일 연속 학습 | 10 탈란트 |
| 일주일 도전 | 7일 연속 학습 | 30 탈란트 |
| 100일 전설 | 100일 연속 학습 | 300 탈란트 |
| 첫 구절 | 첫 번째 구절 완료 | 5 탈란트 |
| 암송 마스터 | 200개 구절 완료 | 500 탈란트 |
| 얼리버드 | 오전 6시 이전 학습 | 20 탈란트 |

### 5.3 레벨 시스템
사용자 경험치(XP)에 따른 레벨 시스템입니다.

#### XP 계산
```
총 XP = (학습일 × 10) + (완료 구절 × 5) + (최장 연속 학습 × 3)
```

#### 레벨 테이블
| 레벨 | 필요 XP | 칭호 | 이모지 |
|------|---------|------|--------|
| 1 | 0 | 새싹 | 🌱 |
| 2 | 100 | 풀잎 | 🌿 |
| 3 | 300 | 나무 | 🌳 |
| 4 | 600 | 꽃봉오리 | 🌸 |
| 5 | 1000 | 꽃 | 🌺 |
| 6 | 1500 | 해바라기 | 🌻 |
| 7 | 2100 | 별 | ⭐ |
| 8 | 2800 | 유성 | 💫 |
| 9 | 3600 | 빛나는 별 | 🌟 |
| 10 | 4500 | 왕관 | 👑 |

### 5.4 연속 학습 (Streak)
매일 학습을 이어가면 연속 학습일이 증가합니다.

#### 연속 학습 보호
- 하루 쉬기 아이템으로 연속 학습 유지 가능
- 연속 학습 보호권 구매 (탈란트 샵)

---

## 6. 소셜 기능

### 6.1 그룹 시스템
사용자들이 그룹을 만들어 함께 학습할 수 있습니다.

#### 그룹 기능
- 그룹 생성/참여
- 그룹 대시보드
- 멤버 목록 및 활동 현황
- 그룹 랭킹

### 6.2 그룹 챌린지
주간 단위로 그룹 목표를 설정하고 함께 달성합니다.

```
WeeklyChallenge
├── targetVerses: 목표 구절 수
├── currentProgress: 현재 진행률
├── participants: 참여자 목록
└── rewards: 완료 시 보상
```

### 6.3 활동 피드
그룹 내 멤버들의 활동을 실시간으로 확인합니다.

#### 활동 타입
| 타입 | 설명 |
|------|------|
| `verseCompleted` | 구절 완료 |
| `streakAchieved` | 연속 학습 달성 |
| `achievementUnlocked` | 업적 해제 |
| `levelUp` | 레벨업 |
| `challengeContribution` | 챌린지 기여 |

### 6.4 넛지 (Nudge)
비활성 멤버에게 격려 메시지를 보냅니다.

- 리더가 비활성 멤버 확인
- 격려 메시지 전송
- 푸시 알림으로 전달

### 6.5 친구 시스템
- 친구 추가/삭제
- 친구 활동 확인
- 친구에게 넛지 보내기

### 6.6 그룹 채팅
그룹 내 실시간 채팅 기능입니다.

---

## 7. 알림 시스템

### 7.1 푸시 알림 (FCM)
Firebase Cloud Messaging을 통한 푸시 알림입니다.

#### 알림 종류
| 타입 | 설명 |
|------|------|
| `studyReminder` | 학습 리마인더 |
| `reviewDue` | 복습 알림 |
| `streakWarning` | 연속 학습 위험 알림 |
| `nudge` | 격려 메시지 |
| `achievementUnlocked` | 업적 해제 알림 |
| `groupActivity` | 그룹 활동 알림 |

### 7.2 알림 설정
사용자가 알림 종류별로 on/off 설정 가능합니다.

---

## 8. 오프라인 지원

### 8.1 Hive 캐싱
로컬 데이터베이스를 통한 오프라인 지원입니다.

#### 캐싱 대상
- 성경 구절 데이터
- 사용자 진행 상황
- 복습 아이템

### 8.2 동기화
- 온라인 복귀 시 자동 동기화
- 충돌 해결 로직
- 동기화 큐 관리

---

## 9. 탈란트 샵

### 9.1 상품 카테고리
| 카테고리 | 설명 |
|----------|------|
| `badge` | 프로필 뱃지 |
| `theme` | 앱 테마 |
| `protection` | 연속 학습 보호권 |
| `boost` | 부스트 아이템 |

### 9.2 인앱 결제
| 상품 | 가격 |
|------|------|
| 프리미엄 월간 | ₩4,900 |
| 프리미엄 연간 | ₩39,000 |
| 탈란트 100개 | ₩1,100 |
| 탈란트 500개 | ₩4,400 |

---

## 10. 화면 구성

### 10.1 메인 화면
| 화면 | 파일 | 설명 |
|------|------|------|
| 스플래시 | `splash_screen.dart` | 앱 시작 화면 |
| 온보딩 | `onboarding_screen.dart` | 신규 사용자 튜토리얼 |
| 메인 메뉴 | `main_menu_screen.dart` | 홈 대시보드 |
| 프로필 | `profile_screen.dart` | 사용자 프로필 |

### 10.2 학습 화면
| 화면 | 파일 | 설명 |
|------|------|------|
| 성경책 선택 | `book_selection_screen.dart` | 책 목록 |
| 장 선택 | `chapter_selection_screen.dart` | 장 목록 |
| 구절 로드맵 | `verse_roadmap_screen.dart` | 진행 상황 |
| 암송 연습 | `verse_practice_screen.dart` | 핵심 학습 화면 |

### 10.3 복습 화면
| 화면 | 파일 | 설명 |
|------|------|------|
| 복습 | `review_screen.dart` | 플래시카드 복습 |

### 10.4 통계/업적 화면
| 화면 | 파일 | 설명 |
|------|------|------|
| 통계 대시보드 | `stats_dashboard_screen.dart` | 학습 통계 |
| 업적 | `achievement_screen.dart` | 업적 목록 |
| 랭킹 | `ranking_screen.dart` | 그룹 랭킹 |

### 10.5 소셜 화면
| 화면 | 파일 | 설명 |
|------|------|------|
| 그룹 대시보드 | `group_dashboard_screen.dart` | 그룹 홈 |
| 그룹 선택 | `group_select_screen.dart` | 그룹 참여/생성 |
| 친구 | `friend_screen.dart` | 친구 목록 |
| 그룹 채팅 | `group_chat_screen.dart` | 채팅 |

### 10.6 설정 화면
| 화면 | 파일 | 설명 |
|------|------|------|
| 알림 설정 | `notification_settings_screen.dart` | 알림 관리 |
| 테마 설정 | `theme_settings_screen.dart` | 테마 변경 |

### 10.7 샵 화면
| 화면 | 파일 | 설명 |
|------|------|------|
| 샵 | `shop_screen.dart` | 탈란트 샵 |
| 인벤토리 | `inventory_screen.dart` | 구매한 아이템 |
| 구독 | `subscription_screen.dart` | 프리미엄 구독 |

### 10.8 단어 학습 (보조 기능)
| 화면 | 파일 | 설명 |
|------|------|------|
| 단어 학습 홈 | `word_study_home_screen.dart` | 단어 학습 메뉴 |
| 단어 목록 | `word_list_screen.dart` | 단어 목록 |
| 플래시카드 | `flashcard_screen.dart` | 단어 암기 |
| 퀴즈 | `quiz_screen.dart` | 단어 퀴즈 |

---

## 11. 서비스 구성

### 11.1 핵심 서비스
| 서비스 | 파일 | 역할 |
|--------|------|------|
| AuthService | `auth_service.dart` | 인증 관리 |
| TTSService | `tts_service.dart` | 음성 재생 |
| RecordingService | `recording_service.dart` | 음성 녹음 |
| AzurePronunciationService | `azure_pronunciation_service.dart` | 발음 평가 |
| GeminiService | `gemini_service.dart` | AI 피드백 |
| ReviewService | `review_service.dart` | 복습 관리 |

### 11.2 데이터 서비스
| 서비스 | 파일 | 역할 |
|--------|------|------|
| BibleDataService | `bible_data_service.dart` | 성경 데이터 |
| ProgressService | `progress_service.dart` | 진행 상황 |
| StatsService | `stats_service.dart` | 통계 |
| AchievementService | `achievement_service.dart` | 업적 |

### 11.3 소셜 서비스
| 서비스 | 파일 | 역할 |
|--------|------|------|
| GroupService | `group_service.dart` | 그룹 관리 |
| GroupChallengeService | `group_challenge_service.dart` | 챌린지 |
| FriendService | `friend_service.dart` | 친구 |
| NudgeService | `nudge_service.dart` | 넛지 |
| StreakService | `streak_service.dart` | 연속 학습 |
| ChatService | `chat_service.dart` | 채팅 |

### 11.4 시스템 서비스
| 서비스 | 파일 | 역할 |
|--------|------|------|
| NotificationService | `notification_service.dart` | 알림 |
| IAPService | `iap_service.dart` | 인앱 결제 |
| ShopService | `shop_service.dart` | 샵 |
| OfflineManager | `offline_manager.dart` | 오프라인 |
| CacheService | `cache_service.dart` | 캐싱 |

---

## 12. 데이터 모델

### 12.1 사용자 관련
| 모델 | 파일 | 설명 |
|------|------|------|
| UserModel | `user_model.dart` | 사용자 정보 |
| UserStats | `user_stats.dart` | 사용자 통계 |
| UserStreak | `user_streak.dart` | 연속 학습 |

### 12.2 학습 관련
| 모델 | 파일 | 설명 |
|------|------|------|
| LearningStage | `learning_stage.dart` | 3단계 학습 |
| VerseProgress | `verse_progress.dart` | 구절 진행 |
| ReviewItem | `review_item.dart` | 복습 아이템 |

### 12.3 소셜 관련
| 모델 | 파일 | 설명 |
|------|------|------|
| GroupModel | `group_model.dart` | 그룹 |
| GroupActivity | `group_activity.dart` | 활동 |
| Friend | `friend.dart` | 친구 |
| Nudge | `nudge.dart` | 넛지 |
| ChatMessage | `chat_message.dart` | 채팅 메시지 |

### 12.4 게이미피케이션
| 모델 | 파일 | 설명 |
|------|------|------|
| Achievement | `achievement.dart` | 업적 |
| ShopItem | `shop_item.dart` | 샵 아이템 |
| Subscription | `subscription.dart` | 구독 |

---

## 13. API 연동

### 13.1 Firebase
| 서비스 | 용도 |
|--------|------|
| Authentication | 사용자 인증 |
| Firestore | 데이터베이스 |
| Storage | 파일 저장 |
| Cloud Messaging | 푸시 알림 |

### 13.2 외부 API
| API | 용도 |
|-----|------|
| Azure Speech Services | 발음 평가 |
| ESV API | 성경 오디오 |
| Google Gemini | AI 피드백 |

---

## 14. 보안 및 개인정보

### 14.1 데이터 보호
- Firebase Security Rules 적용
- 사용자 데이터 암호화
- API 키 환경 변수 관리

### 14.2 개인정보 처리
- 개인정보처리방침 제공
- 이용약관 제공
- 데이터 삭제 요청 지원

---

## 15. 버전 정보

| 항목 | 값 |
|------|-----|
| 앱 버전 | 1.0.0 |
| 빌드 번호 | 1 |
| Bundle ID | com.onapond.biblespeak |
| 최소 Android | API 24 (Android 7.0) |
| 최소 iOS | iOS 12.0 |

---

## 16. 연락처

| 항목 | 정보 |
|------|------|
| 개발사 | Onapond |
| 이메일 | support@onapond.com |
| 웹사이트 | https://onapond.com/biblespeak |

---

*문서 작성일: 2026년 1월 29일*
*Generated by Claude Code*
