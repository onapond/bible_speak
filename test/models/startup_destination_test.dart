import 'package:bible_speak/models/session_state.dart';
import 'package:bible_speak/models/startup_destination.dart';
import 'package:bible_speak/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startup destination', () {
    test('returns to the app for the same persisted Firebase account', () {
      expect(
        resolveStartupDestination(
          onboardingCompleted: true,
          savedUserId: 'user-a',
          firebaseUserId: 'user-a',
        ),
        StartupDestination.mainMenu,
      );
    });

    test('does not restore a different account from stale local state', () {
      expect(
        resolveStartupDestination(
          onboardingCompleted: true,
          savedUserId: 'user-a',
          firebaseUserId: 'user-b',
        ),
        StartupDestination.login,
      );
    });

    test('uses onboarding before login when no session exists', () {
      expect(
        resolveStartupDestination(
          onboardingCompleted: false,
          savedUserId: null,
          firebaseUserId: null,
        ),
        StartupDestination.onboarding,
      );
      expect(
        resolveStartupDestination(
          onboardingCompleted: true,
          savedUserId: null,
          firebaseUserId: null,
        ),
        StartupDestination.login,
      );
    });

    test('waits on loading and recoverable session errors', () {
      expect(
        resolveSessionStartupDestination(
          session: const SessionState.loading(firebaseUserId: 'user-a'),
          onboardingCompleted: true,
        ),
        isNull,
      );
      expect(
        resolveSessionStartupDestination(
          session: const SessionState.recoverableError(
            firebaseUserId: 'user-a',
            error: 'offline',
          ),
          onboardingCompleted: true,
        ),
        isNull,
      );
    });

    test('routes only definitive session states', () {
      const user = UserModel(
        uid: 'user-a',
        name: 'Tester',
        groupId: 'group-a',
      );

      expect(
        resolveSessionStartupDestination(
          session: SessionState.authenticated(
            user: user,
            source: SessionProfileSource.cache,
          ),
          onboardingCompleted: true,
        ),
        StartupDestination.mainMenu,
      );
      expect(
        resolveSessionStartupDestination(
          session: const SessionState.needsProfile(
            firebaseUserId: 'user-a',
          ),
          onboardingCompleted: true,
        ),
        StartupDestination.profileSetup,
      );
      expect(
        resolveSessionStartupDestination(
          session: const SessionState.signedOut(),
          onboardingCompleted: true,
        ),
        StartupDestination.login,
      );
    });
  });
}
