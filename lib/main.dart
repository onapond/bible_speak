import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/bible_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: '.env');

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // BibleDataService 초기화 (Firestore 연결 확인)
  await BibleDataService.instance.init();

  runApp(const BibleSpeakApp());
}

class BibleSpeakApp extends StatelessWidget {
  const BibleSpeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '바이블 스픽',
      debugShowCheckedModeBanner: false,
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
