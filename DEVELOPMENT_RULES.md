# Bible Speak 개발 규칙

> 5개 스킬(Firebase Firestore, Flutter Expert, Flutter Architecture, UI/UX Pro Max, Web Performance)의 규칙을 통합한 프로젝트 개발 가이드

---

## 목차

1. [Firestore 규칙](#1-firestore-규칙)
2. [Flutter 성능 규칙](#2-flutter-성능-규칙)
3. [아키텍처 규칙](#3-아키텍처-규칙)
4. [UI/UX 규칙](#4-uiux-규칙)
5. [웹 성능 규칙](#5-웹-성능-규칙)
6. [코드 리뷰 체크리스트](#6-코드-리뷰-체크리스트)
7. [안티패턴 목록](#7-안티패턴-목록)

---

## 1. Firestore 규칙

### 1.1 필수: set() + merge 패턴

문서/필드가 없어도 안전하게 동작하는 패턴을 사용합니다.

```dart
// ✅ 권장: set() + SetOptions(merge: true)
await docRef.set({
  'field': value,
  'count': FieldValue.increment(1),
}, SetOptions(merge: true));

// ❌ 금지: update() 직접 사용
// 문서가 없으면 실패 (NOT_FOUND)
await docRef.update({'field': value});
```

### 1.2 트랜잭션 내 안전 패턴

```dart
// ✅ 트랜잭션에서도 set + merge 사용
await _firestore.runTransaction((transaction) async {
  final docRef = _firestore.collection('users').doc(userId);

  // 읽기
  final snapshot = await transaction.get(docRef);

  // 쓰기 (set + merge)
  transaction.set(docRef, {
    'talants': FieldValue.increment(amount),
  }, SetOptions(merge: true));
});
```

### 1.3 배치 작업 안전 패턴

```dart
// ✅ batch에서도 set + merge 사용
final batch = _firestore.batch();

for (final doc in documents) {
  batch.set(doc.reference, {
    'isActive': false,
  }, SetOptions(merge: true));
}

await batch.commit();
```

### 1.4 실시간 구독 관리

```dart
// ✅ StreamSubscription 관리
StreamSubscription? _subscription;

void startListening() {
  _subscription?.cancel(); // 기존 구독 취소
  _subscription = _firestore
      .collection('data')
      .snapshots()
      .listen((snapshot) { ... });
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

### 1.5 오프라인 지원

```dart
// ✅ 오프라인 에러 처리
try {
  await docRef.set(data, SetOptions(merge: true));
} catch (e) {
  // 오프라인 시 로컬에 저장
  await _saveToLocal(data);
}
```

---

## 2. Flutter 성능 규칙

### 2.1 ListView Key 필수

리스트 아이템에는 반드시 고유 Key를 제공합니다.

```dart
// ✅ ValueKey 사용
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return Card(
      key: ValueKey(item.id), // 필수!
      child: ListTile(title: Text(item.name)),
    );
  },
);

// ❌ Key 없음
ListView.builder(
  itemBuilder: (context, index) {
    return Card(child: ...); // Key 없으면 재사용 비효율
  },
);
```

### 2.2 const 생성자 활용

변하지 않는 위젯은 const로 선언합니다.

```dart
// ✅ const 사용
const SizedBox(height: 16);
const EdgeInsets.all(16);
const Text('고정 텍스트');

// ❌ const 미사용
SizedBox(height: 16); // 매번 새 인스턴스 생성
```

### 2.3 build() 내 객체 생성 금지

```dart
// ❌ build() 내 객체 생성
@override
Widget build(BuildContext context) {
  final decoration = BoxDecoration(...); // 매번 생성됨
  return Container(decoration: decoration);
}

// ✅ static final 또는 const 사용
static final _decoration = BoxDecoration(...);

@override
Widget build(BuildContext context) {
  return Container(decoration: _decoration);
}
```

### 2.4 RepaintBoundary 사용

독립적으로 업데이트되는 위젯을 분리합니다.

```dart
// ✅ 애니메이션 위젯 분리
RepaintBoundary(
  child: AnimatedWidget(...),
)
```

### 2.5 이미지 캐싱

```dart
// ✅ CachedNetworkImage 사용
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => const ShimmerLoading(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
);

// ❌ Image.network 직접 사용
Image.network(url); // 캐싱 없음
```

### 2.6 비동기 데이터 로딩

```dart
// ✅ FutureBuilder/StreamBuilder 사용
FutureBuilder<List<Item>>(
  future: _loadItems(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const ShimmerLoading();
    }
    if (snapshot.hasError) {
      return ErrorWidget(snapshot.error.toString());
    }
    return ItemList(items: snapshot.data!);
  },
);
```

---

## 3. 아키텍처 규칙

### 3.1 폴더 구조 (Feature-First)

```
lib/
├── main.dart
├── models/          # 데이터 모델
├── services/        # 비즈니스 로직 + Firestore 접근
├── screens/         # UI 화면 (Feature별 폴더)
│   ├── home/
│   ├── study/
│   ├── ranking/
│   └── settings/
├── widgets/         # 재사용 위젯
│   ├── common/
│   └── [feature]/
├── utils/           # 유틸리티 함수
└── config/          # 설정, 상수
```

### 3.2 Service 레이어 규칙

```dart
// ✅ Service는 단일 책임
class AuthService {
  // 인증 관련만 담당
}

class GroupService {
  // 그룹 관련만 담당
}

// ❌ God Service
class AppService {
  // 모든 것을 담당 (안티패턴)
}
```

### 3.3 Model 규칙

```dart
// ✅ immutable + fromFirestore/toFirestore
class UserModel {
  final String uid;
  final String name;
  final int talants;

  const UserModel({
    required this.uid,
    required this.name,
    required this.talants,
  });

  factory UserModel.fromFirestore(String id, Map<String, dynamic> data) {
    return UserModel(
      uid: id,
      name: data['name'] ?? '',
      talants: data['talants'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'talants': talants,
  };

  UserModel copyWith({String? name, int? talants}) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      talants: talants ?? this.talants,
    );
  }
}
```

### 3.4 화면 구조

```dart
// ✅ 화면은 얇게, 로직은 Service로
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: GroupService().getGroups(),
      builder: (context, snapshot) {
        // UI만 담당
      },
    );
  }
}
```

---

## 4. UI/UX 규칙

### 4.1 Warm Parchment 테마 사용

하드코딩 색상 대신 테마 색상을 사용합니다.

```dart
// ✅ 테마 색상 사용
color: ParchmentTheme.manuscriptGold
color: ParchmentTheme.agedPaper
color: ParchmentTheme.warmBrown

// ❌ 하드코딩 금지
color: Color(0xFFC9A857)
color: Colors.brown
```

### 4.2 터치 타겟 크기

최소 44x44px을 보장합니다.

```dart
// ✅ 충분한 터치 영역
InkWell(
  child: Padding(
    padding: const EdgeInsets.all(12), // 최소 터치 영역 확보
    child: Icon(Icons.menu, size: 24),
  ),
  onTap: () {},
);

// ❌ 작은 터치 영역
InkWell(
  child: Icon(Icons.menu, size: 16), // 터치하기 어려움
  onTap: () {},
);
```

### 4.3 대비율 4.5:1 이상

텍스트와 배경의 대비율을 확보합니다.

```dart
// ✅ 충분한 대비
Text(
  '제목',
  style: TextStyle(
    color: ParchmentTheme.inkBlack, // #2D2A26
    // 배경: ParchmentTheme.agedPaper (#F5F0E6)
    // 대비율: 약 10:1
  ),
);
```

### 4.4 로딩 상태 표시

```dart
// ✅ Shimmer 로딩
if (isLoading) {
  return const ShimmerLoading();
}

// ✅ 진행 표시
CircularProgressIndicator(
  value: progress, // 0.0 ~ 1.0
  strokeWidth: 3,
);
```

### 4.5 에러 상태 처리

```dart
// ✅ 친절한 에러 메시지
if (hasError) {
  return Column(
    children: [
      const Icon(Icons.error_outline, size: 48),
      const SizedBox(height: 16),
      const Text('데이터를 불러올 수 없습니다'),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: onRetry,
        child: const Text('다시 시도'),
      ),
    ],
  );
}
```

### 4.6 Semantics 라벨

스크린 리더를 위한 접근성 라벨을 제공합니다.

```dart
// ✅ Semantics 라벨
Semantics(
  label: '랭킹 1위, 홍길동, 150 달란트',
  child: RankingCard(...),
);

IconButton(
  icon: const Icon(Icons.share),
  tooltip: '공유하기', // 접근성 라벨 역할
  onPressed: onShare,
);
```

---

## 5. 웹 성능 규칙

### 5.1 Core Web Vitals 목표

| 지표 | 목표 | 설명 |
|------|------|------|
| LCP | < 2.5s | Largest Contentful Paint |
| FID | < 100ms | First Input Delay |
| CLS | < 0.1 | Cumulative Layout Shift |
| TTFB | < 600ms | Time to First Byte |

### 5.2 이미지 최적화

```dart
// ✅ WebP 포맷 + 적절한 크기
CachedNetworkImage(
  imageUrl: 'https://example.com/image.webp',
  width: 200,
  height: 200,
  fit: BoxFit.cover,
);
```

### 5.3 Lazy Loading

```dart
// ✅ 화면에 보일 때만 로드
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    // 자동으로 lazy loading
    return ItemCard(item: items[index]);
  },
);
```

### 5.4 번들 크기 최적화

```yaml
# pubspec.yaml - 사용하지 않는 패키지 제거
dependencies:
  flutter:
    sdk: flutter
  # 필수 패키지만 유지
```

### 5.5 PWA 캐싱 전략

```javascript
// service-worker.js
// 정적 자산: Cache First
// API 요청: Network First with Cache Fallback
```

---

## 6. 코드 리뷰 체크리스트

### Firestore

- [ ] `update()` 대신 `set() + merge` 사용
- [ ] 트랜잭션 내 읽기 후 쓰기 순서 확인
- [ ] StreamSubscription 정리 (dispose에서 cancel)
- [ ] 오프라인 에러 처리

### Flutter 성능

- [ ] ListView 아이템에 Key 제공
- [ ] const 생성자 사용 가능한 곳 확인
- [ ] build() 내 객체 생성 없음
- [ ] 이미지 캐싱 (CachedNetworkImage)

### UI/UX

- [ ] 하드코딩 색상 없음 (테마 사용)
- [ ] 터치 타겟 44x44px 이상
- [ ] 로딩/에러 상태 처리
- [ ] 접근성 라벨 (Semantics, tooltip)

### 아키텍처

- [ ] Service 단일 책임 준수
- [ ] Model immutable + copyWith
- [ ] 화면에 비즈니스 로직 없음

---

## 7. 안티패턴 목록

### 7.1 Firestore 안티패턴

| 안티패턴 | 문제 | 해결책 |
|----------|------|--------|
| `docRef.update()` | 문서 없으면 실패 | `set() + merge` |
| 트랜잭션 내 `await` 없이 읽기 | 일관성 없는 데이터 | `await transaction.get()` |
| 구독 정리 안 함 | 메모리 누수 | `dispose`에서 `cancel()` |

### 7.2 Flutter 안티패턴

| 안티패턴 | 문제 | 해결책 |
|----------|------|--------|
| ListView에 Key 없음 | 비효율적 재사용 | `ValueKey(item.id)` |
| build() 내 객체 생성 | 불필요한 할당 | `static final` 또는 `const` |
| setState 남용 | 과도한 리빌드 | 필요한 부분만 업데이트 |
| Image.network 직접 사용 | 캐싱 없음 | `CachedNetworkImage` |

### 7.3 UI/UX 안티패턴

| 안티패턴 | 문제 | 해결책 |
|----------|------|--------|
| 하드코딩 색상 | 테마 불일치 | `ParchmentTheme.xxx` |
| 작은 터치 영역 | 접근성 문제 | 최소 44x44px |
| 로딩 상태 없음 | UX 혼란 | Shimmer 또는 Progress |
| 에러 상태 무시 | 사용자 혼란 | 친절한 에러 메시지 |

### 7.4 아키텍처 안티패턴

| 안티패턴 | 문제 | 해결책 |
|----------|------|--------|
| God Service | 유지보수 어려움 | 단일 책임 분리 |
| 화면에 비즈니스 로직 | 테스트 어려움 | Service로 분리 |
| 전역 상태 남용 | 예측 불가 | 명확한 상태 관리 |

---

## 참고 자료

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [Web Vitals](https://web.dev/vitals/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

---

*최종 업데이트: 2026년 2월 5일*
