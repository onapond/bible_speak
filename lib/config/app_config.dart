/// 앱 설정 (웹/모바일 통합)
///
/// 외부 서비스 비밀 키는 앱에 포함하지 않습니다. 모든 유료 API 호출은
/// Firebase ID 토큰으로 인증한 뒤 서버 프록시를 통해 수행합니다.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://asia-northeast3-bible-speak.cloudfunctions.net',
  );

  static String getEsvAudioUrl(String reference) {
    return '$apiBaseUrl/esvAudio?q=${Uri.encodeComponent(reference)}';
  }

  static String getEsvTextUrl(String reference) {
    return '$apiBaseUrl/esvText?q=${Uri.encodeComponent(reference)}';
  }

  static String get pronunciationAssessmentUrl =>
      '$apiBaseUrl/pronunciationAssessment';
  static String get geminiFeedbackUrl => '$apiBaseUrl/geminiFeedback';
  static String get elevenLabsTtsUrl => '$apiBaseUrl/elevenLabsTts';
  static String get verifySubscriptionPurchaseUrl =>
      '$apiBaseUrl/verifySubscriptionPurchase';
}
