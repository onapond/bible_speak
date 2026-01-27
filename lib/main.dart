import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/bible_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  try {
    // 웹에서는 assets/ 경로 필요
    await dotenv.load(fileName: 'assets/.env');
    print('✅ .env 로드 성공 (assets/.env)');
  } catch (e) {
    print('⚠️ assets/.env 실패, .env 시도...');
    try {
      await dotenv.load(fileName: '.env');
      print('✅ .env 로드 성공 (.env)');
    } catch (e2) {
      print('❌ .env 로드 실패: $e2');
    }
  }
  print('📌 ESV_API_KEY: ${dotenv.env['ESV_API_KEY']?.substring(0, 10) ?? 'null'}...');
  print('📌 AZURE_SPEECH_KEY: ${dotenv.env['AZURE_SPEECH_KEY']?.substring(0, 10) ?? 'null'}...');

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
