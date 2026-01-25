import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// TTS 서비스
/// - 기본: ESV API 오디오 (성경 구절 전용)
/// - 대안: ElevenLabs API (일반 텍스트용)
/// - 웹/안드로이드 모두 지원
class TTSService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  double _playbackRate = 1.0;

  bool get isPlaying => _isPlaying;
  double get playbackRate => _playbackRate;

  // API 키 (.env에서 로드)
  String get _esvApiKey => dotenv.env['ESV_API_KEY'] ?? '';
  String get _elevenLabsApiKey => dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  // ESV API 설정
  static const String _esvBaseUrl = 'https://api.esv.org/v3/passage/audio/';

  // ElevenLabs 설정 (백업용)
  static const String _elevenLabsVoiceId = '21m00Tcm4TlvDq8ikWAM';
  static const String _elevenLabsModel = 'eleven_multilingual_v2';

  /// 재생 속도 변경 (0.5 ~ 2.0)
  Future<void> setPlaybackRate(double rate) async {
    if (rate < 0.5 || rate > 2.0) return;
    _playbackRate = rate;
    await _audioPlayer.setPlaybackRate(rate);
    print('🎚️ 재생 속도: ${rate}x');
  }

  /// === ESV API 성경 오디오 재생 (권장) ===
  /// 성경 구절을 ESV API에서 MP3로 가져와 재생
  /// 웹/안드로이드 모두 지원
  Future<void> playBibleVerse({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final reference = '$book+$chapter:$verse';
    print('🔊 ESV 오디오 요청: $reference');

    if (_esvApiKey.isEmpty) {
      print('⚠️ ESV API 키가 없습니다. ElevenLabs로 대체합니다.');
      // 대체 로직 필요시 구현
      return;
    }

    try {
      _isPlaying = true;

      // ESV API는 직접 MP3 스트림 URL을 제공
      final audioUrl = '$_esvBaseUrl?q=$reference';

      if (kIsWeb) {
        // 웹: URL 직접 재생
        await _playFromUrlWeb(audioUrl);
      } else {
        // 모바일: 캐싱 후 재생
        await _playFromUrlWithCache(audioUrl, reference);
      }
    } catch (e) {
      print('❌ ESV 오디오 재생 오류: $e');
      _isPlaying = false;
      rethrow;
    }
  }

  /// === URL에서 직접 재생 (웹 최적화) ===
  Future<void> _playFromUrlWeb(String url) async {
    print('🌐 웹 오디오 재생: $url');

    try {
      // ESV API 호출하여 오디오 바이트 가져오기
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Token $_esvApiKey'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        print('✅ 오디오 데이터 수신: ${bytes.length} bytes');

        await _audioPlayer.setPlaybackRate(_playbackRate);
        await _audioPlayer.play(BytesSource(Uint8List.fromList(bytes)));

        // 재생 완료 대기
        await _audioPlayer.onPlayerComplete.first;
        _isPlaying = false;
        print('✅ 웹 재생 완료');
      } else {
        throw Exception('ESV API 오류: ${response.statusCode}');
      }
    } catch (e) {
      _isPlaying = false;
      rethrow;
    }
  }

  /// === URL에서 캐싱 후 재생 (모바일) ===
  Future<void> _playFromUrlWithCache(String url, String cacheKey) async {
    print('📱 모바일 오디오 재생 (캐싱): $url');

    try {
      final cacheFile = await _getCacheFile(cacheKey);

      // 캐시 확인
      if (await cacheFile.exists()) {
        print('✅ 캐시 히트: ${cacheFile.path}');
        await _playFile(cacheFile);
        return;
      }

      // API 호출
      print('⚠️ 캐시 미스 → API 호출');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Token $_esvApiKey'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // 캐시 저장
        await cacheFile.writeAsBytes(response.bodyBytes);
        print('💾 캐시 저장: ${cacheFile.path}');

        await _playFile(cacheFile);
      } else {
        throw Exception('ESV API 오류: ${response.statusCode}');
      }
    } catch (e) {
      _isPlaying = false;
      rethrow;
    }
  }

  /// === 외부 URL 직접 재생 ===
  Future<void> playFromUrl(String url) async {
    print('🔊 URL 재생: $url');

    try {
      _isPlaying = true;
      await _audioPlayer.setPlaybackRate(_playbackRate);
      await _audioPlayer.play(UrlSource(url));

      await _audioPlayer.onPlayerComplete.first;
      _isPlaying = false;
      print('✅ URL 재생 완료');
    } catch (e) {
      print('❌ URL 재생 오류: $e');
      _isPlaying = false;
      rethrow;
    }
  }

  /// === 일반 텍스트 발음 (단어 학습용) ===
  /// ElevenLabs TTS를 사용하여 텍스트 발음
  Future<void> speakText(String text) async {
    await speakWithElevenLabs(text);
  }

  /// === ElevenLabs TTS (일반 텍스트용, 백업) ===
  Future<void> speakWithElevenLabs(String text) async {
    if (_elevenLabsApiKey.isEmpty) {
      print('⚠️ ElevenLabs API 키가 없습니다.');
      return;
    }

    print('🎤 ElevenLabs TTS: ${text.length > 50 ? text.substring(0, 50) + "..." : text}');

    try {
      final audioBytes = await _fetchFromElevenLabs(text);

      if (kIsWeb) {
        await _playBytes(audioBytes);
      } else {
        final cacheFile = await _getCacheFile(text);
        await cacheFile.writeAsBytes(audioBytes);
        await _playFile(cacheFile);
      }
    } catch (e) {
      print('❌ ElevenLabs TTS 오류: $e');
      _isPlaying = false;
      rethrow;
    }
  }

  /// ElevenLabs API 호출
  Future<List<int>> _fetchFromElevenLabs(String text) async {
    final url = 'https://api.elevenlabs.io/v1/text-to-speech/$_elevenLabsVoiceId';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'xi-api-key': _elevenLabsApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': _elevenLabsModel,
        'voice_settings': {
          'stability': 0.8,
          'similarity_boost': 0.8,
        },
      }),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('ElevenLabs API 오류: ${response.statusCode}');
    }
  }

  /// 바이트 데이터 재생 (웹용)
  Future<void> _playBytes(List<int> bytes) async {
    _isPlaying = true;
    await _audioPlayer.setPlaybackRate(_playbackRate);
    await _audioPlayer.play(BytesSource(Uint8List.fromList(bytes)));
    await _audioPlayer.onPlayerComplete.first;
    _isPlaying = false;
  }

  /// 파일 재생 (모바일용)
  Future<void> _playFile(File file) async {
    _isPlaying = true;
    await _audioPlayer.setPlaybackRate(_playbackRate);
    await _audioPlayer.play(DeviceFileSource(file.path));
    await _audioPlayer.onPlayerComplete.first;
    _isPlaying = false;
    print('✅ 파일 재생 완료');
  }

  /// 캐시 파일 경로
  Future<File> _getCacheFile(String key) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/tts_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final hash = md5.convert(utf8.encode(key)).toString();
    return File('${cacheDir.path}/$hash.mp3');
  }

  /// 재생 중지
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    print('⏹️ 재생 중지');
  }

  /// 캐시 삭제
  Future<void> clearCache() async {
    if (kIsWeb) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/tts_cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('🗑️ TTS 캐시 삭제 완료');
      }
    } catch (e) {
      print('❌ 캐시 삭제 오류: $e');
    }
  }

  /// 캐시 크기 조회
  Future<String> getCacheSize() async {
    if (kIsWeb) return '웹: 캐시 미지원';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/tts_cache');

      if (!await cacheDir.exists()) return '0 MB';

      int totalBytes = 0;
      await for (var entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }

      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } catch (e) {
      return '알 수 없음';
    }
  }

  /// 리소스 해제
  void dispose() {
    _audioPlayer.dispose();
  }
}
