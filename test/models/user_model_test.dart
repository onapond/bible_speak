import 'package:bible_speak/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel completed verses', () {
    test('keeps canonical verse identities', () {
      final user = UserModel.fromFirestore('uid-1', {
        'name': 'Tester',
        'groupId': '',
        'completedVerses': ['malachi:1:2', 'ephesians:2:8'],
      });

      expect(
        user.completedVerses,
        ['malachi:1:2', 'ephesians:2:8'],
      );
    });

    test('preserves legacy numeric entries without colliding with new ids', () {
      final user = UserModel.fromFirestore('uid-1', {
        'name': 'Tester',
        'groupId': '',
        'completedVerses': [1, 2],
      });

      expect(user.completedVerses, ['legacy:1', 'legacy:2']);
      expect(user.completedVerses, isNot(contains('malachi:1:1')));
    });
  });
}
