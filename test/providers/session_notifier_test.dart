import 'dart:async';

import 'package:bible_speak/models/session_state.dart';
import 'package:bible_speak/models/user_model.dart';
import 'package:bible_speak/providers/auth_provider.dart';
import 'package:bible_speak/providers/core_providers.dart';
import 'package:bible_speak/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userA = UserModel(
    uid: 'user-a',
    name: 'Alice',
    groupId: 'group-a',
  );
  const userB = UserModel(
    uid: 'user-b',
    name: 'Bob',
    groupId: 'group-b',
  );

  test('delayed Firebase restore stays loading until a definitive event',
      () async {
    final authEvents = StreamController<String?>();
    final restore = Completer<SessionState>();
    final gateway = _FakeAuthSessionGateway(
      restoreSessionHandler: (uid) => restore.future,
    );
    final container = _container(authEvents, gateway);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    expect(
      container.read(sessionNotifierProvider).status,
      SessionStatus.loading,
    );

    authEvents.add('user-a');
    await pumpEventQueue();
    expect(container.read(sessionNotifierProvider).firebaseUserId, 'user-a');
    expect(
        container.read(sessionNotifierProvider).status, SessionStatus.loading);

    restore.complete(
      SessionState.authenticated(
        user: userA,
        source: SessionProfileSource.remote,
      ),
    );
    await pumpEventQueue();

    expect(
      container.read(sessionNotifierProvider).status,
      SessionStatus.authenticated,
    );
  });

  test('restores an auth value resolved before SessionNotifier starts',
      () async {
    final authEvents = StreamController<String?>();
    final gateway = _FakeAuthSessionGateway(
      restoreSessionHandler: (uid) async => SessionState.authenticated(
        user: userA,
        source: SessionProfileSource.remote,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authUserIdChangesProvider.overrideWith((ref) => authEvents.stream),
        authSessionGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    final authSubscription = container.listen(
      authUserIdChangesProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(authSubscription.close);
    authEvents.add('user-a');
    await pumpEventQueue();

    container.read(sessionNotifierProvider);
    await pumpEventQueue();

    expect(gateway.restoredUserIds, ['user-a']);
    expect(container.read(sessionNotifierProvider).user?.uid, 'user-a');
  });

  test('Firebase UID restores a profile when service currentUser starts null',
      () async {
    final authEvents = StreamController<String?>();
    late final _FakeAuthSessionGateway gateway;
    gateway = _FakeAuthSessionGateway(
      restoreSessionHandler: (uid) async {
        expect(gateway.currentUser, isNull);
        return SessionState.authenticated(
          user: userA,
          source: SessionProfileSource.remote,
        );
      },
    );
    final container = _container(authEvents, gateway);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    authEvents.add('user-a');
    await pumpEventQueue();

    expect(gateway.restoredUserIds, ['user-a']);
    expect(container.read(sessionNotifierProvider).user?.uid, 'user-a');
  });

  test('confirmed signed-out event clears local session before routing',
      () async {
    final authEvents = StreamController<String?>();
    final gateway = _FakeAuthSessionGateway();
    final container = _container(authEvents, gateway);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    authEvents.add(null);
    await pumpEventQueue();

    expect(gateway.clearLocalSessionCalls, 1);
    expect(
      container.read(sessionNotifierProvider).status,
      SessionStatus.signedOut,
    );
  });

  test('unexpected restore failure becomes a recoverable state', () async {
    final authEvents = StreamController<String?>();
    final gateway = _FakeAuthSessionGateway(
      restoreSessionHandler: (uid) => throw StateError('restore failed'),
    );
    final container = _container(authEvents, gateway);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    authEvents.add('user-a');
    await pumpEventQueue();

    final state = container.read(sessionNotifierProvider);
    expect(state.status, SessionStatus.recoverableError);
    expect(state.firebaseUserId, 'user-a');
    expect(state.error, isA<StateError>());
  });

  test('offline cached profile remains authenticated', () async {
    final authEvents = StreamController<String?>();
    final gateway = _FakeAuthSessionGateway(
      restoreSessionHandler: (uid) async => SessionState.authenticated(
        user: userA,
        source: SessionProfileSource.cache,
        warning: StateError('offline'),
      ),
    );
    final container = _container(authEvents, gateway);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    authEvents.add('user-a');
    await pumpEventQueue();

    final state = container.read(sessionNotifierProvider);
    expect(state.status, SessionStatus.authenticated);
    expect(state.isOffline, isTrue);
    expect(state.user?.uid, 'user-a');
  });

  test('late account A restore cannot overwrite account B', () async {
    final authEvents = StreamController<String?>();
    final restoreA = Completer<SessionState>();
    final restoreB = Completer<SessionState>();
    final gateway = _FakeAuthSessionGateway(
      restoreSessionHandler: (uid) {
        return uid == 'user-a' ? restoreA.future : restoreB.future;
      },
    );
    final container = _container(authEvents, gateway);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    authEvents.add('user-a');
    await pumpEventQueue();
    authEvents.add('user-b');
    await pumpEventQueue();

    restoreB.complete(
      SessionState.authenticated(
        user: userB,
        source: SessionProfileSource.remote,
      ),
    );
    await pumpEventQueue();
    restoreA.complete(
      SessionState.authenticated(
        user: userA,
        source: SessionProfileSource.remote,
      ),
    );
    await pumpEventQueue();

    expect(container.read(sessionNotifierProvider).user?.uid, 'user-b');
  });

  test('logout invalidates an in-flight profile restore', () async {
    final authEvents = StreamController<String?>();
    final restore = Completer<SessionState>();
    final signOut = Completer<void>();
    final gateway = _FakeAuthSessionGateway(
      restoreSessionHandler: (uid) => restore.future,
      signOutHandler: () => signOut.future,
    );
    final container = _container(authEvents, gateway);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    authEvents.add('user-a');
    await pumpEventQueue();
    final signOutFuture =
        container.read(sessionNotifierProvider.notifier).signOut();

    restore.complete(
      SessionState.authenticated(
        user: userA,
        source: SessionProfileSource.remote,
      ),
    );
    await pumpEventQueue();
    expect(
      container.read(sessionNotifierProvider).status,
      SessionStatus.loading,
    );

    signOut.complete();
    await signOutFuture;
    expect(
      container.read(sessionNotifierProvider).status,
      SessionStatus.signedOut,
    );
  });

  test('auth stream error remains recoverable instead of signing out',
      () async {
    final authEvents = StreamController<String?>();
    final gateway = _FakeAuthSessionGateway();
    final container = _container(authEvents, gateway);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    authEvents.addError(StateError('temporary auth failure'));
    await pumpEventQueue();

    expect(
      container.read(sessionNotifierProvider).status,
      SessionStatus.recoverableError,
    );
  });
}

ProviderContainer _container(
  StreamController<String?> authEvents,
  _FakeAuthSessionGateway gateway,
) {
  final container = ProviderContainer(
    overrides: [
      authUserIdChangesProvider.overrideWith((ref) => authEvents.stream),
      authSessionGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container.read(sessionNotifierProvider);
  return container;
}

class _FakeAuthSessionGateway implements AuthSessionGateway {
  _FakeAuthSessionGateway({
    this.restoreSessionHandler,
    this.signOutHandler,
  });

  final Future<SessionState> Function(String uid)? restoreSessionHandler;
  final Future<void> Function()? signOutHandler;
  final List<String> restoredUserIds = [];
  int clearLocalSessionCalls = 0;

  @override
  UserModel? currentUser;

  @override
  Future<SessionState> restoreSession(String firebaseUserId) async {
    restoredUserIds.add(firebaseUserId);
    final handler = restoreSessionHandler;
    if (handler == null) {
      return SessionState.recoverableError(
        firebaseUserId: firebaseUserId,
        error: StateError('No restore handler'),
      );
    }
    final restored = await handler(firebaseUserId);
    currentUser = restored.user;
    return restored;
  }

  @override
  Future<void> clearLocalSession() async {
    clearLocalSessionCalls++;
    currentUser = null;
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    await signOutHandler?.call();
  }

  @override
  Future<AuthResult> signInWithGoogle() async =>
      AuthResult.error('unused in this test');

  @override
  Future<AuthResult> signInWithApple() async =>
      AuthResult.error('unused in this test');

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      AuthResult.error('unused in this test');

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async =>
      AuthResult.error('unused in this test');

  @override
  Future<UserModel?> completeProfile({
    required String name,
    String? groupId,
  }) async =>
      null;

  @override
  Future<void> refreshUser() async {}

  @override
  Future<bool> addTalant({
    required String book,
    required int chapter,
    required int verse,
  }) async =>
      false;

  @override
  Future<bool> deductTalant(int amount) async => false;
}
