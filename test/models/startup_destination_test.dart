import 'package:bible_speak/models/startup_destination.dart';
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
  });
}
