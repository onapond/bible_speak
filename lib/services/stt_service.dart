/// STT 서비스 (Speech-to-Text)
///
/// 레거시 ElevenLabs 직접 호출은 공급자 키를 앱 번들에 포함했기 때문에
/// 제거했다. 암송 평가는 인증된 Azure 서버 프록시를 사용한다.
class STTService {
  /// 오디오 파일을 텍스트로 변환
  Future<STTResult> transcribeAudio({
    required String audioFilePath,
    String? languageCode, // null = 자동 감지, 'en' = 영어
  }) async {
    return STTResult.error('이 음성 인식 경로는 더 이상 지원되지 않습니다.');
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

  factory STTResult.success(
      {required String text, required String languageCode}) {
    return STTResult._(isSuccess: true, text: text, languageCode: languageCode);
  }

  factory STTResult.error(String message) {
    return STTResult._(isSuccess: false, errorMessage: message);
  }
}
