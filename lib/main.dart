import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/bible_data_service.dart';
import 'services/notification/notification_service.dart';
import 'services/notification/notification_handler.dart';
import 'services/notification/notification_types.dart';
import 'services/navigation_service.dart';
import 'services/offline/offline_services.dart';
import 'services/accessibility_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1단계: 필수 초기화 (Firebase) - 앱 실행에 필수
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM 백그라운드 핸들러 등록 (동기, 빠름)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 앱 즉시 실행 - 나머지는 백그라운드에서
  runApp(const BibleSpeakApp());

  // 2단계: 비필수 초기화 백그라운드 실행 (앱 실행 후)
  _initializeInBackground();
}

/// 백그라운드 초기화 (앱 실행 후 비동기)
Future<void> _initializeInBackground() async {
  // 환경 변수 로드 (타임아웃 적용)
  try {
    await dotenv.load(fileName: 'assets/.env').timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint('⚠️ .env 로드 타임아웃 (assets/)');
        throw TimeoutException('.env load timeout');
      },
    );
    debugPrint('✅ .env 로드 성공 (assets/.env)');
  } catch (e) {
    try {
      await dotenv.load(fileName: '.env').timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('⚠️ .env 로드 타임아웃');
          throw TimeoutException('.env load timeout');
        },
      );
      debugPrint('✅ .env 로드 성공 (.env)');
    } catch (e2) {
      debugPrint('❌ .env 로드 실패 (웹에서는 정상): $e2');
    }
  }

  // 서비스 초기화 병렬 실행 (타임아웃 적용)
  try {
    await Future.wait([
      _safeInit('AccessibilityService', AccessibilityService().init(), 2),
      _safeInit('NotificationService', NotificationService().initialize(), 3),
      _safeInit('BibleDataService', BibleDataService.instance.init(), 5),
      _safeInit('OfflineManager', initializeOfflineManager(), 3),
    ]);
  } catch (e) {
    debugPrint('⚠️ 백그라운드 초기화 일부 실패: $e');
  }

  debugPrint('✅ 백그라운드 초기화 완료');
}

/// 안전한 초기화 헬퍼 (타임아웃 + 에러 처리)
Future<void> _safeInit(String name, Future<void> future, int timeoutSeconds) async {
  try {
    await future.timeout(Duration(seconds: timeoutSeconds));
  } catch (e) {
    debugPrint('⚠️ $name 초기화 실패: $e');
  }
}

class BibleSpeakApp extends StatefulWidget {
  const BibleSpeakApp({super.key});

  @override
  State<BibleSpeakApp> createState() => _BibleSpeakAppState();
}

class _BibleSpeakAppState extends State<BibleSpeakApp> {
  final _navigationService = NavigationService();
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    // 알림 탭 이벤트 리스닝
    _notificationSubscription = NotificationHandler.onNotificationTap.listen(_handleNotificationTap);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  /// 알림 탭 처리 - 해당 화면으로 네비게이션
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = NotificationType.fromString(data['type']);
    final navigator = _navigationService.navigator;
    if (navigator == null) return;

    // 잠시 대기 후 네비게이션 (스플래시 완료 보장)
    Future.delayed(const Duration(milliseconds: 500), () {
      switch (type) {
        case NotificationType.morningManna:
          // 메인 메뉴에서 아침 만나 자동 표시됨
          debugPrint('[Navigation] Morning manna notification - go to home');
          break;

        case NotificationType.streakWarning:
          // 스트릭 경고 - 연습 화면으로
          debugPrint('[Navigation] Streak warning - go to practice');
          break;

        case NotificationType.nudgeReceived:
          // 찌르기 수신 - 그룹 화면으로
          final groupId = data['groupId'];
          debugPrint('[Navigation] Nudge received for group: $groupId');
          break;

        case NotificationType.reactionBatch:
          // 리액션 모음 - 활동 피드로
          debugPrint('[Navigation] Reaction batch - go to activity');
          break;

        case NotificationType.weeklySummary:
          // 주간 요약 - 통계 화면으로
          debugPrint('[Navigation] Weekly summary - go to stats');
          break;

        case NotificationType.general:
          // 일반 알림 - 홈으로
          debugPrint('[Navigation] General notification - go to home');
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '바이블 스픽',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
