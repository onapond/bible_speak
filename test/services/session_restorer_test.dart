import 'dart:async';

import 'package:bible_speak/models/session_state.dart';
import 'package:bible_speak/models/user_model.dart';
import 'package:bible_speak/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userA = UserModel(
    uid: 'user-a',
    name: 'Alice',
    email: 'alice@example.com',
    groupId: 'group-a',
    talants: 7,
    completedVerses: ['john:3:16'],
  );
  const userB = UserModel(
    uid: 'user-b',
    name: 'Bob',
    groupId: 'group-b',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('remote profile repairs a stale persisted UID', () async {
    SharedPreferences.setMockInitialValues({
      SessionProfileCache.userIdKey: 'user-a',
    });
    final cache = SessionProfileCache();
    final restorer = SessionRestorer(
      cache: cache,
      loadRemoteProfile: (uid) async => userB,
    );

    final state = await restorer.restore('user-b');

    expect(state.status, SessionStatus.authenticated);
    expect(state.user?.uid, 'user-b');
    expect(state.profileSource, SessionProfileSource.remote);
    expect(await cache.readPersistedUserId(), 'user-b');
    expect((await cache.readProfile('user-b'))?.name, 'Bob');
    expect(await cache.readProfile('user-a'), isNull);
  });

  test('Firestore offline restores only a matching cached profile', () async {
    final cache = SessionProfileCache();
    await cache.writeProfile(userA);
    final restorer = SessionRestorer(
      cache: cache,
      loadRemoteProfile: (uid) async => throw StateError('offline'),
    );

    final state = await restorer.restore('user-a');

    expect(state.status, SessionStatus.authenticated);
    expect(state.user?.uid, 'user-a');
    expect(state.profileSource, SessionProfileSource.cache);
    expect(state.isOffline, isTrue);
    expect(state.error, isA<StateError>());
  });

  test('UID mismatch never restores another account cache offline', () async {
    final cache = SessionProfileCache();
    await cache.writeProfile(userA);
    final restorer = SessionRestorer(
      cache: cache,
      loadRemoteProfile: (uid) async => throw StateError('offline'),
    );

    final state = await restorer.restore('user-b');

    expect(state.status, SessionStatus.recoverableError);
    expect(state.firebaseUserId, 'user-b');
    expect(state.persistedUserId, 'user-a');
    expect(state.user, isNull);
  });

  test('confirmed missing remote profile clears stale active cache', () async {
    final cache = SessionProfileCache();
    await cache.writeProfile(userA);
    final restorer = SessionRestorer(
      cache: cache,
      loadRemoteProfile: (uid) async => null,
    );

    final state = await restorer.restore('user-a');

    expect(state.status, SessionStatus.needsProfile);
    expect(await cache.readPersistedUserId(), isNull);
    expect(await cache.readProfile('user-a'), isNull);
  });

  test('stale restore cannot overwrite the active account cache', () async {
    final cache = SessionProfileCache();
    await cache.writeProfile(userB);
    final restorer = SessionRestorer(
      cache: cache,
      loadRemoteProfile: (uid) async => userA,
      isCurrent: () => false,
    );

    await restorer.restore('user-a');

    expect(await cache.readPersistedUserId(), 'user-b');
    expect((await cache.readProfile('user-b'))?.name, 'Bob');
    expect(await cache.readProfile('user-a'), isNull);
  });

  test('account switch invalidates a delayed account mutation', () async {
    final guard = SessionOperationGuard();
    var firebaseUserId = 'user-a';
    var visibleUser = userA;
    final operationA = guard.activate('user-a');
    final delayedResult = Completer<void>();

    final applyLateResult = () async {
      await delayedResult.future;
      if (guard.isCurrent(
        operationA,
        firebaseUserId: firebaseUserId,
      )) {
        visibleUser = userA.copyWith(talants: 99);
      }
    }();

    firebaseUserId = 'user-b';
    guard.activate('user-b');
    visibleUser = userB;
    delayedResult.complete();
    await applyLateResult;

    expect(visibleUser.uid, 'user-b');
    expect(visibleUser.name, 'Bob');
  });

  test('logout invalidates an operation before Firebase UID clears', () {
    final guard = SessionOperationGuard();
    final operation = guard.activate('user-a');

    guard.invalidate();

    expect(
      guard.isCurrent(operation, firebaseUserId: 'user-a'),
      isFalse,
    );
  });

  test('stale UID cannot reactivate an older account generation', () {
    final guard = SessionOperationGuard();
    final operationB = guard.activate('user-b');

    final staleA = guard.activateIfCurrent(
      'user-a',
      firebaseUserId: 'user-b',
    );

    expect(staleA, isNull);
    expect(
      guard.isCurrent(operationB, firebaseUserId: 'user-b'),
      isTrue,
    );
  });

  test('stale cache write cannot overwrite the next account', () async {
    final preferences = await SharedPreferences.getInstance();
    final firstLoadStarted = Completer<void>();
    final firstPreferences = Completer<SharedPreferences>();
    var loadCount = 0;
    final cache = SessionProfileCache(
      loadPreferences: () {
        loadCount++;
        if (loadCount == 1) {
          firstLoadStarted.complete();
          return firstPreferences.future;
        }
        return Future.value(preferences);
      },
    );
    var activeUserId = 'user-a';

    final writeA = cache.writeProfile(
      userA,
      isCurrent: () => activeUserId == 'user-a',
    );
    await firstLoadStarted.future;

    activeUserId = 'user-b';
    final writeB = cache.writeProfile(
      userB,
      isCurrent: () => activeUserId == 'user-b',
    );
    firstPreferences.complete(preferences);

    expect(await writeA, isFalse);
    expect(await writeB, isTrue);
    expect(await cache.readPersistedUserId(), 'user-b');
    expect((await cache.readProfile('user-b'))?.name, 'Bob');
    expect(await cache.readProfile('user-a'), isNull);
  });

  test('stale signed-out cleanup preserves the next temporary profile',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final cleanupLoadStarted = Completer<void>();
    final cleanupPreferences = Completer<SharedPreferences>();
    var loadCount = 0;
    final cache = SessionProfileCache(
      loadPreferences: () {
        loadCount++;
        if (loadCount == 1) {
          cleanupLoadStarted.complete();
          return cleanupPreferences.future;
        }
        return Future.value(preferences);
      },
    );
    String? firebaseUserId;

    final clearOldSession = cache.clearSessionData(
      isCurrent: () => firebaseUserId == null,
    );
    await cleanupLoadStarted.future;

    firebaseUserId = 'user-b';
    final writeNewProfile = cache.writeTemporaryProfile(
      userId: 'user-b',
      name: 'Bob',
      email: 'bob@example.com',
      isCurrent: () => firebaseUserId == 'user-b',
    );
    cleanupPreferences.complete(preferences);

    expect(await clearOldSession, isFalse);
    expect(await writeNewProfile, isTrue);
    expect(await cache.readTemporaryProfile(), {
      'uid': 'user-b',
      'name': 'Bob',
      'email': 'bob@example.com',
      'photo': null,
    });
  });

  test('session profile cache round-trips JSON-safe user data', () async {
    final cache = SessionProfileCache();
    await cache.writeProfile(userA);

    final restored = await cache.readProfile('user-a');

    expect(restored?.uid, userA.uid);
    expect(restored?.name, userA.name);
    expect(restored?.email, userA.email);
    expect(restored?.talants, userA.talants);
    expect(restored?.completedVerses, userA.completedVerses);
  });

  test('profile completion rejects stale or unauthenticated temp UID', () {
    expect(
      resolveProfileCompletionUserId(
        firebaseUserId: 'user-b',
        temporaryUserId: 'user-a',
      ),
      isNull,
    );
    expect(
      resolveProfileCompletionUserId(
        firebaseUserId: null,
        temporaryUserId: 'user-a',
      ),
      isNull,
    );
    expect(
      resolveProfileCompletionUserId(
        firebaseUserId: 'user-a',
        temporaryUserId: 'user-a',
      ),
      'user-a',
    );
  });
}
