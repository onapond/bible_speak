import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ESV API 서비스
/// - 성경 텍스트 동적 로딩
/// - 로컬 캐싱 지원
class EsvService {
  static const String _baseUrl = 'https://api.esv.org/v3/passage/text/';

  String get _apiKey => AppConfig.esvApiKey;

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
    if (_apiKey.isEmpty) {
      throw Exception('ESV API 키가 설정되지 않았습니다.');
    }

    final query = '$book $chapter';
    final url = Uri.parse('$_baseUrl').replace(queryParameters: {
      'q': query,
      'include-passage-references': 'false',
      'include-verse-numbers': 'true',
      'include-first-verse-numbers': 'true',
      'include-footnotes': 'false',
      'include-headings': 'false',
      'include-short-copyright': 'false',
      'indent-paragraphs': '0',
      'indent-poetry': 'false',
      'indent-declares': '0',
      'indent-psalm-doxology': '0',
    });

    // 웹에서는 짧은 타임아웃, 모바일은 여유있게
    final timeout = kIsWeb ? const Duration(seconds: 10) : const Duration(seconds: 20);
    final response = await http.get(
      url,
      headers: {'Authorization': 'Token $_apiKey'},
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['passages']?.first ?? '';
      return _parseVerses(text);
    } else {
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
      final verseText = match.group(2)!.trim()
          .replaceAll(RegExp(r'\s+'), ' '); // 여러 공백을 하나로

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
