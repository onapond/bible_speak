import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/verse_progress.dart';
import '../models/learning_stage.dart';

/// 학습 진행 서비스
/// - Firestore 클라우드 저장 (로그인 시)
/// - SharedPreferences 로컬 저장 (오프라인/백업)
/// - 구절별 3단계 학습 진행 관리
class ProgressService {
  static const String _localKeyPrefix = 'bible_speak_verse_';
  static const double masteryThreshold = 85.0; // Stage 3 완료 기준

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  SharedPreferences? _prefs;

  // 메모리 캐시
  final Map<String, VerseProgress> _cache = {};

  /// 초기화
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 현재 사용자 ID
  String? get _userId => _auth.currentUser?.uid;

  /// Firestore 진행 문서 참조
  DocumentReference? _progressDoc(String bookId) {
    if (_userId == null) return null;
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('progress')
        .doc(bookId);
  }

  /// 구절 점수 저장 (3단계 학습 지원)
  Future<VerseProgress> saveScore({
    required String book,
    required int chapter,
    required int verse,
    required double score,
    LearningStage? stage,
  }) async {
    if (_prefs == null) await init();

    final verseKey = '${book}_${chapter}_$verse';

    // 현재 진행 상태 가져오기
    VerseProgress current = await getVerseProgress(
      book: book,
      chapter: chapter,
      verse: verse,
    );

    // 스테이지 지정 없으면 현재 스테이지 사용
    final targetStage = stage ?? current.currentStage;

    // 점수 업데이트
    final updated = current.withScoreUpdate(targetStage, score);

    // 캐시 업데이트
    _cache[verseKey] = updated;

    // Firestore 저장 (로그인 시)
    await _saveToFirestore(book, chapter, verse, updated);

    // 로컬 백업 저장
    await _saveToLocal(book, chapter, verse, updated);

    return updated;
  }

  /// Firestore에 저장
  Future<void> _saveToFirestore(
    String book,
    int chapter,
    int verse,
    VerseProgress progress,
  ) async {
    final doc = _progressDoc(book);
    if (doc == null) return;

    try {
      await doc.set({
        'chapters': {
          chapter.toString(): {
            'verses': {
              verse.toString(): progress.toMap(),
            },
          },
        },
      }, SetOptions(merge: true));
    } catch (e) {
      // 오프라인 등 오류 시 무시 (로컬에 저장됨)
    }
  }

  /// 로컬에 저장
  Future<void> _saveToLocal(
    String book,
    int chapter,
    int verse,
    VerseProgress progress,
  ) async {
    if (_prefs == null) return;

    final key = '$_localKeyPrefix${book}_${chapter}_$verse';

    // 간단한 형태로 저장 (최고점수, 현재 스테이지)
    await _prefs!.setDouble('${key}_best', progress.overallBestScore);
    await _prefs!.setInt('${key}_stage', progress.currentStage.stageNumber);
    await _prefs!.setBool('${key}_completed', progress.isCompleted);

    // 각 스테이지별 점수도 저장
    for (final entry in progress.stages.entries) {
      final stageKey = '${key}_s${entry.key.stageNumber}';
      await _prefs!.setDouble('${stageKey}_best', entry.value.bestScore);
      await _prefs!.setInt('${stageKey}_attempts', entry.value.attempts);
    }
  }

  /// 구절 진행 상태 가져오기
  Future<VerseProgress> getVerseProgress({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    if (_prefs == null) await init();

    final verseKey = '${book}_${chapter}_$verse';

    // 캐시 확인
    if (_cache.containsKey(verseKey)) {
      return _cache[verseKey]!;
    }

    // Firestore에서 가져오기 시도
    VerseProgress? progress = await _loadFromFirestore(book, chapter, verse);

    // Firestore에 없으면 로컬에서 가져오기
    progress ??= await _loadFromLocal(book, chapter, verse);

    // 여전히 없으면 빈 상태 생성
    progress ??= VerseProgress.empty(
      bookId: book,
      chapter: chapter,
      verse: verse,
    );

    // 캐시에 저장
    _cache[verseKey] = progress;

    return progress;
  }

  /// Firestore에서 로드
  Future<VerseProgress?> _loadFromFirestore(
    String book,
    int chapter,
    int verse,
  ) async {
    final doc = _progressDoc(book);
    if (doc == null) return null;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return null;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return null;

      final chapters = data['chapters'] as Map<String, dynamic>?;
      if (chapters == null) return null;

      final chapterData = chapters[chapter.toString()] as Map<String, dynamic>?;
      if (chapterData == null) return null;

      final verses = chapterData['verses'] as Map<String, dynamic>?;
      if (verses == null) return null;

      final verseData = verses[verse.toString()] as Map<String, dynamic>?;
      if (verseData == null) return null;

      return VerseProgress.fromMap(
        verseData,
        bookId: book,
        chapter: chapter,
        verse: verse,
      );
    } catch (e) {
      return null;
    }
  }

  /// 로컬에서 로드
  Future<VerseProgress?> _loadFromLocal(
    String book,
    int chapter,
    int verse,
  ) async {
    if (_prefs == null) return null;

    final key = '$_localKeyPrefix${book}_${chapter}_$verse';
    final bestScore = _prefs!.getDouble('${key}_best');

    if (bestScore == null) return null;

    final stageNumber = _prefs!.getInt('${key}_stage') ?? 1;
    final isCompleted = _prefs!.getBool('${key}_completed') ?? false;

    // 스테이지별 진행 상태 복원
    final stages = <LearningStage, StageProgress>{};
    for (final stage in LearningStage.values) {
      final stageKey = '${key}_s${stage.stageNumber}';
      final stageBest = _prefs!.getDouble('${stageKey}_best');
      if (stageBest != null) {
        stages[stage] = StageProgress(
          attempts: _prefs!.getInt('${stageKey}_attempts') ?? 1,
          bestScore: stageBest,
          lastScore: stageBest,
        );
      }
    }

    return VerseProgress(
      bookId: book,
      chapter: chapter,
      verse: verse,
      currentStage: LearningStage.fromNumber(stageNumber),
      stages: stages,
      isCompleted: isCompleted,
    );
  }

  /// 챕터 전체 진행 상태 가져오기
  Future<ChapterProgress> getChapterProgress({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    int completedCount = 0;
    int inProgressCount = 0;
    double totalScore = 0;
    int scoredVerses = 0;

    for (int v = 1; v <= totalVerses; v++) {
      final progress = await getVerseProgress(
        book: book,
        chapter: chapter,
        verse: v,
      );

      if (progress.isCompleted) {
        completedCount++;
      } else if (progress.stages.isNotEmpty) {
        inProgressCount++;
      }

      if (progress.overallBestScore > 0) {
        totalScore += progress.overallBestScore;
        scoredVerses++;
      }
    }

    return ChapterProgress(
      bookId: book,
      chapter: chapter,
      totalVerses: totalVerses,
      completedVerses: completedCount,
      inProgressVerses: inProgressCount,
      averageScore: scoredVerses > 0 ? totalScore / scoredVerses : 0,
    );
  }

  /// 구절별 최고 점수 조회 (하위 호환용)
  Future<double> getScore({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final progress = await getVerseProgress(
      book: book,
      chapter: chapter,
      verse: verse,
    );
    return progress.overallBestScore;
  }

  /// 챕터 전체 점수 조회 (하위 호환용)
  Future<Map<int, double>> getChapterScores({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    final scores = <int, double>{};
    for (int i = 1; i <= totalVerses; i++) {
      scores[i] = await getScore(book: book, chapter: chapter, verse: i);
    }
    return scores;
  }

  /// 암기 완료된 구절 수 (하위 호환용)
  Future<int> getMasteredCount({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    final chapterProgress = await getChapterProgress(
      book: book,
      chapter: chapter,
      totalVerses: totalVerses,
    );
    return chapterProgress.completedVerses;
  }

  /// 진척도 (0.0 ~ 1.0) (하위 호환용)
  Future<double> getProgress({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    final chapterProgress = await getChapterProgress(
      book: book,
      chapter: chapter,
      totalVerses: totalVerses,
    );
    return chapterProgress.progressRate;
  }

  /// 구절이 암기 완료 상태인지 확인 (하위 호환용)
  Future<bool> isMastered({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final progress = await getVerseProgress(
      book: book,
      chapter: chapter,
      verse: verse,
    );
    return progress.isCompleted;
  }

  /// 로컬 → Firestore 마이그레이션
  Future<void> migrateLocalToFirestore() async {
    if (_prefs == null) await init();
    if (_userId == null) return;

    final keys = _prefs!.getKeys()
        .where((k) => k.startsWith(_localKeyPrefix) && k.endsWith('_best'));

    for (final key in keys) {
      // 키에서 book, chapter, verse 추출
      final parts = key
          .replaceFirst(_localKeyPrefix, '')
          .replaceFirst('_best', '')
          .split('_');

      if (parts.length >= 3) {
        final book = parts[0];
        final chapter = int.tryParse(parts[1]);
        final verse = int.tryParse(parts[2]);

        if (chapter != null && verse != null) {
          final progress = await _loadFromLocal(book, chapter, verse);
          if (progress != null) {
            await _saveToFirestore(book, chapter, verse, progress);
          }
        }
      }
    }
  }

  /// 캐시 초기화
  void clearCache() {
    _cache.clear();
  }

  /// 챕터 기록 초기화
  Future<void> resetChapterScores({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    if (_prefs == null) await init();

    // 로컬 삭제
    for (int i = 1; i <= totalVerses; i++) {
      final key = '$_localKeyPrefix${book}_${chapter}_$i';
      final keysToRemove = _prefs!.getKeys()
          .where((k) => k.startsWith(key));
      for (final k in keysToRemove) {
        await _prefs!.remove(k);
      }

      // 캐시 삭제
      _cache.remove('${book}_${chapter}_$i');
    }

    // Firestore 삭제
    final doc = _progressDoc(book);
    if (doc != null) {
      try {
        await doc.update({
          'chapters.$chapter': FieldValue.delete(),
        });
      } catch (e) {
        // 무시
      }
    }
  }
}
