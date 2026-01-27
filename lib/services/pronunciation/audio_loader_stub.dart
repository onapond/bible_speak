import 'dart:typed_data';

/// 웹 스텁 - 파일 시스템 사용 불가
Future<Uint8List?> loadAudioFromFile(String filePath) async {
  print('⚠️ 웹에서는 파일 시스템을 사용할 수 없습니다.');
  return null;
}
