import 'package:bible_speak/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds authenticated proxy URLs without provider credentials', () {
    final audio = Uri.parse(AppConfig.getEsvAudioUrl('John 3:16'));
    final text = Uri.parse(AppConfig.getEsvTextUrl('Ephesians 2'));

    expect(audio.path, endsWith('/esvAudio'));
    expect(audio.queryParameters['q'], 'John 3:16');
    expect(text.path, endsWith('/esvText'));
    expect(text.queryParameters['q'], 'Ephesians 2');
    expect(audio.query, isNot(contains('apiKey')));
  });
}
