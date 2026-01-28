import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_progress.dart';

/// 단어 학습 진행 서비스 (SRS 지원)
class WordProgressService {
  static const String _keyPrefix = 'word_progress_';

  SharedPreferences? _prefs;

  /// 초기화
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 단어 진행 상황 가져오기
  Future<WordProgress> getProgress(String wordId) async {
    await init();

    final key = '$_keyPrefix$wordId';
    final jsonStr = _prefs!.getString(key);

    if (jsonStr == null) {
      return WordProgress(wordId: wordId);
    }

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return WordProgress.fromJson(json);
    } catch (_) {
      return WordProgress(wordId: wordId);
    }
  }

  /// 진행 상황 저장
  Future<void> saveProgress(WordProgress progress) async {
    await init();

    final key = '$_keyPrefix${progress.wordId}';
    final jsonStr = jsonEncode(progress.toJson());
    await _prefs!.setString(key, jsonStr);
  }

  /// SRS 기반 정답 기록
  Future<WordProgress> recordAnswerWithSRS({
    required String wordId,
    required int quality, // 0-5
  }) async {
    final current = await getProgress(wordId);
    final updated = SRSCalculator.calculate(current, quality);
    await saveProgress(updated);
    return updated;
  }

  /// 플래시카드 결과 기록 (known/vague/unknown)
  Future<WordProgress> recordFlashcardAnswer({
    required String wordId,
    required String answer, // 'known', 'vague', 'unknown'
  }) async {
    final current = await getProgress(wordId);
    final updated = SRSCalculator.calculateFromFlashcard(current, answer);
    await saveProgress(updated);
    return updated;
  }

  /// 퀴즈 정답/오답 기록 (SRS 적용)
  Future<WordProgress> recordAnswer({
    required String wordId,
    required bool isCorrect,
  }) async {
    final current = await getProgress(wordId);
    // 퀴즈: 정답 = quality 4, 오답 = quality 1
    final updated = SRSCalculator.calculateSimple(current, isCorrect);
    await saveProgress(updated);
    return updated;
  }

  /// 여러 단어의 진행 상황 가져오기
  Future<Map<String, WordProgress>> getProgressBatch(
      List<String> wordIds) async {
    final result = <String, WordProgress>{};
    for (final id in wordIds) {
      result[id] = await getProgress(id);
    }
    return result;
  }

  /// 오늘 복습할 단어 ID 목록 (SRS 기반)
  Future<List<String>> getTodayReviewWords(List<String> wordIds) async {
    final progressMap = await getProgressBatch(wordIds);
    final now = DateTime.now();

    return progressMap.entries
        .where((e) {
          final p = e.value;
          // 미학습은 제외
          if (p.status == WordStatus.notStarted) return false;
          // 다음 복습 시간이 지났으면 포함
          if (p.nextReview == null) return true;
          return now.isAfter(p.nextReview!);
        })
        .map((e) => e.key)
        .toList();
  }

  /// 새로운 단어 목록 (미학습)
  Future<List<String>> getNewWords(List<String> wordIds) async {
    final progressMap = await getProgressBatch(wordIds);
    return progressMap.entries
        .where((e) => e.value.status == WordStatus.notStarted)
        .map((e) => e.key)
        .toList();
  }

  /// 학습 중인 단어 목록
  Future<List<String>> getLearningWords(List<String> wordIds) async {
    final progressMap = await getProgressBatch(wordIds);
    return progressMap.entries
        .where((e) =>
            e.value.status == WordStatus.learning ||
            e.value.status == WordStatus.reviewing)
        .map((e) => e.key)
        .toList();
  }

  /// 마스터한 단어 목록
  Future<List<String>> getMasteredWords(List<String> wordIds) async {
    final progressMap = await getProgressBatch(wordIds);
    return progressMap.entries
        .where((e) => e.value.status == WordStatus.mastered)
        .map((e) => e.key)
        .toList();
  }

  /// 책/장별 학습 통계
  Future<WordStudyStats> getChapterStats(List<String> wordIds) async {
    final progressMap = await getProgressBatch(wordIds);

    int notStarted = 0;
    int learning = 0;
    int reviewing = 0;
    int mastered = 0;
    int dueToday = 0;

    final now = DateTime.now();

    for (final progress in progressMap.values) {
      switch (progress.status) {
        case WordStatus.notStarted:
          notStarted++;
          break;
        case WordStatus.learning:
          learning++;
          break;
        case WordStatus.reviewing:
          reviewing++;
          break;
        case WordStatus.mastered:
          mastered++;
          break;
      }

      // 오늘 복습 필요 여부
      if (progress.status != WordStatus.notStarted) {
        if (progress.nextReview == null || now.isAfter(progress.nextReview!)) {
          dueToday++;
        }
      }
    }

    return WordStudyStats(
      total: wordIds.length,
      notStarted: notStarted,
      learning: learning + reviewing, // 기존 호환성
      mastered: mastered,
      dueToday: dueToday,
    );
  }

  /// 진행 상황 초기화
  Future<void> resetProgress(String wordId) async {
    await init();
    final key = '$_keyPrefix$wordId';
    await _prefs!.remove(key);
  }

  /// 전체 진행 상황 초기화
  Future<void> resetAllProgress() async {
    await init();
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  /// 학습이 필요한 단어 ID 목록 (미학습 + 학습중)
  Future<List<String>> getWordsToStudy(List<String> wordIds) async {
    final progressMap = await getProgressBatch(wordIds);
    return progressMap.entries
        .where((e) => e.value.status != WordStatus.mastered)
        .map((e) => e.key)
        .toList();
  }

  /// 복습이 필요한 단어 (마지막 학습 후 일정 시간 경과) - 레거시 지원
  Future<List<String>> getWordsToReview(
    List<String> wordIds, {
    Duration reviewInterval = const Duration(days: 3),
  }) async {
    // SRS 기반으로 변경
    return getTodayReviewWords(wordIds);
  }
}

/// 학습 통계
class WordStudyStats {
  final int total;
  final int notStarted;
  final int learning;
  final int mastered;
  final int dueToday; // 오늘 복습 필요

  const WordStudyStats({
    required this.total,
    required this.notStarted,
    required this.learning,
    required this.mastered,
    this.dueToday = 0,
  });

  /// 진행률 (0.0 ~ 1.0)
  double get progressPercent => total > 0 ? mastered / total : 0.0;

  /// 진행률 퍼센트
  int get progressPercentInt => (progressPercent * 100).round();

  /// 학습 시작률
  double get startedPercent => total > 0 ? (learning + mastered) / total : 0.0;
}
