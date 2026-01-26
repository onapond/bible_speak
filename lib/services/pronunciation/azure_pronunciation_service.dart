import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Azure Pronunciation Assessment 서비스 (최적화 버전)
/// - 재시도 로직 (최대 3회)
/// - 타임아웃 관리
/// - 오프라인 감지
/// - 상세한 오류 메시지
class AzurePronunciationService {
  // Azure Speech 설정
  String get _subscriptionKey => dotenv.env['AZURE_SPEECH_KEY'] ?? '';
  String get _region => dotenv.env['AZURE_SPEECH_REGION'] ?? 'koreacentral';

  String get _endpoint =>
      'https://$_region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1';

  // 재시도 설정
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 45);
  static const Duration _retryDelay = Duration(seconds: 2);

  /// API 키 설정 확인
  bool get isConfigured => _subscriptionKey.isNotEmpty && _subscriptionKey != 'YOUR_AZURE_SPEECH_KEY_HERE';

  /// 발음 평가 실행
  Future<PronunciationResult> evaluate({
    required String audioFilePath,
    required String referenceText,
    String language = 'en-US',
  }) async {
    // 설정 확인
    if (!isConfigured) {
      return PronunciationResult.error(
        '발음 평가 기능을 사용하려면 Azure Speech API 키를 설정하세요.\n'
        '.env 파일에 AZURE_SPEECH_KEY를 입력해주세요.',
      );
    }

    // 파일 확인
    final file = File(audioFilePath);
    if (!await file.exists()) {
      return PronunciationResult.error('오디오 파일을 찾을 수 없습니다.');
    }

    // 파일 크기 확인 (너무 작으면 녹음 실패)
    final fileSize = await file.length();
    if (fileSize < 1000) {
      return PronunciationResult.error(
        '녹음이 너무 짧습니다. 다시 녹음해주세요.',
      );
    }

    // 파일 크기 제한 (10MB)
    if (fileSize > 10 * 1024 * 1024) {
      return PronunciationResult.error(
        '녹음이 너무 깁니다. 구절을 나눠서 녹음해주세요.',
      );
    }

    final audioBytes = await file.readAsBytes();

    // 재시도 로직
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await _makeRequest(
          audioBytes: audioBytes,
          referenceText: referenceText,
          language: language,
        );
      } on TimeoutException {
        lastException = Exception('서버 응답 시간 초과');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      } on SocketException catch (e) {
        // 네트워크 연결 오류
        if (e.message.contains('Failed host lookup') ||
            e.message.contains('No address associated')) {
          return PronunciationResult.error(
            '인터넷 연결을 확인해주세요.\n네트워크에 연결되어 있지 않습니다.',
          );
        }
        lastException = Exception('네트워크 오류: ${e.message}');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      } on HttpException catch (e) {
        lastException = Exception('HTTP 오류: ${e.message}');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      } catch (e) {
        // 재시도할 수 없는 오류
        if (e.toString().contains('API 키') ||
            e.toString().contains('인식 결과')) {
          return PronunciationResult.error(e.toString());
        }
        lastException = Exception('발음 평가 오류: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      }
    }

    return PronunciationResult.error(
      lastException?.toString() ?? '알 수 없는 오류가 발생했습니다.',
    );
  }

  /// API 요청 실행
  Future<PronunciationResult> _makeRequest({
    required List<int> audioBytes,
    required String referenceText,
    required String language,
  }) async {
    // Pronunciation Assessment 설정
    final pronunciationConfig = {
      'ReferenceText': referenceText,
      'GradingSystem': 'HundredMark',
      'Granularity': 'Phoneme',
      'EnableMiscue': true,
      'EnableProsodyAssessment': true,
    };

    final configBase64 = base64Encode(utf8.encode(jsonEncode(pronunciationConfig)));

    // API 호출
    final response = await http.post(
      Uri.parse('$_endpoint?language=$language&format=detailed'),
      headers: {
        'Ocp-Apim-Subscription-Key': _subscriptionKey,
        'Content-Type': 'audio/wav',
        'Pronunciation-Assessment': configBase64,
        'Accept': 'application/json',
      },
      body: audioBytes,
    ).timeout(_timeout);

    // 응답 처리
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return _parseResponse(jsonResponse, referenceText);
    } else if (response.statusCode == 401) {
      throw Exception('API 키가 유효하지 않습니다. Azure Portal에서 키를 확인해주세요.');
    } else if (response.statusCode == 403) {
      throw Exception('API 키의 권한이 부족합니다.');
    } else if (response.statusCode == 429) {
      throw Exception('요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
    } else if (response.statusCode >= 500) {
      throw Exception('Azure 서버 오류 (${response.statusCode})');
    } else {
      // 오류 상세 정보 파싱 시도
      try {
        final errorJson = jsonDecode(response.body);
        final errorMessage = errorJson['error']?['message'] ?? response.body;
        throw Exception('API 오류: $errorMessage');
      } catch (_) {
        throw Exception('API 오류: ${response.statusCode}');
      }
    }
  }

  /// API 응답 파싱
  PronunciationResult _parseResponse(Map<String, dynamic> json, String referenceText) {
    // RecognitionStatus 확인
    final status = json['RecognitionStatus'];
    if (status == 'NoMatch') {
      return PronunciationResult.error(
        '음성을 인식하지 못했습니다.\n'
        '조용한 환경에서 마이크 가까이 다시 녹음해주세요.',
      );
    } else if (status == 'InitialSilenceTimeout') {
      return PronunciationResult.error(
        '녹음 시작 부분에 소리가 없습니다.\n'
        '녹음 버튼을 누른 직후 말해주세요.',
      );
    } else if (status == 'BabbleTimeout') {
      return PronunciationResult.error(
        '배경 소음이 너무 많습니다.\n'
        '조용한 환경에서 다시 녹음해주세요.',
      );
    } else if (status == 'Error') {
      return PronunciationResult.error('음성 인식 오류가 발생했습니다.');
    }

    // NBest 결과 확인
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
  }

  /// 연결 테스트
  Future<bool> testConnection() async {
    if (!isConfigured) return false;

    try {
      // 간단한 GET 요청으로 연결 확인 (실제로는 토큰 발급 엔드포인트)
      final tokenUrl = 'https://$_region.api.cognitive.microsoft.com/sts/v1.0/issueToken';
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Ocp-Apim-Subscription-Key': _subscriptionKey,
          'Content-Length': '0',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
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
  final double overallScore;
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double prosodyScore;

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

  /// 피드백 요약
  String get feedbackSummary {
    if (!isSuccess) return errorMessage ?? '평가 실패';

    if (overallScore >= 90) {
      return '훌륭합니다! 거의 완벽한 발음이에요.';
    } else if (overallScore >= 80) {
      return '잘했어요! 조금만 더 연습하면 완벽해질 거예요.';
    } else if (overallScore >= 70) {
      return '좋아요! 몇 가지 발음에 집중해 보세요.';
    } else if (overallScore >= 60) {
      return '괜찮아요! 계속 연습하면 나아질 거예요.';
    } else {
      return '천천히 다시 도전해 보세요. 할 수 있어요!';
    }
  }
}

/// 단어별 발음 결과
class WordPronunciation {
  final String word;
  final double accuracyScore;
  final String errorType;
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
  bool get isInserted => errorType == 'Insertion';

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

  /// 점수 기반 상태
  String get status {
    if (errorType == 'Omission') return '누락';
    if (accuracyScore >= 80) return '정확';
    if (accuracyScore >= 60) return '개선 필요';
    return '오류';
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
      'ʌ': '어', 'ə': '어(약하게)', 'ɜ': '어', 'ɝ': '얼',
      // 이중모음
      'aɪ': '아이', 'aʊ': '아우', 'ɔɪ': '오이', 'eɪ': '에이', 'oʊ': '오우',
      'ɪr': '이어', 'ɛr': '에어', 'ʊr': '우어',
      // 자음
      'p': 'ㅍ', 'b': 'ㅂ', 't': 'ㅌ', 'd': 'ㄷ', 'k': 'ㅋ', 'g': 'ㄱ',
      'f': 'ㅍ(입술 물기)', 'v': 'ㅂ(입술 물기)',
      'θ': 'ㅆ(혀 내밀기)', 'ð': 'ㄷ(혀 내밀기)',
      's': 'ㅅ', 'z': 'ㅈ(떨림)', 'ʃ': '쉬', 'ʒ': '쥬', 'h': 'ㅎ',
      'tʃ': '취', 'dʒ': '쥐',
      'm': 'ㅁ', 'n': 'ㄴ', 'ŋ': 'ㅇ받침',
      'l': 'ㄹ', 'r': 'ㄹ(혀 말기)', 'ɹ': 'ㄹ(혀 말기)',
      'w': '우', 'j': '이', 'y': '이',
    };
    return ipaToKorean[phoneme.toLowerCase()] ?? phoneme;
  }

  /// 발음 팁
  String? get pronunciationTip {
    final tips = {
      'θ': '혀끝을 윗니 사이에 살짝 내밀고 바람을 내뿜으세요',
      'ð': '혀끝을 윗니 사이에 대고 성대를 울리세요',
      'r': '혀를 입천장에 닿지 않게 뒤로 말아 올리세요',
      'ɹ': '혀를 입천장에 닿지 않게 뒤로 말아 올리세요',
      'l': '혀끝을 윗니 뒤 잇몸에 대세요',
      'v': '윗니로 아랫입술을 살짝 물고 소리내세요',
      'f': '윗니로 아랫입술을 살짝 물고 바람을 내뿜으세요',
      'æ': '입을 크게 벌리고 "애"와 "아" 중간 소리를 내세요',
      'ʌ': '"어"보다 입을 약간 더 벌리고 짧게 발음하세요',
      'ə': '힘을 빼고 가볍게 "어" 소리를 내세요',
    };
    return tips[phoneme.toLowerCase()];
  }
}
