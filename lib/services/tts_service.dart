import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// TTS 서비스 (최적화 버전)
/// - ESV API 오디오 (성경 구절 전용)
/// - 프리로딩 지원 (다음 구절 미리 로드)
/// - 캐시 만료 관리 (30일)
/// - 재시도 로직
/// - 캐시 크기 제한 (100MB)
class TTSService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  double _playbackRate = 1.0;
  bool _isPreloading = false;

  // 프리로드 큐
  final Map<String, Completer<String?>> _preloadQueue = {};

  // 캐시 설정
  static const int _maxCacheSizeMB = 100;
  static const int _cacheExpirationDays = 30;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  bool get isPlaying => _isPlaying;
  double get playbackRate => _playbackRate;

  // API 키
  String get _esvApiKey => dotenv.env['ESV_API_KEY'] ?? '';
  String get _elevenLabsApiKey => dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  // ESV API 설정
  static const String _esvBaseUrl = 'https://api.esv.org/v3/passage/audio/';

  // ElevenLabs 설정
  static const String _elevenLabsVoiceId = '21m00Tcm4TlvDq8ikWAM';
  static const String _elevenLabsModel = 'eleven_multilingual_v2';

  /// 재생 속도 변경 (0.5 ~ 2.0)
  Future<void> setPlaybackRate(double rate) async {
    if (rate < 0.5 || rate > 2.0) return;
    _playbackRate = rate;
    await _audioPlayer.setPlaybackRate(rate);
  }

  /// 성경 구절 오디오 재생
  Future<void> playBibleVerse({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final reference = '$book+$chapter:$verse';

    if (_esvApiKey.isEmpty) {
      throw Exception('ESV API 키가 설정되지 않았습니다.');
    }

    try {
      _isPlaying = true;
      final audioUrl = '$_esvBaseUrl?q=$reference';

      if (kIsWeb) {
        await _playFromUrlWeb(audioUrl);
      } else {
        await _playFromUrlWithCache(audioUrl, reference);
      }
    } catch (e) {
      _isPlaying = false;
      rethrow;
    }
  }

  /// 다음 구절 프리로드 (백그라운드)
  Future<void> preloadNextVerse({
    required String book,
    required int chapter,
    required int verse,
    required int totalVerses,
  }) async {
    if (_isPreloading || kIsWeb) return;

    // 다음 구절 계산
    final nextVerse = verse < totalVerses ? verse + 1 : null;
    if (nextVerse == null) return;

    final reference = '$book+$chapter:$nextVerse';
    final cacheKey = reference;

    // 이미 캐시되어 있거나 프리로드 중이면 스킵
    if (_preloadQueue.containsKey(cacheKey)) return;

    final cacheFile = await _getCacheFile(cacheKey);
    if (await cacheFile.exists()) return;

    _isPreloading = true;
    final completer = Completer<String?>();
    _preloadQueue[cacheKey] = completer;

    try {
      final audioUrl = '$_esvBaseUrl?q=$reference';
      await _downloadAndCache(audioUrl, cacheKey);
      completer.complete(cacheFile.path);
    } catch (e) {
      completer.complete(null);
    } finally {
      _isPreloading = false;
      _preloadQueue.remove(cacheKey);
    }
  }

  /// 여러 구절 일괄 프리로드
  Future<void> preloadVerses({
    required String book,
    required int chapter,
    required int startVerse,
    required int count,
    required int totalVerses,
  }) async {
    if (kIsWeb) return;

    for (int i = 0; i < count && startVerse + i <= totalVerses; i++) {
      final verse = startVerse + i;
      final reference = '$book+$chapter:$verse';
      final cacheFile = await _getCacheFile(reference);

      if (!await cacheFile.exists()) {
        final audioUrl = '$_esvBaseUrl?q=$reference';
        try {
          await _downloadAndCache(audioUrl, reference);
        } catch (e) {
          // 프리로드 실패는 무시
        }
      }
    }
  }

  /// URL에서 다운로드 후 캐시 (재시도 포함)
  Future<void> _downloadAndCache(String url, String cacheKey) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Token $_esvApiKey'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final cacheFile = await _getCacheFile(cacheKey);
          await cacheFile.writeAsBytes(response.bodyBytes);
          return;
        } else if (response.statusCode >= 500) {
          // 서버 오류면 재시도
          lastException = Exception('서버 오류: ${response.statusCode}');
          if (attempt < _maxRetries) {
            await Future.delayed(_retryDelay * attempt);
            continue;
          }
        } else {
          throw Exception('ESV API 오류: ${response.statusCode}');
        }
      } on TimeoutException {
        lastException = Exception('요청 시간 초과');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      } on SocketException catch (e) {
        lastException = Exception('네트워크 오류: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      } catch (e) {
        lastException = Exception('다운로드 오류: $e');
        break;
      }
    }

    throw lastException ?? Exception('알 수 없는 오류');
  }

  /// 웹 오디오 재생
  Future<void> _playFromUrlWeb(String url) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Token $_esvApiKey'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          await _audioPlayer.setPlaybackRate(_playbackRate);
          await _audioPlayer.play(BytesSource(Uint8List.fromList(bytes)));
          await _audioPlayer.onPlayerComplete.first;
          _isPlaying = false;
          return;
        } else if (response.statusCode >= 500 && attempt < _maxRetries) {
          lastException = Exception('서버 오류: ${response.statusCode}');
          await Future.delayed(_retryDelay * attempt);
          continue;
        } else {
          throw Exception('ESV API 오류: ${response.statusCode}');
        }
      } on TimeoutException {
        lastException = Exception('요청 시간 초과');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      } catch (e) {
        lastException = Exception('재생 오류: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      }
    }

    _isPlaying = false;
    throw lastException ?? Exception('알 수 없는 오류');
  }

  /// 모바일 캐싱 재생
  Future<void> _playFromUrlWithCache(String url, String cacheKey) async {
    try {
      final cacheFile = await _getCacheFile(cacheKey);

      // 캐시 확인 (만료 체크 포함)
      if (await cacheFile.exists()) {
        final stat = await cacheFile.stat();
        final age = DateTime.now().difference(stat.modified);

        if (age.inDays < _cacheExpirationDays) {
          await _playFile(cacheFile);
          return;
        } else {
          // 만료된 캐시 삭제
          await cacheFile.delete();
        }
      }

      // 다운로드 및 캐시
      await _downloadAndCache(url, cacheKey);

      // 캐시 크기 체크 (비동기로 정리)
      _checkCacheSize();

      await _playFile(cacheFile);
    } catch (e) {
      _isPlaying = false;
      rethrow;
    }
  }

  /// 일반 텍스트 TTS (단어 학습용)
  Future<void> speakText(String text) async {
    await speakWithElevenLabs(text);
  }

  /// ElevenLabs TTS
  Future<void> speakWithElevenLabs(String text) async {
    if (_elevenLabsApiKey.isEmpty) {
      throw Exception('ElevenLabs API 키가 설정되지 않았습니다.');
    }

    try {
      final audioBytes = await _fetchFromElevenLabs(text);

      if (kIsWeb) {
        await _playBytes(audioBytes);
      } else {
        final cacheFile = await _getCacheFile('el_$text');
        await cacheFile.writeAsBytes(audioBytes);
        await _playFile(cacheFile);
      }
    } catch (e) {
      _isPlaying = false;
      rethrow;
    }
  }

  /// ElevenLabs API 호출 (재시도 포함)
  Future<List<int>> _fetchFromElevenLabs(String text) async {
    final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_elevenLabsVoiceId');
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.post(
          url,
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
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else if (response.statusCode >= 500 && attempt < _maxRetries) {
          lastException = Exception('서버 오류: ${response.statusCode}');
          await Future.delayed(_retryDelay * attempt);
          continue;
        } else {
          throw Exception('ElevenLabs API 오류: ${response.statusCode}');
        }
      } on TimeoutException {
        lastException = Exception('요청 시간 초과');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      } catch (e) {
        lastException = Exception('ElevenLabs 오류: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      }
    }

    throw lastException ?? Exception('알 수 없는 오류');
  }

  /// 바이트 재생
  Future<void> _playBytes(List<int> bytes) async {
    _isPlaying = true;
    await _audioPlayer.setPlaybackRate(_playbackRate);
    await _audioPlayer.play(BytesSource(Uint8List.fromList(bytes)));
    await _audioPlayer.onPlayerComplete.first;
    _isPlaying = false;
  }

  /// 파일 재생
  Future<void> _playFile(File file) async {
    _isPlaying = true;
    await _audioPlayer.setPlaybackRate(_playbackRate);
    await _audioPlayer.play(DeviceFileSource(file.path));
    await _audioPlayer.onPlayerComplete.first;
    _isPlaying = false;
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

  /// 캐시 크기 체크 및 정리 (백그라운드)
  void _checkCacheSize() {
    _cleanupCacheIfNeeded().catchError((_) {});
  }

  Future<void> _cleanupCacheIfNeeded() async {
    if (kIsWeb) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/tts_cache');

      if (!await cacheDir.exists()) return;

      // 캐시 크기 계산
      int totalBytes = 0;
      final files = <MapEntry<File, DateTime>>[];

      await for (var entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalBytes += stat.size;
          files.add(MapEntry(entity, stat.modified));
        }
      }

      final totalMB = totalBytes / (1024 * 1024);

      // 100MB 초과 시 오래된 파일부터 삭제
      if (totalMB > _maxCacheSizeMB) {
        // 오래된 순 정렬
        files.sort((a, b) => a.value.compareTo(b.value));

        int deletedBytes = 0;
        final targetDelete = totalBytes - (_maxCacheSizeMB * 1024 * 1024 * 0.8).toInt();

        for (final entry in files) {
          if (deletedBytes >= targetDelete) break;

          final stat = await entry.key.stat();
          deletedBytes += stat.size;
          await entry.key.delete();
        }
      }
    } catch (e) {
      // 캐시 정리 실패는 무시
    }
  }

  /// 재생 중지
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
  }

  /// 캐시 삭제
  Future<void> clearCache() async {
    if (kIsWeb) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/tts_cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // 무시
    }
  }

  /// 만료된 캐시만 삭제
  Future<int> clearExpiredCache() async {
    if (kIsWeb) return 0;

    int deletedCount = 0;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/tts_cache');

      if (!await cacheDir.exists()) return 0;

      await for (var entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = DateTime.now().difference(stat.modified);

          if (age.inDays > _cacheExpirationDays) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
    } catch (e) {
      // 무시
    }

    return deletedCount;
  }

  /// 캐시 크기 조회
  Future<String> getCacheSize() async {
    if (kIsWeb) return '웹: 캐시 미지원';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/tts_cache');

      if (!await cacheDir.exists()) return '0 MB';

      int totalBytes = 0;
      int fileCount = 0;

      await for (var entity in cacheDir.list()) {
        if (entity is File) {
          totalBytes += await entity.length();
          fileCount++;
        }
      }

      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB ($fileCount 파일)';
    } catch (e) {
      return '알 수 없음';
    }
  }

  /// 특정 구절이 캐시되어 있는지 확인
  Future<bool> isVerseCached({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    if (kIsWeb) return false;

    final reference = '$book+$chapter:$verse';
    final cacheFile = await _getCacheFile(reference);
    return cacheFile.exists();
  }

  /// URL 직접 재생
  Future<void> playFromUrl(String url) async {
    try {
      _isPlaying = true;
      await _audioPlayer.setPlaybackRate(_playbackRate);
      await _audioPlayer.play(UrlSource(url));
      await _audioPlayer.onPlayerComplete.first;
      _isPlaying = false;
    } catch (e) {
      _isPlaying = false;
      rethrow;
    }
  }

  /// 리소스 해제
  void dispose() {
    _audioPlayer.dispose();
  }
}
