import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../bible_data_service.dart';

/// 오디오 소스 타입
enum AudioSourceType {
  firebaseStorage, // Firebase Storage에 저장된 ESV 오디오
  esvApi, // ESV API 직접 스트리밍
  local, // 로컬 캐시
}

/// 오디오 재생 상태
enum AudioPlaybackState {
  idle,
  loading,
  playing,
  paused,
  stopped,
  error,
}

/// 하이브리드 성경 오디오 서비스
/// - Firebase Storage 우선 (고품질 오프라인 지원)
/// - ESV API 폴백 (실시간 스트리밍)
/// - 로컬 캐시 (30일 만료, 100MB 제한)
class BibleAudioService {
  static BibleAudioService? _instance;
  static BibleAudioService get instance => _instance ??= BibleAudioService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 상태
  AudioPlaybackState _state = AudioPlaybackState.idle;
  double _playbackRate = 1.0;
  String? _currentVerse;

  // 캐시 설정
  static const int _maxCacheSizeMB = 100;
  static const int _cacheExpirationDays = 30;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  // API 키
  String get _esvApiKey => dotenv.env['ESV_API_KEY'] ?? '';

  // Firebase Storage 경로 패턴
  // bible_audio/{bookId}/{chapter}/{verse}.mp3
  String _getStoragePath(String bookId, int chapter, int verse) =>
      'bible_audio/$bookId/$chapter/$verse.mp3';

  // 전체 챕터 오디오 경로
  String _getChapterStoragePath(String bookId, int chapter) =>
      'bible_audio/$bookId/$chapter/chapter.mp3';

  // ESV API
  static const String _esvBaseUrl = 'https://api.esv.org/v3/passage/audio/';

  // 이벤트 스트림
  final _stateController = StreamController<AudioPlaybackState>.broadcast();
  Stream<AudioPlaybackState> get stateStream => _stateController.stream;

  final _progressController = StreamController<Duration>.broadcast();
  Stream<Duration> get progressStream => _progressController.stream;

  BibleAudioService._() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _setState(AudioPlaybackState.playing);
          break;
        case PlayerState.paused:
          _setState(AudioPlaybackState.paused);
          break;
        case PlayerState.stopped:
          _setState(AudioPlaybackState.stopped);
          break;
        case PlayerState.completed:
          _setState(AudioPlaybackState.idle);
          break;
        case PlayerState.disposed:
          break;
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _progressController.add(position);
    });
  }

  // Getters
  AudioPlaybackState get state => _state;
  bool get isPlaying => _state == AudioPlaybackState.playing;
  double get playbackRate => _playbackRate;
  String? get currentVerse => _currentVerse;

  void _setState(AudioPlaybackState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// 재생 속도 설정 (0.5 ~ 2.0)
  Future<void> setPlaybackRate(double rate) async {
    if (rate < 0.5 || rate > 2.0) return;
    _playbackRate = rate;
    await _audioPlayer.setPlaybackRate(rate);
  }

  /// 구절 오디오 재생
  /// 우선순위: 1. Firebase Storage → 2. ESV API
  Future<AudioSourceType> playVerse({
    required String bookId,
    required int chapter,
    required int verse,
    bool forceEsvApi = false,
  }) async {
    _currentVerse = '$bookId:$chapter:$verse';
    _setState(AudioPlaybackState.loading);

    try {
      // 1. 로컬 캐시 확인
      if (!kIsWeb) {
        final cacheFile = await _getCacheFile(bookId, chapter, verse);
        if (await cacheFile.exists()) {
          final stat = await cacheFile.stat();
          final age = DateTime.now().difference(stat.modified);

          if (age.inDays < _cacheExpirationDays) {
            await _playFile(cacheFile);
            return AudioSourceType.local;
          } else {
            await cacheFile.delete();
          }
        }
      }

      // 2. Firebase Storage 확인 (forceEsvApi가 아닌 경우)
      if (!forceEsvApi) {
        try {
          final storagePath = _getStoragePath(bookId, chapter, verse);
          final downloadUrl = await _storage.ref(storagePath).getDownloadURL();

          if (kIsWeb) {
            await _playUrl(downloadUrl);
          } else {
            // 다운로드 후 캐시
            await _downloadAndCache(downloadUrl, bookId, chapter, verse);
            final cacheFile = await _getCacheFile(bookId, chapter, verse);
            await _playFile(cacheFile);
          }

          return AudioSourceType.firebaseStorage;
        } catch (e) {
          // Firebase Storage에 없음 - ESV API 폴백
        }
      }

      // 3. ESV API 폴백
      if (_esvApiKey.isEmpty) {
        throw Exception('ESV API 키가 설정되지 않았습니다.');
      }

      final bookNameEn = await BibleDataService.instance.getBookNameEn(bookId);
      final reference = '$bookNameEn+$chapter:$verse';
      final audioUrl = '$_esvBaseUrl?q=$reference';

      if (kIsWeb) {
        await _playEsvApiWeb(audioUrl);
      } else {
        await _downloadEsvAndCache(audioUrl, bookId, chapter, verse);
        final cacheFile = await _getCacheFile(bookId, chapter, verse);
        await _playFile(cacheFile);
      }

      return AudioSourceType.esvApi;
    } catch (e) {
      _setState(AudioPlaybackState.error);
      rethrow;
    }
  }

  /// 챕터 전체 오디오 재생 (있는 경우)
  Future<bool> playChapter({
    required String bookId,
    required int chapter,
  }) async {
    _setState(AudioPlaybackState.loading);

    try {
      final storagePath = _getChapterStoragePath(bookId, chapter);
      final downloadUrl = await _storage.ref(storagePath).getDownloadURL();

      await _playUrl(downloadUrl);
      return true;
    } catch (e) {
      _setState(AudioPlaybackState.idle);
      return false;
    }
  }

  /// 다음 구절 프리로드
  Future<void> preloadNextVerses({
    required String bookId,
    required int chapter,
    required int currentVerse,
    int count = 3,
  }) async {
    if (kIsWeb) return;

    final verseCount =
        await BibleDataService.instance.getVerseCount(bookId, chapter);

    for (int i = 1; i <= count && currentVerse + i <= verseCount; i++) {
      final verse = currentVerse + i;
      final cacheFile = await _getCacheFile(bookId, chapter, verse);

      if (!await cacheFile.exists()) {
        _preloadVerse(bookId, chapter, verse);
      }
    }
  }

  /// 백그라운드에서 구절 프리로드
  Future<void> _preloadVerse(String bookId, int chapter, int verse) async {
    try {
      // Firebase Storage 먼저 시도
      final storagePath = _getStoragePath(bookId, chapter, verse);
      try {
        final downloadUrl = await _storage.ref(storagePath).getDownloadURL();
        await _downloadAndCache(downloadUrl, bookId, chapter, verse);
        return;
      } catch (e) {
        // Firebase에 없음
      }

      // ESV API 폴백
      if (_esvApiKey.isNotEmpty) {
        final bookNameEn = await BibleDataService.instance.getBookNameEn(bookId);
        final reference = '$bookNameEn+$chapter:$verse';
        final audioUrl = '$_esvBaseUrl?q=$reference';
        await _downloadEsvAndCache(audioUrl, bookId, chapter, verse);
      }
    } catch (e) {
      // 프리로드 실패는 무시
    }
  }

  /// URL 다운로드 후 캐시
  Future<void> _downloadAndCache(
    String url,
    String bookId,
    int chapter,
    int verse,
  ) async {
    final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode == 200) {
      final cacheFile = await _getCacheFile(bookId, chapter, verse);
      await cacheFile.writeAsBytes(response.bodyBytes);
      _checkCacheSize();
    } else {
      throw Exception('다운로드 오류: ${response.statusCode}');
    }
  }

  /// ESV API 다운로드 후 캐시 (재시도 포함)
  Future<void> _downloadEsvAndCache(
    String url,
    String bookId,
    int chapter,
    int verse,
  ) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Token $_esvApiKey'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final cacheFile = await _getCacheFile(bookId, chapter, verse);
          await cacheFile.writeAsBytes(response.bodyBytes);
          _checkCacheSize();
          return;
        } else if (response.statusCode >= 500) {
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

  /// ESV API 웹 재생
  Future<void> _playEsvApiWeb(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Token $_esvApiKey'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      await _audioPlayer.setPlaybackRate(_playbackRate);
      await _audioPlayer.play(
        BytesSource(Uint8List.fromList(response.bodyBytes)),
      );
    } else {
      throw Exception('ESV API 오류: ${response.statusCode}');
    }
  }

  /// URL 직접 재생
  Future<void> _playUrl(String url) async {
    await _audioPlayer.setPlaybackRate(_playbackRate);
    await _audioPlayer.play(UrlSource(url));
  }

  /// 파일 재생
  Future<void> _playFile(File file) async {
    await _audioPlayer.setPlaybackRate(_playbackRate);
    await _audioPlayer.play(DeviceFileSource(file.path));
  }

  /// 캐시 파일 경로
  Future<File> _getCacheFile(String bookId, int chapter, int verse) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/bible_audio_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final key = '$bookId:$chapter:$verse';
    final hash = md5.convert(utf8.encode(key)).toString();
    return File('${cacheDir.path}/$hash.mp3');
  }

  /// 캐시 크기 체크 (비동기)
  void _checkCacheSize() {
    _cleanupCacheIfNeeded().catchError((_) {});
  }

  Future<void> _cleanupCacheIfNeeded() async {
    if (kIsWeb) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/bible_audio_cache');

      if (!await cacheDir.exists()) return;

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

      if (totalMB > _maxCacheSizeMB) {
        files.sort((a, b) => a.value.compareTo(b.value));

        int deletedBytes = 0;
        final targetDelete =
            totalBytes - (_maxCacheSizeMB * 1024 * 1024 * 0.8).toInt();

        for (final entry in files) {
          if (deletedBytes >= targetDelete) break;

          final stat = await entry.key.stat();
          deletedBytes += stat.size;
          await entry.key.delete();
        }
      }
    } catch (e) {
      // 무시
    }
  }

  /// 일시 정지
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// 재개
  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  /// 중지
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentVerse = null;
  }

  /// 특정 위치로 이동
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 캐시 삭제
  Future<void> clearCache() async {
    if (kIsWeb) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/bible_audio_cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // 무시
    }
  }

  /// 캐시 크기 조회
  Future<String> getCacheSize() async {
    if (kIsWeb) return '웹: 캐시 미지원';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/bible_audio_cache');

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

  /// 구절 캐시 여부 확인
  Future<bool> isVerseCached({
    required String bookId,
    required int chapter,
    required int verse,
  }) async {
    if (kIsWeb) return false;

    final cacheFile = await _getCacheFile(bookId, chapter, verse);
    return cacheFile.exists();
  }

  /// 리소스 해제
  void dispose() {
    _audioPlayer.dispose();
    _stateController.close();
    _progressController.close();
  }
}
