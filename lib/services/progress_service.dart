import 'package:shared_preferences/shared_preferences.dart';

/// 학습 진행 서비스
/// - 구절별 최고 점수 저장/조회
/// - 진척도 계산
class ProgressService {
  static const String _keyPrefix = 'bible_speak_verse_';
  static const double masteryThreshold = 80.0; // 암기 완료 기준 점수

  SharedPreferences? _prefs;

  /// 초기화
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    print('📊 ProgressService 초기화 완료');
  }

  /// 구절별 최고 점수 저장 (기존보다 높을 때만)
  Future<bool> saveScore({
    required String book,
    required int chapter,
    required int verse,
    required double score,
  }) async {
    if (_prefs == null) await init();

    final key = '${_keyPrefix}${book}_${chapter}_$verse';
    final currentBest = _prefs!.getDouble(key) ?? 0.0;

    if (score > currentBest) {
      await _prefs!.setDouble(key, score);
      print('🏆 새 최고 점수! $book $chapter:$verse - ${currentBest.toStringAsFixed(0)}% → ${score.toStringAsFixed(0)}%');
      return true;
    }

    print('📊 기존 기록 유지. $book $chapter:$verse - ${currentBest.toStringAsFixed(0)}%');
    return false;
  }

  /// 구절별 최고 점수 조회
  Future<double> getScore({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    if (_prefs == null) await init();

    final key = '${_keyPrefix}${book}_${chapter}_$verse';
    return _prefs!.getDouble(key) ?? 0.0;
  }

  /// 챕터 전체 점수 조회
  Future<Map<int, double>> getChapterScores({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    if (_prefs == null) await init();

    final scores = <int, double>{};
    for (int i = 1; i <= totalVerses; i++) {
      scores[i] = await getScore(book: book, chapter: chapter, verse: i);
    }
    return scores;
  }

  /// 암기 완료된 구절 수
  Future<int> getMasteredCount({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    final scores = await getChapterScores(
      book: book,
      chapter: chapter,
      totalVerses: totalVerses,
    );
    return scores.values.where((score) => score >= masteryThreshold).length;
  }

  /// 진척도 (0.0 ~ 1.0)
  Future<double> getProgress({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    final masteredCount = await getMasteredCount(
      book: book,
      chapter: chapter,
      totalVerses: totalVerses,
    );
    return masteredCount / totalVerses;
  }

  /// 구절이 암기 완료 상태인지 확인
  Future<bool> isMastered({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final score = await getScore(book: book, chapter: chapter, verse: verse);
    return score >= masteryThreshold;
  }

  /// 챕터 기록 초기화
  Future<void> resetChapterScores({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    if (_prefs == null) await init();

    for (int i = 1; i <= totalVerses; i++) {
      final key = '${_keyPrefix}${book}_${chapter}_$i';
      await _prefs!.remove(key);
    }
    print('🗑️ $book $chapter장 학습 기록 초기화 완료');
  }

  /// 모든 기록 초기화
  Future<void> resetAllScores() async {
    if (_prefs == null) await init();

    final keys = _prefs!.getKeys().where((key) => key.startsWith(_keyPrefix));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
    print('🗑️ 모든 학습 기록 초기화 완료');
  }
}
