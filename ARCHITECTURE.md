# 아키텍처 규칙

> Claude Code가 세션 간 일관된 코딩을 위해 반드시 준수해야 하는 규칙

---

## 1. 상태 관리

### 기본 원칙
- **Riverpod 우선** - 가능하면 `@Riverpod` provider 사용
- **화면에서 직접 서비스 생성 금지** - `final _service = Service()` 금지

### Riverpod 사용 (기본)
```dart
// ✅ 서비스 정의 (providers/에 위치)
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService();

// ✅ 화면에서 사용
class MyScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
  }
}
```

### 싱글톤 허용 케이스
```dart
// ✅ 위젯 트리 외부에서 접근 필요 (FCM 백그라운드 핸들러 등)
class NavigationService {
  static final NavigationService _instance = NavigationService._();
  factory NavigationService() => _instance;
  final navigatorKey = GlobalKey<NavigatorState>();
}

// ✅ 전역 이벤트 스트림
class NotificationHandler {
  static final _controller = StreamController<Map>.broadcast();
  static Stream<Map> get onNotificationTap => _controller.stream;
}

// ✅ 플러그인/네이티브 연동
class HiveService {
  static final HiveService instance = HiveService._();
}
```

### 싱글톤 사용 기준
| 상황 | 패턴 |
|------|------|
| 화면에서 사용하는 서비스 | Riverpod |
| 위젯 트리 외부 접근 필요 | 싱글톤 허용 |
| FCM/Isolate에서 사용 | 싱글톤 허용 |
| GlobalKey 보관 | 싱글톤 허용 |
| 전역 이벤트 스트림 | 싱글톤 허용 |

### 금지 패턴
```dart
// ❌ 화면에서 직접 생성
class MyScreen extends StatelessWidget {
  final _authService = AuthService();  // 금지!
}

// ❌ 불필요한 싱글톤 (Riverpod로 대체 가능한 경우)
class ReviewService {
  static final _instance = ReviewService._();  // Riverpod 사용하세요
}
```

---

## 2. 초기화 순서

### main.dart 필수 순서
```dart
void main() async {
  // 1. Flutter 바인딩
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase 초기화 (필수! 여기서만!)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. FCM 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 4. 앱 실행
  runApp(const ProviderScope(child: BibleSpeakApp()));

  // 5. 백그라운드 초기화 (Firebase 의존 서비스들)
  _initializeInBackground();
}
```

### 절대 금지
- Firebase 초기화를 splash_screen.dart로 이동 금지
- Firebase 초기화 전에 Firestore 접근 금지

---

## 3. 서비스 의존성 그래프

```
Firebase.initializeApp()
│
├── AuthService
│   └── Firestore (users 컬렉션)
│
├── ReviewService
│   └── Firestore (reviews 컬렉션)
│
├── DailyQuizService
│   └── Firestore (quizzes 컬렉션)
│
├── NotificationService
│   └── Firebase Messaging
│
├── BibleOfflineService
│   ├── Hive (로컬 DB)
│   └── Firestore (다운로드 시)
│
└── StatsService
    └── Firestore (stats 컬렉션)
```

---

## 4. 에러 처리

### 필수 규칙
```dart
// ✅ 올바른 에러 처리
try {
  await someOperation();
} catch (e) {
  debugPrint('❌ 작업 실패: $e');
  // 필요시 사용자에게 피드백
  rethrow; // 또는 적절한 처리
}

// ❌ 빈 catch 블록 금지
try {
  await someOperation();
} catch (e) {
  // 아무것도 안 함 - 금지!
}
```

### 사용자 피드백이 필요한 경우
- 네트워크 오류
- 인증 실패
- 데이터 저장 실패

---

## 5. 타입 안전성

### 필수 규칙
```dart
// ✅ 명시적 타입 지정
final String userId = user.id;
final List<Verse> verses = await fetchVerses();

// ❌ dynamic 사용 금지
final dynamic data = response.data;  // 금지!
```

### Future.wait() 결과 처리
```dart
// ✅ 올바른 패턴
final results = await Future.wait<Object?>([
  fetchCount(),      // Future<int>
  fetchStatus(),     // Future<bool>
]);
final count = results[0] as int;
final status = results[1] as bool;

// ❌ 타입 없이 사용 금지
final results = await Future.wait([...]);
final data = results[0];  // dynamic - 금지!
```

---

## 6. Firestore 패턴

### 문서 생성/수정
```dart
// ✅ 권장: set() + merge (문서 없어도 안전)
await docRef.set({
  'field': value,
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

// ❌ 금지: update() (문서 없으면 에러)
await docRef.update({'field': value});
```

### 트랜잭션
```dart
// ✅ 권장: set() with merge in transaction
await _firestore.runTransaction((transaction) async {
  transaction.set(
    docRef,
    {'count': FieldValue.increment(1)},
    SetOptions(merge: true),
  );
});

// ❌ 금지: update() in transaction
transaction.update(docRef, {'count': newCount});
```

---

## 7. 파일 구조

```
lib/
├── main.dart              # 앱 진입점, Firebase 초기화
├── providers/             # Riverpod providers
│   ├── auth_provider.dart
│   └── *_provider.dart
├── services/              # 비즈니스 로직
│   ├── auth_service.dart
│   └── *_service.dart
├── screens/               # UI 화면
├── widgets/               # 재사용 위젯
└── models/                # 데이터 모델
```

---

## 8. PWA / Service Worker

### 업데이트 처리
- `controllerchange` 이벤트에서 무조건 reload 금지
- 세션당 1회만 reload (sessionStorage 플래그 사용)

```javascript
// web/index.html
var hasReloaded = sessionStorage.getItem('sw-reloaded');
navigator.serviceWorker.addEventListener('controllerchange', function() {
  if (!hasReloaded) {
    sessionStorage.setItem('sw-reloaded', 'true');
    window.location.reload();
  }
});
```

---

## 변경 이력
- 2026-02-06: 최초 작성
