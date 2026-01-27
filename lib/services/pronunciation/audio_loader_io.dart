import 'dart:io';
import 'dart:typed_data';

/// 모바일 구현 - 파일 시스템 사용
Future<Uint8List?> loadAudioFromFile(String filePath) async {
  try {
    final file = File(filePath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      print('📁 파일 로드 완료 (${bytes.length} bytes)');
      return bytes;
    }
    print('❌ 파일이 존재하지 않습니다: $filePath');
    return null;
  } catch (e) {
    print('❌ 파일 읽기 실패: $e');
    return null;
  }
}
