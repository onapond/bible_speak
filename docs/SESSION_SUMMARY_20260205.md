# 세션 요약 - 2026년 2월 5일

## 완료된 작업

### Phase 3: Riverpod 아키텍처 마이그레이션 (진행중 - Phase 1-2 + Tier 1 완료)

#### 완료된 작업

**Phase 1: 기반 설정**
- `pubspec.yaml`: flutter_riverpod, riverpod_annotation, riverpod_generator, build_runner 추가
- `lib/main.dart`: ProviderScope 래핑

**Phase 2: Core Providers 구현**
- `lib/providers/core_providers.dart`: Firebase Auth, Firestore, SharedPreferences providers
- `lib/providers/auth_provider.dart`: AuthService provider, AuthNotifier (상태 관리), 편의용 providers
- `lib/providers/progress_provider.dart`: ProgressService provider, ProgressNotifier

**Phase 3 Tier 1: 핵심 화면 마이그레이션 (3개)**
| 파일 | 변경 내용 |
|------|----------|
| `lib/screens/splash_screen.dart` | ConsumerStatefulWidget 변환, ref.read(authServiceProvider) 사용 |
| `lib/screens/home/main_menu_screen.dart` | ConsumerStatefulWidget 변환, ref.watch(currentUserProvider) 사용 |
| `lib/screens/practice/verse_practice_redesigned.dart` | ConsumerStatefulWidget 변환, authService 파라미터 제거 |
| `lib/screens/practice/verse_practice_screen.dart` | ConsumerStatefulWidget 변환, authService 파라미터 제거 |
| `lib/screens/auth/login_screen.dart` | ConsumerStatefulWidget 변환, ref.read(authNotifierProvider.notifier) 사용 |
| `lib/screens/auth/profile_setup_screen.dart` | ConsumerStatefulWidget 변환, authService 파라미터 제거 |
| `lib/screens/admin/screenshot_helper_screen.dart` | authService 파라미터 제거 |

**호출 부분 수정**
- `learning_center_screen.dart`: VersePracticeRedesigned 호출 시 authService 제거
- `practice_setup_screen.dart`: VersePracticeRedesigned 호출 시 authService 제거
- `mypage/my_page_screen.dart`: ScreenshotHelperScreen 호출 시 authService 제거
- `profile/profile_screen.dart`: ScreenshotHelperScreen 호출 시 authService 제거

#### 남은 작업 (Tier 2-3)

**Tier 2 (중요) - 6개 화면** (점진적 마이그레이션 예정)
- LearningCenterScreen, CommunityScreen
- RankingScreen, ShopScreen
- AchievementScreen, MyPageScreen

**Tier 3 (나머지) - 50개 화면** (필요시 점진적 마이그레이션)

#### 사용 방법

```dart
// Provider 읽기 (일회성)
final authService = ref.read(authServiceProvider);
final user = ref.read(currentUserProvider);

// Provider 구독 (반응형)
final user = ref.watch(currentUserProvider);
final talants = ref.watch(userTalantsProvider);

// Notifier 메서드 호출
final authNotifier = ref.read(authNotifierProvider.notifier);
await authNotifier.signInWithGoogle();
await authNotifier.signOut();
```

### Phase 2.8: 나머지 Const 최적화 (완료)

40개 추가 최적화로 최종 18개 warning 달성 (58개 → 18개):

| 파일 | 변경 내용 |
|------|----------|
| `group_service.dart` | GroupCreateResult, GroupJoinResult const 추가 |
| `friend_service.dart` | FriendRequestResult const 추가 (replace_all) |
| `battle_service.dart` | BattleCreateResult const 추가 |
| `shop_service.dart` | PurchaseResult const 추가 |
| `parchment_theme.dart` | BorderSide, BottomNavigationBarThemeData, DividerThemeData const 추가 |
| `parchment_button.dart` | SizedBox const 추가 |
| `verse_memorization_card.dart` | LinearGradient, Text const 추가 |
| `live_activity_ticker.dart` | _PulsingDot const 추가 |
| `streak_widget.dart` | Row const 추가 |
| `reminder_scheduler.dart` | AndroidNotificationDetails const 추가 (replace_all) |
| `bible_offline_service.dart` | StorageInfo const 추가 |

### Phase 2.7: 추가 Const 최적화 (완료)

추가 49개 위치에 `const` 키워드 추가 (107개 → 58개 warning):

| 파일 | 변경 내용 |
|------|----------|
| `verse_practice_screen.dart` | Row, SizedBox, CircularProgressIndicator, Text const 추가 |
| `friend_screen.dart` | Icon, BorderSide, Padding, SizedBox, TextStyle const 추가 (15개+) |
| `community_screen.dart` | Icon, Center, Padding, TextStyle, CircularProgressIndicator const 추가 (20개+) |
| `learning_center_screen.dart` | Divider, BoxDecoration, Border const 추가 |

### Phase 2.6: Const 최적화 (완료)

39개 위치에 `const` 키워드 추가로 빌드 성능 최적화 (146개 → 107개 warning):

| 파일 | 변경 내용 |
|------|----------|
| `lib/screens/shop/shop_screen.dart` | Icon, TextStyle, Center, Column, Divider const 추가 |
| `lib/screens/social/community_screen.dart` | Icon, Text, Center, Column const 추가 |
| `lib/screens/achievement/achievement_screen.dart` | Icon, TextStyle const 추가 |
| `lib/screens/settings/notification_settings_screen.dart` | Icon, TextStyle const 추가 |
| `lib/screens/home/main_menu_screen.dart` | Divider, TextStyle const 추가 |
| `lib/screens/group/group_select_screen.dart` | Icon, Row const 추가 |
| `lib/screens/mypage/my_page_screen.dart` | BoxDecoration, Divider const 추가 |
| `lib/screens/practice/verse_practice_redesigned.dart` | Icon const 추가 |
| `lib/screens/profile/profile_screen.dart` | Row const 추가 |
| `lib/screens/quiz/daily_quiz_screen.dart` | Divider const 추가 |
| `lib/screens/settings/theme_settings_screen.dart` | BoxDecoration, Icon const 추가 |
| `lib/screens/shop/inventory_screen.dart` | Icon, TextStyle const 추가 |
| `lib/screens/settings/offline_download_screen.dart` | TextStyle const 추가 |
| `lib/screens/auth/profile_setup_screen.dart` | Row const 추가 |
| `lib/screens/group/widgets/leaderboard_card.dart` | Row const 추가 |

**성능 이점:**
- 위젯 재빌드 시 불필요한 객체 생성 방지
- 컴파일 타임 최적화로 런타임 성능 향상

### Phase 2.5: Unused Field 제거 (완료)

11개 파일에서 unused field 및 관련 import 제거:

| 파일 | 제거된 필드 |
|------|-------------|
| `lib/screens/achievement/achievement_screen.dart` | `_cardColor` (in _AchievementDetailSheet) |
| `lib/screens/auth/profile_setup_screen.dart` | `_groupService`, GroupService import |
| `lib/screens/practice/verse_practice_redesigned.dart` | `_pronunciationResult`, `_feedback`, `_primaryLight` |
| `lib/screens/shop/shop_screen.dart` | `_authService`, AuthService import |
| `lib/screens/social/friend_screen.dart` | `_cardColor` (in _ChallengeSheetState) |
| `lib/screens/splash_screen.dart` | `fadedScript` |
| `lib/screens/study/learning_center_screen.dart` | `_bgColor`, `_cardColor` (2곳) |
| `lib/screens/ranking/ranking_screen.dart` | `member.odId` → `member.id` 수정 |

**성능 이점:**
- 컴파일 시 dead code 제거로 번들 사이즈 감소
- lint warning 0개 달성 (unused_field)

### Phase 2: ListView 성능 최적화 (완료)

8개 파일에 ListView/GridView 아이템 `ValueKey` 추가로 재렌더링 최적화:

| 파일 | 변경 내용 |
|------|----------|
| `lib/screens/social/friend_screen.dart` | 3곳 수정 |
| - Friends list | `key: ValueKey(friend.odId)` 추가 |
| - Requests list | `key: ValueKey(request.id)` 추가 |
| - Search results | `key: ValueKey(user.odId)` 추가 |
| `lib/screens/achievement/achievement_screen.dart` | 1곳 수정 |
| - Achievement list | `key: ValueKey(userAch.achievementId)` 추가 |
| `lib/screens/word_study/word_list_screen.dart` | 1곳 수정 |
| - Word list | `KeyedSubtree(key: ValueKey(word.id))` 래핑 |
| `lib/screens/social/community_screen.dart` | 5곳 수정 |
| - Chat messages | `key: ValueKey(message.id)` on RepaintBoundary |
| - Friends list | `key: ValueKey(friend.odId)` on RepaintBoundary |
| - Friend requests | `key: ValueKey(request.id)` on RepaintBoundary |
| - Search results | `key: ValueKey(user.odId)` on RepaintBoundary |
| - Browse groups dialog | `KeyedSubtree(key: ValueKey(group.id))` 래핑 |
| `lib/screens/settings/offline_download_screen.dart` | 1곳 수정 |
| - Book list | `KeyedSubtree(key: ValueKey(book.id))` 래핑 |
| `lib/screens/study/practice_setup_screen.dart` | 1곳 수정 |
| - Chapter selector | `KeyedSubtree(key: ValueKey('chapter_$chapter'))` 래핑 |
| `lib/screens/study/learning_center_screen.dart` | 1곳 수정 |
| - Chapter selector | `KeyedSubtree(key: ValueKey('chapter_$chapter'))` 래핑 |
| `lib/screens/group/group_select_screen.dart` | 1곳 수정 |
| - Group list | `KeyedSubtree(key: ValueKey(group.id))` 래핑 |

**성능 이점:**
- Flutter가 리스트 아이템을 효율적으로 식별하여 불필요한 재빌드 방지
- 리스트 스크롤 및 업데이트 시 프레임 드랍 감소
- 메모리 사용량 최적화

### Phase 1: Firestore 안전 패턴 적용 (완료)

13곳의 위험한 `.update()` 패턴을 `.set() + SetOptions(merge: true)` 안전 패턴으로 변경했습니다.

#### 수정된 파일 및 라인

| 파일 | 변경 내용 |
|------|----------|
| `lib/services/auth_service.dart` | 4곳 수정 |
| - Line 423 | 익명 로그인 시 그룹 멤버 수 증가 |
| - Line 471-475 | Google 계정 연결 시 사용자 정보 업데이트 |
| - Line 550 | 계정 삭제 시 그룹 멤버 수 감소 |
| - Line 649 | 달란트 차감 |
| `lib/services/group_service.dart` | 2곳 수정 |
| - Line 209 | `incrementMemberCount()` 함수 |
| - Line 294 | `joinGroup()` 시 사용자 문서 업데이트 |
| `lib/services/progress_service.dart` | 1곳 수정 |
| - Line 476-478 | 챕터 기록 초기화 시 Firestore 삭제 |
| `lib/services/shop_service.dart` | 3곳 수정 |
| - Line 266 | 아이템 비활성화 (batch) |
| - Line 277 | 아이템 활성화 (batch) |
| - Line 310 | 소모품 사용 시 수량 감소 |
| `lib/services/review_service.dart` | 1곳 수정 |
| - Line 116 | 복습 결과 저장 |
| `lib/services/theme_service.dart` | 2곳 수정 |
| - Line 203 | 테마 활성화 (batch) |
| - Line 213 | 테마 비활성화 (batch, resetToDefault) |

### DEVELOPMENT_RULES.md 문서 생성 (완료)

5개 스킬의 규칙을 통합한 개발 규칙 문서를 작성했습니다.

- Firestore 규칙
- Flutter 성능 규칙
- 아키텍처 규칙
- UI/UX 규칙
- 웹 성능 규칙
- 코드 리뷰 체크리스트
- 안티패턴 목록

## 검증 결과

```bash
flutter analyze lib/services/auth_service.dart lib/services/group_service.dart \
  lib/services/progress_service.dart lib/services/shop_service.dart \
  lib/services/review_service.dart lib/services/theme_service.dart
```

- **에러(error)**: 0개
- **경고(warning)**: 0개
- **정보(info)**: 83개 (avoid_print, prefer_const_constructors 등 코드 스타일 권장사항)

## 다음 작업 (TODO)

### Phase 3 계속: Riverpod Tier 2-3 마이그레이션 (선택적)

나머지 화면들은 점진적으로 마이그레이션 가능:
- 새 기능 추가 시 해당 화면 마이그레이션
- 버그 수정 시 해당 화면 마이그레이션
- 기존 StatefulWidget과 ConsumerStatefulWidget 공존 가능

### Phase 4: 테스트 레이어 구축 (중간)

1. Provider 단위 테스트
2. 위젯 테스트

### Phase 5: UI/UX 완성 (낮음)

1. Warm Parchment 테마 100% 적용
2. 접근성 WCAG 2.1 준수
3. 하드코딩 색상 제거

## 중요 참고사항

### Firestore 안전 패턴 규칙

```dart
// ✅ 필수 패턴 (문서/필드 없어도 안전)
await docRef.set({
  'field': FieldValue.increment(1),
}, SetOptions(merge: true));

// ❌ 금지 패턴 (문서 없으면 NOT_FOUND 에러)
await docRef.update({'field': value});
```

### 빌드 명령

웹 빌드 시 반드시 `build_web.ps1` 스크립트 사용 (API 키 주입):

```powershell
powershell -ExecutionPolicy Bypass -File build_web.ps1
```

## 생성된 파일

- `DEVELOPMENT_RULES.md` - 개발 규칙 통합 문서
- `docs/SESSION_SUMMARY_20260205.md` - 이 세션 요약

---

*작성일: 2026년 2월 5일*
