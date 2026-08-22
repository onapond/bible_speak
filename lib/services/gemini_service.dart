import 'dart:convert';
import '../config/app_config.dart';
import 'api/authenticated_api_client.dart';

/// Gemini AI 튜터 서비스
/// - 발음 평가 결과 분석
/// - 맞춤형 피드백 제공
class GeminiService {
  /// 발음 피드백 생성
  Future<String> getFeedback({
    required String originalText,
    required String spokenText,
    required List<String> incorrectWords,
    required double score,
  }) async {
    try {
      final prompt = _buildPrompt(
        originalText: originalText,
        spokenText: spokenText,
        incorrectWords: incorrectWords,
        score: score,
      );

      return await _callGeminiAPI(prompt);
    } catch (e) {
      print('❌ Gemini API 오류: $e');
      return _getLocalFeedback(incorrectWords, score);
    }
  }

  /// 프롬프트 생성
  String _buildPrompt({
    required String originalText,
    required String spokenText,
    required List<String> incorrectWords,
    required double score,
  }) {
    return '''
당신은 친절한 영어 발음 코치입니다. 한국인 학습자가 성경 구절을 영어로 암송했습니다.

[원본 문장]
$originalText

[학습자가 말한 것 (음성인식 결과)]
$spokenText

[틀린 단어들]
${incorrectWords.isEmpty ? '없음' : incorrectWords.join(', ')}

[정확도 점수]
${score.toStringAsFixed(0)}%

위 정보를 바탕으로 학습자에게 도움이 되는 피드백을 한국어로 1-2문장으로 짧게 제공해주세요.
- 틀린 단어가 있다면 어떻게 발음하면 좋을지 팁을 주세요
- 격려와 함께 구체적인 개선점을 알려주세요
''';
  }

  /// Gemini API 호출
  Future<String> _callGeminiAPI(String prompt) async {
    print('🤖 Gemini API 호출 중...');

    final response = await AuthenticatedApiClient.postJson(
      Uri.parse(AppConfig.geminiFeedbackUrl),
      {'prompt': prompt},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final text = jsonResponse['text'];

      if (text != null) {
        print('✅ Gemini 응답 완료');
        return text.trim();
      }
      return _getLocalFeedback([], 0);
    } else {
      print('❌ Gemini API 오류: ${response.statusCode}');
      throw Exception('API 호출 실패: ${response.statusCode}');
    }
  }

  /// 로컬 피드백 (API 실패 시 fallback)
  String _getLocalFeedback(List<String> incorrectWords, double score) {
    if (score >= 90) {
      return '완벽해요! 원어민처럼 발음하셨습니다!';
    } else if (score >= 80) {
      return '훌륭해요! 조금만 더 연습하면 완벽합니다!';
    } else if (score >= 70) {
      if (incorrectWords.isNotEmpty) {
        final word = incorrectWords.first;
        return '좋아요! "$word" 발음에 조금 더 신경 써보세요.';
      }
      return '좋은 시도예요! 천천히 또박또박 발음해보세요.';
    } else if (score >= 50) {
      return 'TTS로 원어민 발음을 다시 들어보고 따라해보세요!';
    } else {
      return '먼저 원문을 들으면서 발음을 익혀보세요. 화이팅!';
    }
  }

  /// 점수별 격려 메시지 (간단 버전)
  static String getQuickEncouragement(double score) {
    if (score >= 95) return '완벽!';
    if (score >= 85) return '훌륭해요!';
    if (score >= 70) return '잘했어요!';
    if (score >= 50) return '조금만 더!';
    return '다시 도전!';
  }
}
