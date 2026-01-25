import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_progress.dart';

/// 단어 학습 진행 서비스
class WordProgressService {
  static const String _keyPrefix = 'word_progress_';
  static const int masteryThreshold = 3; // 연속 3회 정답 시 암기완료

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

  /// 정답 기록
  Future<WordProgress> recordAnswer({
    required String wordId,
    required bool isCorrect,
  }) async {
    final current = await getProgress(wordId);

    final newStreak = isCorrect ? current.streak + 1 : 0;
    final newStatus = _calculateStatus(newStreak, current.totalAttempts + 1);

    final updated = current.copyWith(
      correctCount: current.correctCount + (isCorrect ? 1 : 0),
      totalAttempts: current.totalAttempts + 1,
      lastStudied: DateTime.now(),
      streak: newStreak,
      status: newStatus,
    );

    await saveProgress(updated);
    return updated;
  }

  /// 상태 계산
  WordStatus _calculateStatus(int streak, int totalAttempts) {
    if (streak >= masteryThreshold) {
      return WordStatus.mastered;
    } else if (totalAttempts > 0) {
      return WordStatus.learning;
    }
    return WordStatus.notStarted;
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

  /// 책/장별 학습 통계
  Future<WordStudyStats> getChapterStats(List<String> wordIds) async {
    final progressMap = await getProgressBatch(wordIds);

    int notStarted = 0;
    int learning = 0;
    int mastered = 0;

    for (final progress in progressMap.values) {
      switch (progress.status) {
        case WordStatus.notStarted:
          notStarted++;
          break;
        case WordStatus.learning:
          learning++;
          break;
        case WordStatus.mastered:
          mastered++;
          break;
      }
    }

    return WordStudyStats(
      total: wordIds.length,
      notStarted: notStarted,
      learning: learning,
      mastered: mastered,
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

  /// 복습이 필요한 단어 (마지막 학습 후 일정 시간 경과)
  Future<List<String>> getWordsToReview(
    List<String> wordIds, {
    Duration reviewInterval = const Duration(days: 3),
  }) async {
    final progressMap = await getProgressBatch(wordIds);
    final now = DateTime.now();

    return progressMap.entries.where((e) {
      final lastStudied = e.value.lastStudied;
      if (lastStudied == null) return false;
      return now.difference(lastStudied) >= reviewInterval;
    }).map((e) => e.key).toList();
  }
}

/// 학습 통계
class WordStudyStats {
  final int total;
  final int notStarted;
  final int learning;
  final int mastered;

  const WordStudyStats({
    required this.total,
    required this.notStarted,
    required this.learning,
    required this.mastered,
  });

  /// 진행률 (0.0 ~ 1.0)
  double get progressPercent => total > 0 ? mastered / total : 0.0;

  /// 진행률 퍼센트
  int get progressPercentInt => (progressPercent * 100).round();

  /// 학습 시작률
  double get startedPercent => total > 0 ? (learning + mastered) / total : 0.0;
}
