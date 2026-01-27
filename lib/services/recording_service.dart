import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 마이크 녹음 서비스
/// - flutter_sound 사용
/// - 웹에서는 제한됨
class RecordingService {
  FlutterSoundRecorder? _recorder;

  bool _isInitialized = false;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  String? _lastRecordingPath;
  String? get lastRecordingPath => _lastRecordingPath;

  /// 초기화
  Future<bool> init() async {
    if (_isInitialized) return true;

    // 웹 환경 체크
    if (kIsWeb) {
      print('⚠️ 웹에서는 녹음 기능이 제한됩니다.');
      return false;
    }

    print('🎤 녹음기 초기화 중...');

    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      _isInitialized = true;
      print('✅ 녹음기 초기화 완료');
      return true;
    } catch (e) {
      print('❌ 녹음기 초기화 실패: $e');
      return false;
    }
  }

  /// 마이크 권한 요청
  Future<bool> requestPermission() async {
    print('🔐 마이크 권한 확인 중...');

    if (kIsWeb) {
      print('🌐 웹 환경: 브라우저 권한 필요');
      return true; // 웹은 별도 처리
    }

    final status = await Permission.microphone.request();

    if (status.isGranted) {
      print('✅ 마이크 권한 허용됨');
      return true;
    } else if (status.isPermanentlyDenied) {
      print('❌ 마이크 권한 영구 거부됨');
      await openAppSettings();
      return false;
    } else {
      print('❌ 마이크 권한 거부됨');
      return false;
    }
  }

  /// 녹음 시작
  Future<bool> startRecording() async {
    print('\n🎤 녹음 시작 요청');

    if (kIsWeb) {
      print('❌ 웹에서는 녹음이 지원되지 않습니다.');
      return false;
    }

    if (_isRecording) {
      print('⚠️ 이미 녹음 중입니다');
      return false;
    }

    final hasPermission = await requestPermission();
    if (!hasPermission) return false;

    if (!_isInitialized) {
      final ok = await init();
      if (!ok) return false;
    }

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/recording_$timestamp.wav';

      await _recorder!.startRecorder(
        toFile: filePath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      _isRecording = true;
      _lastRecordingPath = filePath;

      print('✅ 녹음 시작됨!');
      print('📁 경로: $filePath\n');

      return true;
    } catch (e) {
      print('❌ 녹음 시작 실패: $e');
      _isRecording = false;
      return false;
    }
  }

  /// 녹음 중지
  Future<String?> stopRecording() async {
    print('\n⏹️ 녹음 중지 요청');

    if (!_isRecording) {
      print('⚠️ 녹음 중이 아닙니다');
      return null;
    }

    try {
      await _recorder!.stopRecorder();
      _isRecording = false;

      final path = _lastRecordingPath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          print('✅ 녹음 완료!');
          print('📁 경로: $path');
          print('📊 크기: ${(size / 1024).toStringAsFixed(2)} KB\n');
        }
        return path;
      }
      return null;
    } catch (e) {
      print('❌ 녹음 중지 실패: $e');
      _isRecording = false;
      return null;
    }
  }

  /// 리소스 정리
  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder?.stopRecorder();
    }
    await _recorder?.closeRecorder();
    _recorder = null;
    _isInitialized = false;
    print('🧹 녹음 서비스 정리 완료');
  }
}
