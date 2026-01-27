import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 마이크 녹음 서비스 (웹/모바일 통합)
/// - record 패키지 사용 (모든 플랫폼 지원)
class RecordingService {
  AudioRecorder? _recorder;

  bool _isInitialized = false;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  String? _lastRecordingPath;
  String? get lastRecordingPath => _lastRecordingPath;

  // 웹에서 사용할 녹음 데이터 (Blob URL)
  Uint8List? _webRecordingData;
  Uint8List? get webRecordingData => _webRecordingData;

  /// 초기화
  Future<bool> init() async {
    if (_isInitialized) return true;

    print('🎤 녹음기 초기화 중...');

    try {
      _recorder = AudioRecorder();
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
      // 웹에서는 record 패키지가 자동으로 권한 요청
      final hasPermission = await _recorder?.hasPermission() ?? false;
      if (hasPermission) {
        print('✅ 마이크 권한 허용됨 (웹)');
        return true;
      }
      print('❌ 마이크 권한 거부됨 (웹)');
      return false;
    }

    // 모바일
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

    if (_isRecording) {
      print('⚠️ 이미 녹음 중입니다');
      return false;
    }

    if (!_isInitialized) {
      final ok = await init();
      if (!ok) return false;
    }

    final hasPermission = await requestPermission();
    if (!hasPermission) return false;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (kIsWeb) {
        // 웹: 메모리에 녹음
        await _recorder!.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: '', // 웹에서는 빈 경로 (Blob 사용)
        );
        _lastRecordingPath = 'web_recording_$timestamp.wav';
      } else {
        // 모바일: 파일로 녹음
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/recording_$timestamp.wav';

        await _recorder!.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );
        _lastRecordingPath = filePath;
      }

      _isRecording = true;
      print('✅ 녹음 시작됨!');
      print('📁 경로: $_lastRecordingPath\n');

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
      final result = await _recorder!.stop();
      _isRecording = false;

      if (kIsWeb) {
        // 웹: Blob URL 반환
        if (result != null) {
          print('✅ 녹음 완료! (웹)');
          print('📁 Blob URL: $result\n');
          return result;
        }
      } else {
        // 모바일: 파일 경로 반환
        if (result != null) {
          print('✅ 녹음 완료!');
          print('📁 경로: $result\n');
          return result;
        }
      }

      return _lastRecordingPath;
    } catch (e) {
      print('❌ 녹음 중지 실패: $e');
      _isRecording = false;
      return null;
    }
  }

  /// 리소스 정리
  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder?.stop();
    }
    await _recorder?.dispose();
    _recorder = null;
    _isInitialized = false;
    _webRecordingData = null;
    print('🧹 녹음 서비스 정리 완료');
  }
}
