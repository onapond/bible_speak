import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_progress.dart';

/// 단어 학습 진행 서비스 (SRS 지원)
class WordProgressService {
  static const String _legacyKeyPrefix = 'word_progress_';
  static const String _scopedKeyRoot = 'word_progress_v2.';
  static const String _legacyQuarantineScope = 'legacy';

  WordProgressService({String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? _firebaseUserId;

  final String? Function() _currentUserId;

  SharedPreferences? _prefs;
  Future<void>? _initialization;

  static String? _firebaseUserId() => FirebaseAuth.instance.currentUser?.uid;

  /// Firebase UID가 없는 상태도 별도 guest 공간으로 격리한다.
  /// 콜백을 매 접근마다 평가해 같은 서비스 인스턴스에서 계정이 바뀌어도
  /// 이전 사용자의 진행도를 재사용하지 않는다.
  String _scopeForUserId(String? userId) {
    if (userId == null || userId.isEmpty) return 'guest';
    final encodedUserId =
        base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return 'user.$encodedUserId';
  }

  String _currentScope() => _scopeForUserId(_currentUserId());

  String _scopedKeyPrefix(String scope) => '$_scopedKeyRoot$scope.';

  String _progressKey(String scope, String wordId) =>
      '${_scopedKeyPrefix(scope)}$wordId';

  /// 초기화
  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateLegacyProgress();
  }

  /// 계정 정보가 없던 구버전 키는 어느 계정에도 자동 귀속하지 않는다.
  /// 원본은 격리 공간에 보존하되 명시적인 소유자 확인 절차가 생기기 전까지
  /// 로그인 사용자나 guest 진행도로 노출하지 않는다.
  Future<void> _migrateLegacyProgress() async {
    final prefs = _prefs!;
    final legacyKeys = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_legacyKeyPrefix) &&
              !key.startsWith(_scopedKeyRoot),
        )
        .toList(growable: false);
    if (legacyKeys.isEmpty) return;

    final targetPrefix = _scopedKeyPrefix(_legacyQuarantineScope);

    for (final legacyKey in legacyKeys) {
      final value = prefs.getString(legacyKey);
      if (value == null) continue;

      final wordId = legacyKey.substring(_legacyKeyPrefix.length);
      final targetKey = '$targetPrefix$wordId';
      final copied = prefs.containsKey(targetKey) ||
          await prefs.setString(targetKey, value);
      if (copied) await prefs.remove(legacyKey);
    }
  }

  /// 단어 진행 상황 가져오기
  Future<WordProgress> getProgress(String wordId) async {
    final scope = _currentScope();
    return _getProgressForScope(scope, wordId);
  }

  Future<WordProgress> _getProgressForScope(
    String scope,
    String wordId,
  ) async {
    await init();

    final key = _progressKey(scope, wordId);
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
    final scope = _currentScope();
    await _saveProgressForScope(scope, progress);
  }

  Future<void> _saveProgressForScope(
    String scope,
    WordProgress progress,
  ) async {
    await init();

    final key = _progressKey(scope, progress.wordId);
    final jsonStr = jsonEncode(progress.toJson());
    await _prefs!.setString(key, jsonStr);
  }

  /// SRS 기반 정답 기록
  Future<WordProgress> recordAnswerWithSRS({
    required String wordId,
    required int quality, // 0-5
  }) async {
    final scope = _currentScope();
    final current = await _getProgressForScope(scope, wordId);
    final updated = SRSCalculator.calculate(current, quality);
    await _saveProgressForScope(scope, updated);
    return updated;
  }

  /// 플래시카드 결과 기록 (known/vague/unknown)
  Future<WordProgress> recordFlashcardAnswer({
    required String wordId,
    required String answer, // 'known', 'vague', 'unknown'
  }) async {
    final scope = _currentScope();
    final current = await _getProgressForScope(scope, wordId);
    final updated = SRSCalculator.calculateFromFlashcard(current, answer);
    await _saveProgressForScope(scope, updated);
    return updated;
  }

  /// 퀴즈 정답/오답 기록 (SRS 적용)
  Future<WordProgress> recordAnswer({
    required String wordId,
    required bool isCorrect,
  }) async {
    final scope = _currentScope();
    final current = await _getProgressForScope(scope, wordId);
    // 퀴즈: 정답 = quality 4, 오답 = quality 1
    final updated = SRSCalculator.calculateSimple(current, isCorrect);
    await _saveProgressForScope(scope, updated);
    return updated;
  }

  /// 여러 단어의 진행 상황 가져오기
  Future<Map<String, WordProgress>> getProgressBatch(
      List<String> wordIds) async {
    final scope = _currentScope();
    final result = <String, WordProgress>{};
    for (final id in wordIds) {
      result[id] = await _getProgressForScope(scope, id);
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
    final scope = _currentScope();
    await init();
    final key = _progressKey(scope, wordId);
    await _prefs!.remove(key);
  }

  /// 현재 사용자에 해당하는 전체 진행 상황 초기화
  Future<void> resetAllProgress() async {
    final scope = _currentScope();
    await init();
    final prefix = _scopedKeyPrefix(scope);
    final keys = _prefs!
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
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
