import 'dart:convert';

import '../config/app_config.dart';
import 'api/authenticated_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ESV API 서비스
/// - 성경 텍스트 동적 로딩
/// - 로컬 캐싱 지원
class EsvService {
  /// 성경 구절 가져오기 (캐싱 포함)
  Future<List<VerseText>> getChapter({
    required String book,
    required int chapter,
  }) async {
    final cacheKey = 'esv_${book}_$chapter';

    // 캐시 확인
    final cached = await _getFromCache(cacheKey);
    if (cached != null) {
      print('✅ ESV 캐시 히트: $book $chapter');
      return cached;
    }

    // API 호출
    print('🌐 ESV API 호출: $book $chapter');
    final verses = await _fetchFromApi(book, chapter);

    // 캐시 저장
    await _saveToCache(cacheKey, verses);

    return verses;
  }

  /// ESV API에서 구절 가져오기
  Future<List<VerseText>> _fetchFromApi(String book, int chapter) async {
    final query = '$book $chapter';
    final url = Uri.parse(AppConfig.getEsvTextUrl(query));
    final response = await AuthenticatedApiClient.get(url)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['passages']?.first ?? '';
      return _parseVerses(text);
    } else if (response.statusCode == 401) {
      throw Exception('로그인이 만료되었습니다. 다시 로그인해주세요.');
    } else if (response.statusCode == 403) {
      throw Exception('성경 본문에 접근할 권한이 없습니다.');
    } else {
      print('❌ ESV API 오류: ${response.statusCode} - ${response.body}');
      throw Exception('ESV API 오류: ${response.statusCode}');
    }
  }

  /// ESV 텍스트를 구절 단위로 파싱
  List<VerseText> _parseVerses(String text) {
    final verses = <VerseText>[];

    // ESV 형식: [1] In the beginning... [2] The earth was...
    final regex = RegExp(r'\[(\d+)\]\s*([^\[]+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final verseNum = int.parse(match.group(1)!);
      final verseText =
          match.group(2)!.trim().replaceAll(RegExp(r'\s+'), ' '); // 여러 공백을 하나로

      if (verseText.isNotEmpty) {
        verses.add(VerseText(verse: verseNum, english: verseText));
      }
    }

    return verses;
  }

  /// 캐시에서 가져오기
  Future<List<VerseText>?> _getFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(key);

      if (jsonStr == null) return null;

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => VerseText.fromJson(j)).toList();
    } catch (e) {
      return null;
    }
  }

  /// 캐시에 저장
  Future<void> _saveToCache(String key, List<VerseText> verses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(verses.map((v) => v.toJson()).toList());
      await prefs.setString(key, jsonStr);
      print('💾 ESV 캐시 저장: $key');
    } catch (e) {
      print('⚠️ 캐시 저장 실패: $e');
    }
  }

  /// 캐시 삭제
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('esv_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
    print('🗑️ ESV 캐시 삭제 완료');
  }
}

/// 구절 텍스트 모델
class VerseText {
  final int verse;
  final String english;
  final String? korean; // 한글은 선택적

  const VerseText({
    required this.verse,
    required this.english,
    this.korean,
  });

  factory VerseText.fromJson(Map<String, dynamic> json) {
    return VerseText(
      verse: json['verse'],
      english: json['english'],
      korean: json['korean'],
    );
  }

  Map<String, dynamic> toJson() => {
        'verse': verse,
        'english': english,
        'korean': korean,
      };

  VerseText copyWith({String? korean}) {
    return VerseText(
      verse: verse,
      english: english,
      korean: korean ?? this.korean,
    );
  }
}
