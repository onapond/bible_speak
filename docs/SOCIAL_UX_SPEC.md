# Bible Speak 소셜 UX 상세 기획서

**Version**: 1.0
**Last Updated**: 2026-01-27
**Author**: CTO Planning

---

## Executive Summary

Bible Speak의 핵심 가치는 **"혼자가 아닌 함께 암송"**입니다.
본 기획서는 사용자들이 매일 앱을 열고, 그룹원들과 서로 독려하며 성경 암송을 지속할 수 있는 소셜 UX 시스템을 정의합니다.

### 핵심 원칙

| 원칙 | 설명 |
|------|------|
| **One Tap = Max Impact** | 한 번의 탭으로 최대의 사회적 효과 |
| **Cost-Efficient Sync** | Firestore 읽기 비용 최소화 |
| **Warm Christianity** | 경쟁보다는 격려, 순위보다는 동행 |
| **Habit Formation** | 21일 습관 형성 이론 적용 |

---

## 1. Daily Engagement System (일일 참여 시스템)

### 1.1 Daily Streak (연속 학습 스트릭)

**목적**: 매일 앱을 여는 습관 형성

```
┌─────────────────────────────────────────────┐
│  🔥 7일 연속 학습 중!                        │
│  ████████████░░░░░░░░  14/21일 목표          │
│                                              │
│  월  화  수  목  금  토  일                  │
│  🔥  🔥  🔥  🔥  🔥  🔥  ⭕                  │
│                        오늘                  │
└─────────────────────────────────────────────┘
```

**Firestore Schema**:
```
users/{uid}/streak
├── currentStreak: 7
├── longestStreak: 14
├── lastLearnedDate: "2026-01-27"
├── streakStartDate: "2026-01-21"
└── weeklyHistory: [true, true, true, true, true, true, false]
```

**비용 최적화**:
- `lastLearnedDate`만 매일 업데이트 (1 write/day)
- 스트릭 계산은 클라이언트에서 수행
- 주간 히스토리는 일주일에 한 번 정리

### 1.2 Morning Manna (아침 만나)

**목적**: 오전 6-8시 골든타임에 앱 진입 유도

```
┌─────────────────────────────────────────────┐
│  ☀️ 오늘의 만나                              │
│                                              │
│  "여호와를 경외하는 것이 지혜의 근본이라"      │
│   - 말라기 1:2                               │
│                                              │
│  [오늘의 구절 암송하기]                       │
└─────────────────────────────────────────────┘
```

**구현 방식**:
- 매일 자정 Cloud Function으로 "오늘의 구절" 선정
- 푸시 알림 (오전 6시, 7시 선택 가능)
- 아침 완료 시 "Early Bird" 보너스 달란트 +1

---

## 2. Group Activity Feed (그룹 활동 피드)

### 2.1 Live Activity Ticker

**목적**: 그룹원들의 실시간 활동을 보여주어 "나도 해야지" 동기 부여

**UI 디자인** (홈 화면 상단):
```
┌─────────────────────────────────────────────┐
│  👥 우리 그룹 소식                           │
│  ─────────────────────────────────────────  │
│  🎉 김성실 님이 말라기 1:5 암송 완료! (2분 전)│
│  🔥 박믿음 님이 7일 연속 학습 달성! (15분 전) │
│  🙏 이소망 님이 에베소서 시작! (1시간 전)    │
└─────────────────────────────────────────────┘
```

**Firestore Schema**:
```
groups/{groupId}/activities/{activityId}
├── type: "verse_complete" | "streak_milestone" | "stage_clear" | "book_start"
├── userId: "user123"
├── userName: "김성실"
├── verseRef: "말라기 1:5" (optional)
├── milestone: 7 (optional, for streak)
├── createdAt: Timestamp
└── reactions: { "pray": ["user456"], "clap": ["user789"] }
```

**비용 최적화 전략**:

1. **Batch Write**: 활동 생성 시 즉시 쓰지 않고 5분마다 배치 처리
2. **TTL (Time To Live)**: 7일 이상 된 활동은 자동 삭제 (Cloud Function)
3. **Pagination**: 최근 20개만 로드, 스크롤 시 추가 로드
4. **Local Cache**: 마지막 조회 시간 저장, 그 이후 데이터만 fetch

```dart
// 비용 효율적인 쿼리
Query<Map<String, dynamic>> getRecentActivities(String groupId, DateTime since) {
  return _firestore
    .collection('groups/$groupId/activities')
    .where('createdAt', isGreaterThan: since)
    .orderBy('createdAt', descending: true)
    .limit(20);
}
```

### 2.2 Activity Types & Icons

| Type | Icon | Message Template |
|------|------|------------------|
| `verse_complete` | 🎉 | `{name}님이 {verse} 암송 완료!` |
| `streak_milestone` | 🔥 | `{name}님이 {n}일 연속 학습!` |
| `stage_clear` | ⭐ | `{name}님이 {verse} Stage 3 통과!` |
| `book_complete` | 📖 | `{name}님이 {book} 완독!` |
| `joined_group` | 👋 | `{name}님이 그룹에 합류!` |
| `prayer_request` | 🙏 | `{name}님의 기도 요청` |

---

## 3. One-Tap Interaction (원탭 인터랙션)

### 3.1 Quick Reactions

**목적**: 최소한의 노력으로 그룹원 격려

**UI**:
```
┌─────────────────────────────────────────────┐
│  🎉 김성실 님이 말라기 1:5 암송 완료!        │
│                                              │
│  [👏 박수]  [🙏 기도]  [💪 화이팅]            │
│     12        5          3                   │
└─────────────────────────────────────────────┘
```

**반응 타입**:
| Reaction | 의미 | 알림 메시지 |
|----------|------|------------|
| 👏 Clap | 축하/격려 | `{name}님이 박수를 보냈어요!` |
| 🙏 Pray | 기도 약속 | `{name}님이 기도해주겠다고 해요!` |
| 💪 Fighting | 응원 | `{name}님이 응원해요!` |

**Firestore 업데이트** (비용 최적화):
```dart
// 배열에 추가 (중복 방지 포함)
await activityRef.update({
  'reactions.clap': FieldValue.arrayUnion([currentUserId]),
});
```

### 3.2 Nudge System (찌르기)

**목적**: 비활성 그룹원 부드럽게 독려

**트리거 조건**:
- 3일 이상 미접속 그룹원
- 그룹 랭킹 화면에서 "찌르기" 버튼 표시

**UI**:
```
┌─────────────────────────────────────────────┐
│  📊 그룹 랭킹                                │
│  ─────────────────────────────────────────  │
│  1. 김성실  🔥14일  ████████ 85%            │
│  2. 박믿음  🔥7일   ██████░░ 62%            │
│  3. 이소망  😴3일전 ████░░░░ 40%  [💌 찌르기]│
└─────────────────────────────────────────────┘
```

**Nudge 메시지 템플릿**:
```
"함께 암송해요! 오늘 말라기 1절 어때요? 🙏"
"보고 싶어요! 잠깐이라도 들러주세요 💕"
"우리 그룹이 기다리고 있어요! 화이팅! 💪"
```

**수신자 화면**:
```
┌─────────────────────────────────────────────┐
│  💌 김성실님이 찌르기!                       │
│                                              │
│  "함께 암송해요! 오늘 말라기 1절 어때요? 🙏"  │
│                                              │
│  [무시]          [암송하러 가기]              │
└─────────────────────────────────────────────┘
```

---

## 4. Collaborative Goal (그룹 목표)

### 4.1 Weekly Group Challenge

**목적**: 그룹 단위 목표 달성으로 공동체 의식 강화

**UI**:
```
┌─────────────────────────────────────────────┐
│  🏛️ 이번 주 그룹 목표: 성전 쌓기             │
│                                              │
│       ⛪                                     │
│      /██\        73% 달성!                  │
│     /████\       ███████████░░░              │
│    /██████\                                  │
│   ──────────     목표: 100 달란트            │
│                  현재: 73 달란트             │
│                                              │
│  이번 주 기여자:                             │
│  김성실 25🌟  박믿음 20🌟  이소망 18🌟  +3명  │
└─────────────────────────────────────────────┘
```

**Firestore Schema**:
```
groups/{groupId}/challenges/{weekId}
├── weekStart: "2026-01-20"
├── weekEnd: "2026-01-26"
├── goalType: "dalants" | "verses" | "streaks"
├── targetValue: 100
├── currentValue: 73
├── contributors: {
│     "user123": 25,
│     "user456": 20,
│     "user789": 18
│   }
├── isCompleted: false
└── reward: { type: "badge", name: "temple_builder_1" }
```

### 4.2 Goal Types

| 목표 타입 | 아이콘 | 설명 | 예시 |
|----------|--------|------|------|
| 달란트 모으기 | 🏛️ | 그룹 총 달란트 | 100달란트 모으기 |
| 구절 암송 | 📜 | 그룹 총 암송 구절 | 50구절 암송하기 |
| 연속 학습 | 🔥 | 모든 멤버 연속 학습 | 전원 7일 스트릭 |
| 책 완독 | 📖 | 특정 책 완독 | 말라기 전체 완독 |

### 4.3 Goal Completion Celebration

목표 달성 시 그룹 전체에 축하 화면:

```
┌─────────────────────────────────────────────┐
│                                              │
│           🎊 축하합니다! 🎊                  │
│                                              │
│        우리 그룹이 이번 주 목표를             │
│           함께 달성했어요!                   │
│                                              │
│              ⛪ 성전 완성! ⛪                 │
│                                              │
│         전원에게 보너스 달란트 +5            │
│                                              │
│  [다음 주 목표 보기]     [공유하기]          │
│                                              │
└─────────────────────────────────────────────┘
```

---

## 5. Notification Strategy (알림 전략)

### 5.1 Push Notification Types

| 유형 | 시간 | 내용 | 우선순위 |
|------|------|------|----------|
| Morning Manna | 06:00-08:00 | 오늘의 구절 | HIGH |
| Streak Reminder | 21:00 | 스트릭 끊길 위험 | HIGH |
| Group Activity | 실시간 | 누가 암송 완료 | LOW |
| Nudge Received | 실시간 | 찌르기 받음 | MEDIUM |
| Goal Progress | 진행률 변화 | 목표 50%/90% 달성 | MEDIUM |
| Weekly Summary | 일요일 18:00 | 주간 리포트 | LOW |

### 5.2 Smart Notification Batching

**비용 절감**: 개별 알림 대신 일괄 알림

```
// 나쁜 예: 매 활동마다 알림 (비용 높음)
onVerseComplete -> sendNotificationToAllMembers()

// 좋은 예: 5분마다 배치 처리
Cloud Function (every 5 min):
  - 최근 5분간 활동 수집
  - 그룹별로 묶어서 1개 알림으로 전송
  - "김성실님 외 2명이 암송을 완료했어요!"
```

---

## 6. Firestore Architecture (비용 최적화)

### 6.1 Collection Structure

```
firestore/
├── users/{uid}
│   ├── profile (name, groupId, etc.)
│   ├── streak (currentStreak, lastLearnedDate)
│   └── notifications/ (unread notifications)
│
├── groups/{groupId}
│   ├── info (name, code, memberCount)
│   ├── members/ (uid -> joinedAt, role)
│   ├── activities/ (최근 7일만 유지)
│   ├── challenges/{weekId}
│   └── stats (totalDalants, weeklyDalants)
│
└── global/
    └── dailyVerse (오늘의 구절)
```

### 6.2 Read Cost Optimization

| 기능 | 최적화 전략 | 예상 reads/day/user |
|------|------------|---------------------|
| Activity Feed | lastFetchTime 이후만 조회 | ~5 |
| Group Stats | 캐시 (5분 TTL) | ~3 |
| Leaderboard | 주 1회 계산, 캐시 | ~1 |
| User Profile | 세션 시작 시 1회 | ~1 |
| **Total** | | **~10 reads/day/user** |

### 6.3 Write Cost Optimization

| 이벤트 | 최적화 전략 | 예상 writes/day/user |
|--------|------------|----------------------|
| Verse Complete | 배치 (5분) | ~2 |
| Streak Update | 1일 1회 | 1 |
| Activity Create | 배치 (5분) | ~2 |
| Reaction | 즉시 (배열 업데이트) | ~3 |
| **Total** | | **~8 writes/day/user** |

---

## 7. Implementation Phases

### Phase 1: Foundation (1주차)
- [ ] Streak 시스템 (Firestore + UI)
- [ ] 기본 Activity Feed 구조
- [ ] 홈 화면 리디자인

### Phase 2: Social Core (2주차)
- [ ] Live Activity Ticker
- [ ] Quick Reactions (👏🙏💪)
- [ ] Nudge 시스템

### Phase 3: Gamification (3주차)
- [ ] Weekly Group Challenge
- [ ] Goal Progress UI
- [ ] Celebration 화면

### Phase 4: Polish (4주차)
- [ ] Push Notification 최적화
- [ ] 배치 처리 Cloud Functions
- [ ] 성능 테스트 & 비용 분석

---

## 8. Success Metrics

| 지표 | 목표 | 측정 방법 |
|------|------|----------|
| DAU/MAU | 40%+ | Firebase Analytics |
| 7일 리텐션 | 50%+ | Cohort Analysis |
| 평균 세션 시간 | 5분+ | Analytics |
| 그룹 참여율 | 70%+ | 그룹 가입 유저 비율 |
| Nudge 응답률 | 30%+ | 찌르기 후 24시간 내 접속 |
| 주간 목표 달성률 | 60%+ | Challenge completion |

---

## 9. UI/UX Mockups Reference

### Home Screen Layout
```
┌─────────────────────────────────────────────┐
│  [≡]  Bible Speak           [🔔] [👤]       │
├─────────────────────────────────────────────┤
│                                              │
│  ☀️ 오늘의 만나                              │
│  "여호와를 경외하는 것이..."                  │
│  [암송하기]                                  │
│                                              │
├─────────────────────────────────────────────┤
│  🔥 7일 연속 학습 중!                        │
│  ████████████░░░░░░░░  14/21일              │
├─────────────────────────────────────────────┤
│  👥 그룹 소식                    [더보기 >]  │
│  🎉 김성실님 말라기 1:5 완료! (2분 전)       │
│  🔥 박믿음님 7일 스트릭! (15분 전)           │
├─────────────────────────────────────────────┤
│  🏛️ 이번 주 그룹 목표                        │
│  성전 쌓기  73/100 달란트  [기여하기]        │
│  ███████████░░░░                            │
├─────────────────────────────────────────────┤
│                                              │
│  [📖 암송하기]        [📊 내 진도]           │
│                                              │
└─────────────────────────────────────────────┘
```

---

## 10. Risk & Mitigation

| 리스크 | 영향 | 대응 방안 |
|--------|------|----------|
| Firestore 비용 폭발 | HIGH | TTL, 배치 처리, 캐시 |
| 알림 피로 | MEDIUM | 스마트 배칭, 사용자 설정 |
| 그룹 비활성화 | MEDIUM | AI 자동 Nudge, 관리자 알림 |
| 경쟁 과열 | LOW | 순위보다 협력 강조 |

---

## Appendix: Key Decisions

### Q: 왜 실시간 리스너 대신 폴링을 사용하나요?
**A**: Firestore 실시간 리스너는 연결 유지 비용이 높습니다.
Activity Feed는 5분마다 새로고침해도 사용자 경험에 큰 영향이 없으므로,
비용 효율성을 위해 "pull-to-refresh + 자동 5분 갱신" 방식을 채택합니다.

### Q: 왜 활동 기록을 7일만 유지하나요?
**A**: 오래된 활동은 참여 동기 부여에 효과가 없습니다.
7일 TTL로 Firestore 저장 비용을 절감하고, 쿼리 성능도 향상됩니다.

### Q: Nudge 남용을 어떻게 방지하나요?
**A**:
- 1인당 하루 3회 Nudge 제한
- 같은 사람에게 24시간 내 1회만 가능
- 수신자가 "조용히" 설정 시 알림 미발송

---

*"혼자 가면 빨리 가고, 함께 가면 멀리 간다."*
