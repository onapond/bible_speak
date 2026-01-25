import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// STT 서비스 (Speech-to-Text)
/// - ElevenLabs Scribe API 사용
/// - 웹에서는 제한됨 (파일 시스템 접근 불가)
class STTService {
  static const String _apiKey =
      'a37eb906f7735ff06fe51303dce546cd36866f40e59be609a8686a13f2b6b1e5';
  static const String _baseUrl = 'https://api.elevenlabs.io/v1/speech-to-text';

  /// 오디오 파일을 텍스트로 변환
  Future<STTResult> transcribeAudio({
    required String audioFilePath,
    String? languageCode, // null = 자동 감지, 'en' = 영어
  }) async {
    // 웹 환경 체크
    if (kIsWeb) {
      print('⚠️ 웹에서는 STT가 제한됩니다.');
      return STTResult.error('웹에서는 음성 인식이 제한됩니다.');
    }

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🎤 STT 요청 시작');
    print('📁 파일: $audioFilePath');
    print('🌐 언어: ${languageCode ?? "자동 감지"}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    try {
      final file = File(audioFilePath);
      if (!await file.exists()) {
        return STTResult.error('오디오 파일을 찾을 수 없습니다.');
      }

      final fileSize = await file.length();
      print('📊 파일 크기: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Multipart 요청
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      request.headers['xi-api-key'] = _apiKey;
      request.fields['model_id'] = 'scribe_v1';

      if (languageCode != null && languageCode.isNotEmpty) {
        request.fields['language_code'] = languageCode;
      }

      request.files.add(await http.MultipartFile.fromPath('file', audioFilePath));

      print('📡 API 호출 중...');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final text = jsonResponse['text'] ?? '';
        final detectedLang = jsonResponse['language_code'] ?? 'unknown';

        print('✅ STT 성공!');
        print('📝 인식된 텍스트: "$text"');
        print('🌐 감지된 언어: $detectedLang\n');

        return STTResult.success(text: text, languageCode: detectedLang);
      } else {
        print('❌ STT 실패: ${response.statusCode}');
        _printErrorGuide(response.statusCode);

        String errorMsg = 'API 오류: ${response.statusCode}';
        try {
          final errorJson = json.decode(response.body);
          if (errorJson['detail'] != null) {
            errorMsg = errorJson['detail']['message'] ?? errorJson['detail'].toString();
          }
        } catch (_) {}

        return STTResult.error(errorMsg);
      }
    } catch (e) {
      print('❌ 예외 발생: $e');
      return STTResult.error('네트워크 오류: $e');
    }
  }

  void _printErrorGuide(int statusCode) {
    switch (statusCode) {
      case 401:
        print('💡 401: API 키 권한 확인 필요');
        break;
      case 429:
        print('💡 429: 무료 한도 초과');
        break;
      case 422:
        print('💡 422: 오디오 파일 형식 확인 (wav, mp3, aac 지원)');
        break;
    }
  }
}

/// STT 결과 클래스
class STTResult {
  final bool isSuccess;
  final String? text;
  final String? languageCode;
  final String? errorMessage;

  STTResult._({
    required this.isSuccess,
    this.text,
    this.languageCode,
    this.errorMessage,
  });

  factory STTResult.success({required String text, required String languageCode}) {
    return STTResult._(isSuccess: true, text: text, languageCode: languageCode);
  }

  factory STTResult.error(String message) {
    return STTResult._(isSuccess: false, errorMessage: message);
  }
}
