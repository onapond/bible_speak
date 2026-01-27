# Bible Speak 소셜 UX 구현 진행상황

**Last Updated:** 2026-01-27
**Session:** Social UX Implementation Phase

---

## 완료된 기능 (Completed Features)

### 1. 스트릭 시스템 (Streak System) ✅
**커밋:** `feafe53`

**파일 구조:**
- `lib/models/user_streak.dart` - UserStreak, StreakMilestone 모델
- `lib/services/social/streak_service.dart` - Firestore 기반 스트릭 관리
- `lib/widgets/social/streak_widget.dart` - StreakWidget, StreakProtectionDialog, MilestoneAchievedDialog

**주요 기능:**
- 연속 학습일 추적 (currentStreak, longestStreak)
- 마일스톤 보상: 3/7/14/21/30/100/365일
- 스트릭 보호권: 100 달란트, 월 2회 제한, 7일 이상 스트릭 필요
- 21일 습관 형성 프로그레스 바
- 주간 캘린더 (월~일)

**Firestore 스키마:** `users/{uid}/streak`

---

### 2. 그룹 활동 피드 (Activity Stream) ✅
**커밋:** `aaaf266`, `710dcb7`

**파일 구조:**
- `lib/models/group_activity.dart` - ActivityType, ReactionType, GroupActivity 모델
- `lib/services/social/group_activity_service.dart` - 활동 게시, 반응 토글
- `lib/widgets/social/activity_ticker.dart` - ActivityTicker 위젯

**주요 기능:**
- 활동 유형: verse_complete, stage3_clear, streak_milestone, joined_group
- 반응 시스템: 👏 박수, 🙏 기도, 💪 화이팅
- Optimistic UI (즉시 반응 후 서버 동기화)
- 7일 TTL (자동 만료)
- 중복 방지 (같은 구절 하루 1회)

**Firestore 스키마:** `groups/{groupId}/activities/{activityId}`

---

### 3. 성전 쌓기 챌린지 (Temple Building) ✅
**커밋:** `aaaf266`, `710dcb7`

**파일 구조:**
- `lib/services/social/group_challenge_service.dart` - 주간 챌린지 관리
- `lib/widgets/social/group_goal_widget.dart` - GroupGoalWidget, 성전 시각화

**주요 기능:**
- 주간 그룹 목표 (기본 100절)
- 성전 건축 시각화 (CustomPaint)
- 개인 기여도 추적
- ISO 주차 ID 기반 (YYYY-Www)
- 목표 달성 시 축하 다이얼로그

**Firestore 스키마:** `groups/{groupId}/challenges/{weekId}`

---

### 4. 아침 만나 (Morning Manna) ✅
**커밋:** `a932d90`

**파일 구조:**
- `lib/models/daily_verse.dart` - DailyVerse, EarlyBirdBonus, SeasonalVerse, CuratedVerses
- `lib/services/social/morning_manna_service.dart` - 오늘의 구절 선정, 보너스 클레임
- `lib/widgets/social/morning_manna_widget.dart` - MorningMannaWidget, EarlyBirdBonusDialog

**주요 기능:**
- 오늘의 구절 선정 알고리즘 (시즌 → 큐레이션)
- Early Bird 보너스:
  - 05:00-06:00: +3 달란트 🌅
  - 06:00-07:00: +2 달란트 ☀️
  - 07:00-08:00: +1 달란트 🌤️
- 시즌 구절: 신년 (1/1-1/7), 성탄절 (12/20-12/25)
- 10개 큐레이션 명구절 (날짜 기반 로테이션)

**Firestore 스키마:** `users/{uid}/earlyBird`, `global/dailyVerse`

---

### 5. 찌르기 시스템 (Nudge System) ✅
**커밋:** `240e36b`

**파일 구조:**
- `lib/models/nudge.dart` - Nudge, NudgeTemplate, InactiveMember, NudgeDailyStats
- `lib/services/social/nudge_service.dart` - 찌르기 전송/수신, 비활성 멤버 조회
- `lib/widgets/social/nudge_widget.dart` - InactiveMembersWidget, NudgeMessageDialog, NudgeReceivedDialog

**주요 기능:**
- 비활성 멤버 감지 (3일 이상 미접속)
- 메시지 템플릿 4종 + 직접 작성
- 일일 제한: 3회/일 (리더 10회)
- 동일 대상 24시간 내 1회 제한
- 상태 표시: 😴 (3-6일), 😴😴 (7-13일), 💤 (14일+)

**Firestore 스키마:** `users/{uid}/nudges/{nudgeId}`, `users/{uid}/dailyStats/{date}`

---

## 통합 위치 (Integration Points)

### MainMenuScreen (`lib/screens/home/main_menu_screen.dart`)
홈 화면에 모든 소셜 위젯 통합:
1. StreakWidget - 스트릭 현황
2. MorningMannaWidget - 오늘의 구절
3. ActivityTicker - 그룹 활동 피드
4. GroupGoalWidget - 주간 챌린지
5. InactiveMembersWidget - 비활성 멤버 찌르기

### VersePracticeScreen (`lib/screens/practice/verse_practice_screen.dart`)
학습 완료 시 자동 연동:
- 스트릭 기록 (`_recordStreakAndCheckMilestone`)
- 그룹 활동 게시 (`_postActivityAndChallenge`)
- 챌린지 기여도 증가

---

## Barrel Files

### Services
`lib/services/social/social_services.dart`:
```dart
export 'group_activity_service.dart';
export 'group_challenge_service.dart';
export 'streak_service.dart';
export 'morning_manna_service.dart';
export 'nudge_service.dart';
```

### Widgets
`lib/widgets/social/social_widgets.dart`:
```dart
export 'activity_ticker.dart';
export 'group_goal_widget.dart';
export 'streak_widget.dart';
export 'morning_manna_widget.dart';
export 'nudge_widget.dart';
```

---

## 추후 구현 가능 기능 (Future Features)

1. **알림 시스템 (FCM)**
   - 스트릭 위험 알림
   - 찌르기 수신 알림
   - 마일스톤 달성 알림
   - 아침 만나 리마인더

2. **그룹 대시보드**
   - 그룹 통계 (참여율, 암송량)
   - MVP 랭킹
   - 주간 리포트

3. **달란트 샵**
   - 프로필 테두리
   - 특별 이모지 팩
   - 광고 제거

4. **프로필 시스템**
   - 칭호 표시
   - 배지 컬렉션
   - 스트릭 불꽃 효과

---

## 기술 스택

- **Frontend:** Flutter (Dart)
- **Backend:** Firebase (Firestore, Auth, Storage)
- **State Management:** setState (로컬 상태)
- **비용 최적화:**
  - FieldValue.increment/arrayUnion for atomic updates
  - Optimistic UI for instant feedback
  - TTL for automatic cleanup (7 days)
  - Client-side calculations where possible

---

## 빌드 명령어

```bash
# 분석
flutter analyze

# 웹 빌드
powershell -ExecutionPolicy Bypass -File build_web.ps1

# Android APK 빌드
flutter build apk --release

# 웹 배포
firebase deploy --only hosting

# 연결된 기기에서 실행
flutter run
```

---

## Git 커밋 히스토리 (Social UX)

1. `0d0ce32` - docs: Expand Social UX specification
2. `aaaf266` - feat: Implement social activity stream and group challenge system
3. `28a6a1c` - fix: Remove unused shadowColor variable
4. `710dcb7` - feat: Integrate social widgets into main app flow
5. `5e3c14c` - refactor: Simplify Gemini prompt
6. `feafe53` - feat: Implement streak system with milestones and protection
7. `a932d90` - feat: Implement Morning Manna with Early Bird bonus system
8. `240e36b` - feat: Implement Nudge System for encouraging inactive members

---

## 다음 세션에서 참고할 파일들

### 핵심 파일
- `lib/screens/home/main_menu_screen.dart` - 홈 화면 (모든 위젯 통합)
- `lib/screens/practice/verse_practice_screen.dart` - 학습 화면 (스트릭/활동 연동)
- `docs/SOCIAL_UX_SPEC.md` - 상세 기획서

### 서비스
- `lib/services/social/streak_service.dart`
- `lib/services/social/group_activity_service.dart`
- `lib/services/social/group_challenge_service.dart`
- `lib/services/social/morning_manna_service.dart`
- `lib/services/social/nudge_service.dart`

### 모델
- `lib/models/user_streak.dart`
- `lib/models/group_activity.dart`
- `lib/models/daily_verse.dart`
- `lib/models/nudge.dart`
