import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'audio_loader_stub.dart' if (dart.library.io) 'audio_loader_io.dart'
    as platform;

/// 플랫폼별 오디오 로더
class AudioLoader {
  /// 오디오 파일/URL에서 바이트 데이터 로드
  static Future<Uint8List?> load(String path) async {
    if (kIsWeb) {
      // 웹: Blob URL에서 로드
      try {
        print('🌐 웹: Blob URL에서 오디오 로드 중...');
        final response = await http.get(Uri.parse(path));
        if (response.statusCode == 200) {
          print('🌐 웹: 오디오 로드 완료 (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        }
        print('❌ 웹: 오디오 로드 실패 (${response.statusCode})');
        return null;
      } catch (e) {
        print('❌ 웹 오디오 로드 실패: $e');
        return null;
      }
    } else {
      // 모바일: 파일에서 로드
      return platform.loadAudioFromFile(path);
    }
  }
}
