import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../pronunciation/azure_pronunciation_service.dart';

/// AI 튜터 피드백 결과
class TutorFeedback {
  final bool isSuccess;
  final String? errorMessage;

  /// 격려 메시지 (한글)
  final String encouragement;

  /// 상세 피드백 (한글)
  final String detailedFeedback;

  /// 발음 팁 목록
  final List<PronunciationTip> tips;

  /// 점수 등급 (A+, A, B+, B, C, D)
  final String grade;

  /// 전체 점수
  final double overallScore;

  /// 다음 단계 추천
  final NextStepRecommendation? nextStep;

  /// 음성 피드백 URL (ElevenLabs)
  final String? audioFeedbackUrl;

  TutorFeedback({
    required this.isSuccess,
    this.errorMessage,
    this.encouragement = '',
    this.detailedFeedback = '',
    this.tips = const [],
    this.grade = 'C',
    this.overallScore = 0,
    this.nextStep,
    this.audioFeedbackUrl,
  });

  factory TutorFeedback.error(String message) {
    return TutorFeedback(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// 발음 팁
class PronunciationTip {
  final String word;
  final String phoneme;
  final String tip;
  final String? koreanPronunciation;

  PronunciationTip({
    required this.word,
    required this.phoneme,
    required this.tip,
    this.koreanPronunciation,
  });
}

/// 다음 단계 추천
enum NextStepRecommendation {
  listenAgain, // TTS 다시 듣기
  repeatSlow, // 천천히 다시 따라하기
  practiceWords, // 특정 단어 연습
  nextVerse, // 다음 구절로 이동
  stageComplete, // 단계 완료
}

/// AI 튜터 코디네이터
/// Azure 발음 평가 → Gemini 피드백 생성 → (옵션) ElevenLabs 음성 합성
class TutorCoordinator {
  static TutorCoordinator? _instance;
  static TutorCoordinator get instance => _instance ??= TutorCoordinator._();

  final AzurePronunciationService _azureService = AzurePronunciationService();

  // API 키
  String get _geminiApiKey => AppConfig.geminiApiKey;
  String get _elevenLabsApiKey => AppConfig.elevenLabsApiKey;

  // Gemini 설정
  static const String _geminiModel = 'gemini-1.5-flash';
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ElevenLabs 설정 (한국어 음성)
  static const String _elevenLabsVoiceId = 'jBpfuIE2acCO8z3wKNLl'; // 한국어 여성 음성
  static const String _elevenLabsModel = 'eleven_multilingual_v2';

  // 단계별 통과 기준
  static const Map<int, double> _stagePassThresholds = {
    1: 70.0, // Stage 1: 듣고 따라하기
    2: 80.0, // Stage 2: 핵심 표현
    3: 85.0, // Stage 3: 실전 암송
  };

  TutorCoordinator._();

  /// 발음 평가 및 AI 피드백 생성 (전체 파이프라인)
  Future<TutorFeedback> evaluateAndFeedback({
    required String audioFilePath,
    required String referenceText,
    required int currentStage,
    bool generateAudioFeedback = false,
  }) async {
    try {
      // 1. Azure 발음 평가
      final pronunciationResult = await _azureService.evaluate(
        audioFilePath: audioFilePath,
        referenceText: referenceText,
      );

      if (!pronunciationResult.isSuccess) {
        return TutorFeedback.error(
          pronunciationResult.errorMessage ?? '발음 평가 실패',
        );
      }

      // 2. Gemini로 피드백 생성
      final geminiResponse = await _generateGeminiFeedback(
        pronunciationResult: pronunciationResult,
        currentStage: currentStage,
      );

      // 3. 발음 팁 추출
      final tips = _extractPronunciationTips(pronunciationResult);

      // 4. 다음 단계 추천 결정
      final nextStep = _determineNextStep(
        score: pronunciationResult.overallScore,
        stage: currentStage,
        incorrectWords: pronunciationResult.incorrectWords,
      );

      // 5. (옵션) ElevenLabs 음성 피드백
      String? audioUrl;
      if (generateAudioFeedback && _elevenLabsApiKey.isNotEmpty) {
        audioUrl = await _generateAudioFeedback(geminiResponse.encouragement);
      }

      return TutorFeedback(
        isSuccess: true,
        encouragement: geminiResponse.encouragement,
        detailedFeedback: geminiResponse.detailedFeedback,
        tips: tips,
        grade: pronunciationResult.grade,
        overallScore: pronunciationResult.overallScore,
        nextStep: nextStep,
        audioFeedbackUrl: audioUrl,
      );
    } catch (e) {
      return TutorFeedback.error('AI 튜터 오류: $e');
    }
  }

  /// Gemini로 피드백 생성
  Future<_GeminiFeedbackResponse> _generateGeminiFeedback({
    required PronunciationResult pronunciationResult,
    required int currentStage,
  }) async {
    if (_geminiApiKey.isEmpty || _geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return _getLocalFeedback(pronunciationResult);
    }

    try {
      final prompt = _buildGeminiPrompt(
        pronunciationResult: pronunciationResult,
        currentStage: currentStage,
      );

      final url = '$_geminiBaseUrl/$_geminiModel:generateContent?key=$_geminiApiKey';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 300,
        },
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text =
            jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (text != null) {
          return _parseGeminiResponse(text.trim());
        }
      }

      return _getLocalFeedback(pronunciationResult);
    } catch (e) {
      return _getLocalFeedback(pronunciationResult);
    }
  }

  /// Gemini 프롬프트 생성 (간결한 버전 - 20단어 이하 팁)
  String _buildGeminiPrompt({
    required PronunciationResult pronunciationResult,
    required int currentStage,
  }) {
    // 가장 문제되는 단어와 음소 추출
    final worstWord = pronunciationResult.incorrectWords.isNotEmpty
        ? pronunciationResult.incorrectWords.first
        : null;
    final worstPhoneme = worstWord?.worstPhoneme ??
        (pronunciationResult.weakestPhonemes.isNotEmpty
            ? pronunciationResult.weakestPhonemes.first
            : null);

    final phonemeInfo = worstPhoneme != null
        ? '문제 음소: ${worstPhoneme.phoneme} (${worstPhoneme.koreanHint})'
        : '전체적으로 양호';

    final wordInfo = worstWord != null
        ? '문제 단어: "${worstWord.word}" (${worstWord.accuracyScore.toStringAsFixed(0)}점)'
        : '모든 단어 정확';

    return '''
You are a friendly Korean English pronunciation tutor helping with Bible verse memorization.

Score: ${pronunciationResult.overallScore.toStringAsFixed(0)}%
$wordInfo
$phonemeInfo

Give feedback in Korean with this EXACT format:

[격려] (한 문장, 10단어 이하)

[팁] (발음 팁 한 문장, 20단어 이하, 입모양이나 혀 위치 설명)

Rules:
- Be encouraging and warm
- Focus on mouth position or tongue placement for the problem phoneme
- Keep tips practical and specific
- If score >= 80, praise and suggest moving forward
''';
  }

  /// 단계 설명
  String _getStageDescription(int stage) {
    switch (stage) {
      case 1:
        return '(듣고 따라하기 - 자막 O)';
      case 2:
        return '(핵심 표현 - 빈칸 채우기)';
      case 3:
        return '(실전 암송 - 자막 X)';
      default:
        return '';
    }
  }

  /// Gemini 응답 파싱 (간결한 버전)
  _GeminiFeedbackResponse _parseGeminiResponse(String text) {
    String encouragement = '';
    String tip = '';

    // [격려] 추출
    final encouragementMatch = RegExp(r'\[격려\]\s*(.+?)(?=\[|$)', dotAll: true).firstMatch(text);
    if (encouragementMatch != null) {
      encouragement = encouragementMatch.group(1)?.trim() ?? '';
    }

    // [팁] 추출 (새 형식)
    final tipMatch = RegExp(r'\[팁\]\s*(.+?)(?=\[|$)', dotAll: true).firstMatch(text);
    if (tipMatch != null) {
      tip = tipMatch.group(1)?.trim() ?? '';
    }

    // [발음팁] 형식도 지원 (하위 호환)
    if (tip.isEmpty) {
      final oldTipMatch = RegExp(r'\[발음팁\]\s*(.+?)(?=\[|$)', dotAll: true).firstMatch(text);
      if (oldTipMatch != null) {
        tip = oldTipMatch.group(1)?.trim() ?? '';
      }
    }

    // [피드백] 형식도 지원 (하위 호환)
    if (tip.isEmpty) {
      final feedbackMatch = RegExp(r'\[피드백\]\s*(.+?)(?=\[|$)', dotAll: true).firstMatch(text);
      if (feedbackMatch != null) {
        tip = feedbackMatch.group(1)?.trim() ?? '';
      }
    }

    // 형식이 맞지 않으면 전체 텍스트에서 추출
    if (encouragement.isEmpty && tip.isEmpty) {
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isNotEmpty) {
        encouragement = lines.first;
        tip = lines.length > 1 ? lines[1] : '';
      }
    }

    return _GeminiFeedbackResponse(
      encouragement: encouragement.isNotEmpty ? encouragement : '잘하고 있어요!',
      detailedFeedback: tip.isNotEmpty ? tip : '',
    );
  }

  /// 로컬 피드백 (Gemini API 실패 시)
  _GeminiFeedbackResponse _getLocalFeedback(PronunciationResult result) {
    final score = result.overallScore;
    String encouragement;
    String detailedFeedback;

    if (score >= 90) {
      encouragement = '완벽해요! 하나님의 말씀이 입에서 자연스럽게 흘러나오네요! 🌟';
      detailedFeedback = '원어민 수준의 발음입니다. 다음 구절로 넘어가도 좋아요!';
    } else if (score >= 80) {
      encouragement = '훌륭해요! 거의 완벽한 발음이에요! ✨';
      if (result.incorrectWords.isNotEmpty) {
        final word = result.incorrectWords.first.word;
        detailedFeedback = '"$word" 발음만 조금 더 신경 쓰면 완벽합니다.';
      } else {
        detailedFeedback = '조금만 더 연습하면 완벽해질 거예요!';
      }
    } else if (score >= 70) {
      encouragement = '잘하고 있어요! 꾸준한 연습이 실력을 만들어요. 💪';
      if (result.incorrectWords.isNotEmpty) {
        final words = result.incorrectWords.take(2).map((w) => w.word).join(', ');
        detailedFeedback = '"$words"에 집중해서 다시 들어보고 따라해보세요.';
      } else {
        detailedFeedback = '속도를 조금 늦추고 또박또박 발음해보세요.';
      }
    } else if (score >= 50) {
      encouragement = '좋은 시도예요! 연습하면 반드시 나아져요. 화이팅! 💕';
      detailedFeedback = '먼저 원어민 음성을 천천히 들어보고, 한 단어씩 따라해보세요.';
    } else {
      encouragement = '괜찮아요, 누구나 처음은 어려워요! 함께 해봐요. 🤗';
      detailedFeedback = 'TTS로 원문을 여러 번 들으면서 리듬과 발음을 익혀보세요.';
    }

    return _GeminiFeedbackResponse(
      encouragement: encouragement,
      detailedFeedback: detailedFeedback,
    );
  }

  /// 발음 팁 추출
  List<PronunciationTip> _extractPronunciationTips(PronunciationResult result) {
    final tips = <PronunciationTip>[];

    for (final word in result.incorrectWords.take(3)) {
      final worstPhoneme = word.worstPhoneme;
      if (worstPhoneme != null && worstPhoneme.pronunciationTip != null) {
        tips.add(PronunciationTip(
          word: word.word,
          phoneme: worstPhoneme.phoneme,
          tip: worstPhoneme.pronunciationTip!,
          koreanPronunciation: worstPhoneme.koreanHint,
        ));
      }
    }

    return tips;
  }

  /// 다음 단계 추천 결정
  NextStepRecommendation _determineNextStep({
    required double score,
    required int stage,
    required List<WordPronunciation> incorrectWords,
  }) {
    final threshold = _stagePassThresholds[stage] ?? 70.0;

    if (score >= threshold) {
      if (stage >= 3) {
        return NextStepRecommendation.stageComplete;
      }
      return NextStepRecommendation.nextVerse;
    }

    if (score < 50) {
      return NextStepRecommendation.listenAgain;
    }

    if (incorrectWords.length > 3) {
      return NextStepRecommendation.repeatSlow;
    }

    return NextStepRecommendation.practiceWords;
  }

  /// ElevenLabs 음성 피드백 생성
  Future<String?> _generateAudioFeedback(String text) async {
    if (_elevenLabsApiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/$_elevenLabsVoiceId',
      );

      final response = await http.post(
        url,
        headers: {
          'xi-api-key': _elevenLabsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'model_id': _elevenLabsModel,
          'voice_settings': {
            'stability': 0.7,
            'similarity_boost': 0.8,
          },
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // TODO: Firebase Storage에 업로드하고 URL 반환
        // 현재는 base64로 반환
        return 'data:audio/mpeg;base64,${base64Encode(response.bodyBytes)}';
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 기존 발음 결과로 AI 피드백만 생성 (Azure 재호출 없음)
  Future<TutorFeedback> generateFeedbackFromResult({
    required PronunciationResult pronunciationResult,
    required int currentStage,
  }) async {
    if (!pronunciationResult.isSuccess) {
      return TutorFeedback.error(
        pronunciationResult.errorMessage ?? '발음 평가 결과가 유효하지 않습니다.',
      );
    }

    try {
      // Gemini로 피드백 생성
      final geminiResponse = await _generateGeminiFeedback(
        pronunciationResult: pronunciationResult,
        currentStage: currentStage,
      );

      // 발음 팁 추출
      final tips = _extractPronunciationTips(pronunciationResult);

      // 다음 단계 추천 결정
      final nextStep = _determineNextStep(
        score: pronunciationResult.overallScore,
        stage: currentStage,
        incorrectWords: pronunciationResult.incorrectWords,
      );

      return TutorFeedback(
        isSuccess: true,
        encouragement: geminiResponse.encouragement,
        detailedFeedback: geminiResponse.detailedFeedback,
        tips: tips,
        grade: pronunciationResult.grade,
        overallScore: pronunciationResult.overallScore,
        nextStep: nextStep,
      );
    } catch (e) {
      // Gemini 실패 시 로컬 피드백
      final localFeedback = _getLocalFeedback(pronunciationResult);
      return TutorFeedback(
        isSuccess: true,
        encouragement: localFeedback.encouragement,
        detailedFeedback: localFeedback.detailedFeedback,
        tips: _extractPronunciationTips(pronunciationResult),
        grade: pronunciationResult.grade,
        overallScore: pronunciationResult.overallScore,
      );
    }
  }

  /// 빠른 점수별 메시지
  static String getQuickMessage(double score) {
    if (score >= 95) return '완벽! 🌟';
    if (score >= 85) return '훌륭해요! ✨';
    if (score >= 70) return '잘했어요! 💪';
    if (score >= 50) return '조금만 더! 💕';
    return '다시 도전! 🤗';
  }

  /// 단계 통과 여부 확인
  static bool isStagePass(int stage, double score) {
    final threshold = _stagePassThresholds[stage] ?? 70.0;
    return score >= threshold;
  }

  /// 다음 단계 추천 텍스트
  static String getNextStepText(NextStepRecommendation recommendation) {
    switch (recommendation) {
      case NextStepRecommendation.listenAgain:
        return '원어민 발음 다시 듣기';
      case NextStepRecommendation.repeatSlow:
        return '천천히 다시 따라하기';
      case NextStepRecommendation.practiceWords:
        return '틀린 단어 연습하기';
      case NextStepRecommendation.nextVerse:
        return '다음 구절로 이동';
      case NextStepRecommendation.stageComplete:
        return '🎉 단계 완료!';
    }
  }
}

/// Gemini 피드백 응답 (내부용)
class _GeminiFeedbackResponse {
  final String encouragement;
  final String detailedFeedback;

  _GeminiFeedbackResponse({
    required this.encouragement,
    required this.detailedFeedback,
  });
}
