import 'package:bible_speak/models/session_state.dart';
import 'package:bible_speak/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = UserModel(
    uid: 'user-a',
    name: 'Tester',
    groupId: 'group-a',
  );

  test('authenticated state keeps one matching Firebase and profile UID', () {
    final state = SessionState.authenticated(
      user: user,
      source: SessionProfileSource.remote,
    );

    expect(state.firebaseUserId, 'user-a');
    expect(state.persistedUserId, 'user-a');
    expect(state.user, same(user));
    expect(state.isAuthenticated, isTrue);
    expect(state.isDefinitive, isTrue);
    expect(state.isOffline, isFalse);
  });

  test('cached authenticated state remains definitive and reports offline', () {
    final state = SessionState.authenticated(
      user: user,
      source: SessionProfileSource.cache,
      warning: StateError('offline'),
    );

    expect(state.isAuthenticated, isTrue);
    expect(state.isDefinitive, isTrue);
    expect(state.isOffline, isTrue);
    expect(state.error, isA<StateError>());
  });

  test('loading and recoverable errors are not routing decisions', () {
    expect(const SessionState.loading().isDefinitive, isFalse);
    expect(
      const SessionState.recoverableError(error: 'offline').isDefinitive,
      isFalse,
    );
  });
}
