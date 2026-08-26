import 'dart:convert';

import 'package:bible_speak/models/word_progress.dart';
import 'package:bible_speak/services/word_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WordProgressService account isolation', () {
    test('keeps progress separate when the active account changes', () async {
      String? activeUserId = 'user-a';
      final service = WordProgressService(
        currentUserId: () => activeUserId,
      );

      await service.saveProgress(
        const WordProgress(
          wordId: 'malachi-1-1-word-1',
          correctCount: 3,
          totalAttempts: 4,
          status: WordStatus.reviewing,
        ),
      );

      activeUserId = 'user-b';
      final userBInitial = await service.getProgress('malachi-1-1-word-1');
      expect(userBInitial.status, WordStatus.notStarted);
      expect(userBInitial.totalAttempts, 0);

      await service.saveProgress(
        const WordProgress(
          wordId: 'malachi-1-1-word-1',
          correctCount: 1,
          totalAttempts: 2,
          status: WordStatus.learning,
        ),
      );

      activeUserId = 'user-a';
      final userAProgress = await service.getProgress('malachi-1-1-word-1');
      expect(userAProgress.correctCount, 3);
      expect(userAProgress.totalAttempts, 4);
      expect(userAProgress.status, WordStatus.reviewing);

      activeUserId = 'user-b';
      final userBProgress = await service.getProgress('malachi-1-1-word-1');
      expect(userBProgress.correctCount, 1);
      expect(userBProgress.totalAttempts, 2);
      expect(userBProgress.status, WordStatus.learning);
    });

    test('reset all removes only the active account progress', () async {
      String? activeUserId = 'user-a';
      final service = WordProgressService(
        currentUserId: () => activeUserId,
      );

      await service.saveProgress(
        const WordProgress(
          wordId: 'word-1',
          totalAttempts: 1,
          status: WordStatus.learning,
        ),
      );

      activeUserId = 'user-b';
      await service.saveProgress(
        const WordProgress(
          wordId: 'word-1',
          totalAttempts: 2,
          status: WordStatus.reviewing,
        ),
      );
      await service.resetAllProgress();

      expect((await service.getProgress('word-1')).totalAttempts, 0);

      activeUserId = 'user-a';
      expect((await service.getProgress('word-1')).totalAttempts, 1);
    });

    test('reset prefix cannot collide with a longer user id', () async {
      String? activeUserId = 'user';
      final service = WordProgressService(
        currentUserId: () => activeUserId,
      );

      await service.saveProgress(
        const WordProgress(
          wordId: 'word-1',
          totalAttempts: 1,
          status: WordStatus.learning,
        ),
      );

      activeUserId = 'user_with_suffix';
      await service.saveProgress(
        const WordProgress(
          wordId: 'word-1',
          totalAttempts: 2,
          status: WordStatus.reviewing,
        ),
      );

      activeUserId = 'user';
      await service.resetAllProgress();

      activeUserId = 'user_with_suffix';
      expect((await service.getProgress('word-1')).totalAttempts, 2);
    });

    test('guest progress does not leak into an authenticated account',
        () async {
      String? activeUserId;
      final service = WordProgressService(
        currentUserId: () => activeUserId,
      );

      await service.saveProgress(
        const WordProgress(
          wordId: 'word-1',
          totalAttempts: 1,
          status: WordStatus.learning,
        ),
      );

      activeUserId = 'user-a';
      expect(
          (await service.getProgress('word-1')).status, WordStatus.notStarted);

      activeUserId = null;
      expect((await service.getProgress('word-1')).totalAttempts, 1);
    });

    test('quarantines ownerless legacy progress from authenticated users',
        () async {
      SharedPreferences.setMockInitialValues({
        'bible_speak_userId': 'user-b',
        'word_progress_word-1': jsonEncode(
          const WordProgress(
            wordId: 'word-1',
            totalAttempts: 7,
            status: WordStatus.reviewing,
          ).toJson(),
        ),
      });
      String? activeUserId = 'user-b';
      final service = WordProgressService(
        currentUserId: () => activeUserId,
      );

      expect((await service.getProgress('word-1')).totalAttempts, 0);

      activeUserId = null;
      expect((await service.getProgress('word-1')).totalAttempts, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('word_progress_word-1'), isFalse);
      final quarantinedKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('word_progress_v2.legacy.'))
          .toList();
      expect(quarantinedKeys, hasLength(1));
      final quarantinedJson = jsonDecode(
        prefs.getString(quarantinedKeys.single)!,
      ) as Map<String, dynamic>;
      expect(quarantinedJson['totalAttempts'], 7);
    });

    test('keeps a read-modify-write answer in its starting account', () async {
      var userLookupCount = 0;
      final service = WordProgressService(
        currentUserId: () {
          userLookupCount++;
          return userLookupCount == 1 ? 'user-a' : 'user-b';
        },
      );

      await service.recordAnswer(wordId: 'word-1', isCorrect: true);

      expect(userLookupCount, 1);
      final userAService = WordProgressService(
        currentUserId: () => 'user-a',
      );
      final userBService = WordProgressService(
        currentUserId: () => 'user-b',
      );
      expect((await userAService.getProgress('word-1')).totalAttempts, 1);
      expect((await userBService.getProgress('word-1')).totalAttempts, 0);
    });
  });
}
