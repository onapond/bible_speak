import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/verse_progress.dart';
import '../models/learning_stage.dart';
import '../services/progress_service.dart';

part 'progress_provider.g.dart';

/// ProgressService 싱글톤 인스턴스
@Riverpod(keepAlive: true)
ProgressService progressService(Ref ref) => ProgressService();

/// Progress 관리 Notifier
@Riverpod(keepAlive: true)
class ProgressNotifier extends _$ProgressNotifier {
  late final ProgressService _progressService;
  bool _initialized = false;

  @override
  FutureOr<void> build() async {
    _progressService = ref.watch(progressServiceProvider);
    if (!_initialized) {
      await _progressService.init();
      _initialized = true;
    }
  }

  /// 구절 점수 저장
  Future<VerseProgress> saveScore({
    required String book,
    required int chapter,
    required int verse,
    required double score,
    LearningStage? stage,
  }) async {
    return await _progressService.saveScore(
      book: book,
      chapter: chapter,
      verse: verse,
      score: score,
      stage: stage,
    );
  }

  /// 챕터 기록 초기화
  Future<void> resetChapterScores({
    required String book,
    required int chapter,
    required int totalVerses,
  }) async {
    await _progressService.resetChapterScores(
      book: book,
      chapter: chapter,
      totalVerses: totalVerses,
    );
  }

  /// 캐시 초기화
  void clearCache() {
    _progressService.clearCache();
  }
}

/// 특정 구절의 진행 상태 (Family Provider)
@riverpod
Future<VerseProgress> verseProgress(
  Ref ref, {
  required String book,
  required int chapter,
  required int verse,
}) async {
  final service = ref.watch(progressServiceProvider);
  return await service.getVerseProgress(
    book: book,
    chapter: chapter,
    verse: verse,
  );
}

/// 챕터 진행 상태 (Family Provider)
@riverpod
Future<ChapterProgress> chapterProgress(
  Ref ref, {
  required String book,
  required int chapter,
  required int totalVerses,
}) async {
  final service = ref.watch(progressServiceProvider);
  return await service.getChapterProgress(
    book: book,
    chapter: chapter,
    totalVerses: totalVerses,
  );
}

/// 챕터별 점수 맵 (Family Provider)
@riverpod
Future<Map<int, double>> chapterScores(
  Ref ref, {
  required String book,
  required int chapter,
  required int totalVerses,
}) async {
  final service = ref.watch(progressServiceProvider);
  return await service.getChapterScores(
    book: book,
    chapter: chapter,
    totalVerses: totalVerses,
  );
}
