import 'package:bible_speak/models/learning_stage.dart';
import 'package:bible_speak/models/verse_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerseProgress completion', () {
    test('does not complete below the final-stage threshold', () {
      final progress = VerseProgress.empty(
        bookId: 'malachi',
        chapter: 1,
        verse: 2,
      ).withScoreUpdate(
        LearningStage.realSpeak,
        LearningStage.realSpeak.passThreshold - 0.01,
      );

      expect(progress.isCompleted, isFalse);
      expect(progress.completedAt, isNull);
    });

    test('completes at the final-stage threshold and keeps completion', () {
      final completed = VerseProgress.empty(
        bookId: 'malachi',
        chapter: 1,
        verse: 2,
      ).withScoreUpdate(
        LearningStage.realSpeak,
        LearningStage.realSpeak.passThreshold,
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      final completedAt = completed.completedAt;
      final retried = completed.withScoreUpdate(LearningStage.realSpeak, 0);
      expect(retried.isCompleted, isTrue);
      expect(retried.completedAt, completedAt);
    });

    test('passing earlier stages alone does not mark the verse complete', () {
      final progress = VerseProgress.empty(
        bookId: 'malachi',
        chapter: 1,
        verse: 2,
      ).withScoreUpdate(
        LearningStage.listenRepeat,
        LearningStage.listenRepeat.passThreshold,
      );

      expect(progress.currentStage, LearningStage.keyExpressions);
      expect(progress.isCompleted, isFalse);
    });
  });
}
