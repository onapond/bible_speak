import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Azure Pronunciation Assessment 서비스
/// - 음소별 발음 점수
/// - 단어별 정확도, 유창성
/// - 구체적인 발음 교정 피드백
class AzurePronunciationService {
  // Azure Speech 설정 (.env에서 로드)
  String get _subscriptionKey => dotenv.env['AZURE_SPEECH_KEY'] ?? '';
  String get _region => dotenv.env['AZURE_SPEECH_REGION'] ?? 'koreacentral';

  String get _endpoint =>
      'https://$_region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1';

  /// 발음 평가 실행
  Future<PronunciationResult> evaluate({
    required String audioFilePath,
    required String referenceText,
    String language = 'en-US',
  }) async {
    if (_subscriptionKey.isEmpty) {
      return PronunciationResult.error('Azure Speech API 키가 설정되지 않았습니다.');
    }

    try {
      final file = File(audioFilePath);
      if (!await file.exists()) {
        return PronunciationResult.error('오디오 파일을 찾을 수 없습니다.');
      }

      final audioBytes = await file.readAsBytes();
      print('🎤 Azure 발음 평가 시작...');
      print('📝 참조 텍스트: $referenceText');

      // Pronunciation Assessment 설정
      final pronunciationConfig = {
        'ReferenceText': referenceText,
        'GradingSystem': 'HundredMark',
        'Granularity': 'Phoneme', // 음소 단위 평가
        'EnableMiscue': true, // 누락/추가 단어 감지
        'EnableProsodyAssessment': true, // 운율 평가 (강세, 억양)
      };

      final configBase64 = base64Encode(utf8.encode(jsonEncode(pronunciationConfig)));

      // API 호출
      final response = await http.post(
        Uri.parse('$_endpoint?language=$language&format=detailed'),
        headers: {
          'Ocp-Apim-Subscription-Key': _subscriptionKey,
          'Content-Type': 'audio/wav', // 또는 audio/ogg;codecs=opus
          'Pronunciation-Assessment': configBase64,
          'Accept': 'application/json',
        },
        body: audioBytes,
      ).timeout(const Duration(seconds: 30));

      print('📥 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return _parseResponse(jsonResponse, referenceText);
      } else {
        print('❌ Azure API 오류: ${response.body}');
        return PronunciationResult.error('API 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 예외 발생: $e');
      return PronunciationResult.error('네트워크 오류: $e');
    }
  }

  /// API 응답 파싱
  PronunciationResult _parseResponse(Map<String, dynamic> json, String referenceText) {
    try {
      final nBest = json['NBest'] as List?;
      if (nBest == null || nBest.isEmpty) {
        return PronunciationResult.error('인식 결과가 없습니다.');
      }

      final best = nBest[0];
      final assessment = best['PronunciationAssessment'] as Map<String, dynamic>?;

      if (assessment == null) {
        return PronunciationResult.error('발음 평가 결과가 없습니다.');
      }

      // 전체 점수
      final accuracyScore = (assessment['AccuracyScore'] as num?)?.toDouble() ?? 0;
      final fluencyScore = (assessment['FluencyScore'] as num?)?.toDouble() ?? 0;
      final completenessScore = (assessment['CompletenessScore'] as num?)?.toDouble() ?? 0;
      final prosodyScore = (assessment['ProsodyScore'] as num?)?.toDouble() ?? 0;
      final pronScore = (assessment['PronScore'] as num?)?.toDouble() ?? 0;

      // 단어별 결과
      final words = <WordPronunciation>[];
      final wordsJson = best['Words'] as List? ?? [];

      for (final wordJson in wordsJson) {
        final wordAssessment = wordJson['PronunciationAssessment'] as Map<String, dynamic>?;

        // 음소별 결과
        final phonemes = <PhonemePronunciation>[];
        final phonemesJson = wordJson['Phonemes'] as List? ?? [];

        for (final phonemeJson in phonemesJson) {
          final phonemeAssessment = phonemeJson['PronunciationAssessment'] as Map<String, dynamic>?;
          phonemes.add(PhonemePronunciation(
            phoneme: phonemeJson['Phoneme'] ?? '',
            accuracyScore: (phonemeAssessment?['AccuracyScore'] as num?)?.toDouble() ?? 0,
          ));
        }

        words.add(WordPronunciation(
          word: wordJson['Word'] ?? '',
          accuracyScore: (wordAssessment?['AccuracyScore'] as num?)?.toDouble() ?? 0,
          errorType: wordAssessment?['ErrorType'] ?? 'None',
          phonemes: phonemes,
        ));
      }

      print('✅ 발음 평가 완료');
      print('📊 전체 점수: $pronScore');
      print('🎯 정확도: $accuracyScore, 유창성: $fluencyScore');

      return PronunciationResult(
        isSuccess: true,
        recognizedText: best['Display'] ?? '',
        referenceText: referenceText,
        overallScore: pronScore,
        accuracyScore: accuracyScore,
        fluencyScore: fluencyScore,
        completenessScore: completenessScore,
        prosodyScore: prosodyScore,
        words: words,
      );
    } catch (e) {
      print('❌ 파싱 오류: $e');
      return PronunciationResult.error('결과 파싱 오류: $e');
    }
  }
}

/// 발음 평가 결과
class PronunciationResult {
  final bool isSuccess;
  final String? errorMessage;
  final String recognizedText;
  final String referenceText;

  // 전체 점수 (0-100)
  final double overallScore;      // 종합 발음 점수
  final double accuracyScore;     // 정확도 (음소 정확성)
  final double fluencyScore;      // 유창성 (자연스러움)
  final double completenessScore; // 완전성 (누락 없이 말했는지)
  final double prosodyScore;      // 운율 (강세, 억양)

  // 단어별 결과
  final List<WordPronunciation> words;

  PronunciationResult({
    required this.isSuccess,
    this.errorMessage,
    this.recognizedText = '',
    this.referenceText = '',
    this.overallScore = 0,
    this.accuracyScore = 0,
    this.fluencyScore = 0,
    this.completenessScore = 0,
    this.prosodyScore = 0,
    this.words = const [],
  });

  factory PronunciationResult.error(String message) {
    return PronunciationResult(
      isSuccess: false,
      errorMessage: message,
    );
  }

  /// 틀린 단어 목록
  List<WordPronunciation> get incorrectWords =>
      words.where((w) => w.accuracyScore < 60 || w.errorType != 'None').toList();

  /// 잘한 단어 목록
  List<WordPronunciation> get correctWords =>
      words.where((w) => w.accuracyScore >= 80 && w.errorType == 'None').toList();

  /// 개선 필요 단어 (60-80점)
  List<WordPronunciation> get needsImprovementWords =>
      words.where((w) => w.accuracyScore >= 60 && w.accuracyScore < 80).toList();

  /// 가장 취약한 음소 찾기
  List<PhonemePronunciation> get weakestPhonemes {
    final allPhonemes = <PhonemePronunciation>[];
    for (final word in words) {
      allPhonemes.addAll(word.phonemes.where((p) => p.accuracyScore < 60));
    }
    allPhonemes.sort((a, b) => a.accuracyScore.compareTo(b.accuracyScore));
    return allPhonemes.take(5).toList();
  }

  /// 등급
  String get grade {
    if (overallScore >= 90) return 'A+';
    if (overallScore >= 80) return 'A';
    if (overallScore >= 70) return 'B+';
    if (overallScore >= 60) return 'B';
    if (overallScore >= 50) return 'C';
    return 'D';
  }
}

/// 단어별 발음 결과
class WordPronunciation {
  final String word;
  final double accuracyScore;
  final String errorType; // None, Omission, Insertion, Mispronunciation
  final List<PhonemePronunciation> phonemes;

  WordPronunciation({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
    required this.phonemes,
  });

  bool get isCorrect => accuracyScore >= 80 && errorType == 'None';
  bool get isOmitted => errorType == 'Omission';
  bool get isMispronounced => errorType == 'Mispronunciation';

  /// 가장 틀린 음소
  PhonemePronunciation? get worstPhoneme {
    if (phonemes.isEmpty) return null;
    return phonemes.reduce((a, b) => a.accuracyScore < b.accuracyScore ? a : b);
  }

  /// 에러 타입 한글
  String get errorTypeKorean {
    switch (errorType) {
      case 'Omission':
        return '누락';
      case 'Insertion':
        return '추가';
      case 'Mispronunciation':
        return '발음 오류';
      default:
        return '';
    }
  }
}

/// 음소별 발음 결과
class PhonemePronunciation {
  final String phoneme;
  final double accuracyScore;

  PhonemePronunciation({
    required this.phoneme,
    required this.accuracyScore,
  });

  bool get isCorrect => accuracyScore >= 80;

  /// IPA를 한글 발음 힌트로 변환
  String get koreanHint {
    const ipaToKorean = {
      // 모음
      'i': '이', 'ɪ': '이(짧게)', 'e': '에', 'ɛ': '에', 'æ': '애',
      'ɑ': '아', 'ɔ': '오', 'o': '오', 'ʊ': '우(짧게)', 'u': '우',
      'ʌ': '어', 'ə': '어(약하게)', 'ɜ': '어',
      // 이중모음
      'aɪ': '아이', 'aʊ': '아우', 'ɔɪ': '오이', 'eɪ': '에이', 'oʊ': '오우',
      // 자음
      'p': 'ㅍ', 'b': 'ㅂ', 't': 'ㅌ', 'd': 'ㄷ', 'k': 'ㅋ', 'g': 'ㄱ',
      'f': 'ㅍ(입술)', 'v': 'ㅂ(입술)', 'θ': 'ㅆ(혀)', 'ð': 'ㄷ(혀)',
      's': 'ㅅ', 'z': 'ㅈ', 'ʃ': '쉬', 'ʒ': '쥬', 'h': 'ㅎ',
      'tʃ': '취', 'dʒ': '쥐',
      'm': 'ㅁ', 'n': 'ㄴ', 'ŋ': 'ㅇ(받침)',
      'l': 'ㄹ', 'r': 'ㄹ(혀 말기)', 'w': '우', 'j': '이',
    };
    return ipaToKorean[phoneme] ?? phoneme;
  }
}
