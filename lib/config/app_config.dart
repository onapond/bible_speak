import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 앱 설정 (웹/모바일 통합)
///
/// 웹 빌드 시 환경변수 주입:
/// flutter build web --dart-define=ESV_API_KEY=xxx --dart-define=AZURE_SPEECH_KEY=xxx ...
///
/// 또는 build_web.sh 스크립트 사용
class AppConfig {
  // 빌드 시 주입되는 환경변수 (--dart-define)
  static const String _envEsvApiKey = String.fromEnvironment('ESV_API_KEY');
  static const String _envGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envElevenLabsApiKey = String.fromEnvironment('ELEVENLABS_API_KEY');
  static const String _envAzureSpeechKey = String.fromEnvironment('AZURE_SPEECH_KEY');
  static const String _envAzureSpeechRegion = String.fromEnvironment('AZURE_SPEECH_REGION', defaultValue: 'koreacentral');

  // 웹 오디오 프록시 URL (Cloudflare Worker)
  static const String _webAudioProxyUrl = 'https://bible-speak-proxy.tlsdygksdev.workers.dev';

  /// 웹에서 ESV 오디오 프록시 URL
  static String getEsvAudioUrl(String reference) {
    if (kIsWeb) {
      return '$_webAudioProxyUrl/esv-audio?q=${Uri.encodeComponent(reference)}';
    }
    return 'https://api.esv.org/v3/passage/audio/?q=${Uri.encodeComponent(reference)}';
  }

  static String get esvApiKey {
    if (kIsWeb) {
      return _envEsvApiKey;
    }
    return dotenv.env['ESV_API_KEY'] ?? '';
  }

  static String get geminiApiKey {
    if (kIsWeb) {
      return _envGeminiApiKey;
    }
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static String get elevenLabsApiKey {
    if (kIsWeb) {
      return _envElevenLabsApiKey;
    }
    return dotenv.env['ELEVENLABS_API_KEY'] ?? '';
  }

  static String get azureSpeechKey {
    if (kIsWeb) {
      return _envAzureSpeechKey;
    }
    return dotenv.env['AZURE_SPEECH_KEY'] ?? '';
  }

  static String get azureSpeechRegion {
    if (kIsWeb) {
      return _envAzureSpeechRegion.isNotEmpty ? _envAzureSpeechRegion : 'koreacentral';
    }
    return dotenv.env['AZURE_SPEECH_REGION'] ?? 'koreacentral';
  }
}
