import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/bible/bible_models.dart';
import '../bible_data_service.dart';
import '../esv_service.dart';

/// 성경 오프라인 저장 서비스
/// - 책 단위로 오프라인 저장
/// - 다운로드 진행률 추적
/// - 저장 공간 관리
class BibleOfflineService extends ChangeNotifier {
  static final BibleOfflineService _instance = BibleOfflineService._internal();
  factory BibleOfflineService() => _instance;
  BibleOfflineService._internal();

  static const String _boxName = 'bible_offline_texts';
  static const String _metaBoxName = 'bible_offline_meta';

  Box? _textBox;
  Box? _metaBox;
  bool _isInitialized = false;

  // 다운로드 상태
  final Map<String, DownloadProgress> _downloadProgress = {};
  String? _currentDownloadingBookId;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 현재 다운로드 중인 책 ID
  String? get currentDownloadingBookId => _currentDownloadingBookId;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _textBox = await Hive.openBox(_boxName);
      _metaBox = await Hive.openBox(_metaBoxName);
      _isInitialized = true;
      debugPrint('BibleOfflineService initialized');
    } catch (e) {
      debugPrint('BibleOfflineService init error: $e');
      _isInitialized = true;
    }
  }

  /// 책이 오프라인 저장되어 있는지 확인
  bool isBookCached(String bookId) {
    if (_metaBox == null) return false;
    final meta = _metaBox!.get('meta_$bookId');
    return meta != null && meta['isComplete'] == true;
  }

  /// 저장된 책 목록
  List<String> getCachedBooks() {
    if (_metaBox == null) return [];

    final cached = <String>[];
    for (final key in _metaBox!.keys) {
      if (key.toString().startsWith('meta_')) {
        final meta = _metaBox!.get(key);
        if (meta != null && meta['isComplete'] == true) {
          cached.add(key.toString().replaceFirst('meta_', ''));
        }
      }
    }
    return cached;
  }

  /// 다운로드 진행률 가져오기
  DownloadProgress? getDownloadProgress(String bookId) {
    return _downloadProgress[bookId];
  }

  /// 책 다운로드 (오프라인 저장)
  Future<bool> downloadBook(String bookId) async {
    if (!_isInitialized || _textBox == null || _metaBox == null) {
      return false;
    }

    if (_currentDownloadingBookId != null) {
      debugPrint('Already downloading: $_currentDownloadingBookId');
      return false;
    }

    _currentDownloadingBookId = bookId;
    _downloadProgress[bookId] = DownloadProgress(
      bookId: bookId,
      status: DownloadStatus.downloading,
      progress: 0.0,
      message: '준비 중...',
    );
    notifyListeners();

    try {
      final bibleService = BibleDataService.instance;
      final esvService = EsvService();

      // 1. 책 정보 가져오기
      final book = await bibleService.getBook(bookId);
      if (book == null) {
        throw Exception('Book not found: $bookId');
      }

      final chapterCount = book.chapterCount;
      int totalVerses = 0;
      int downloadedVerses = 0;

      // 2. 총 구절 수 계산
      for (int ch = 1; ch <= chapterCount; ch++) {
        totalVerses += await bibleService.getVerseCount(bookId, ch);
      }

      // 3. 챕터별로 다운로드
      for (int ch = 1; ch <= chapterCount; ch++) {
        _updateProgress(bookId, downloadedVerses / totalVerses,
            '${book.nameKo} $ch장 다운로드 중...');

        // 한글 구절 가져오기
        final verses = await bibleService.getVerses(bookId, ch);

        // 영문 구절 가져오기 (ESV API)
        List<VerseText> englishVerses = [];
        try {
          final bookNameEn = await bibleService.getBookNameEn(bookId);
          englishVerses = await esvService.getChapter(
            book: bookNameEn,
            chapter: ch,
          );
        } catch (e) {
          debugPrint('ESV API error for $bookId $ch: $e');
        }

        // 구절 데이터 저장
        final chapterData = <String, dynamic>{};
        for (final verse in verses) {
          final englishText = englishVerses
              .where((v) => v.verse == verse.verse)
              .firstOrNull
              ?.english;

          chapterData['v${verse.verse}'] = {
            'verse': verse.verse,
            'textKo': verse.textKo,
            'textEn': englishText ?? verse.textEn,
          };
          downloadedVerses++;
        }

        // Hive에 저장
        await _textBox!.put('${bookId}_$ch', chapterData);
        _updateProgress(bookId, downloadedVerses / totalVerses,
            '${book.nameKo} $ch장 완료');
      }

      // 4. 메타데이터 저장
      await _metaBox!.put('meta_$bookId', {
        'bookId': bookId,
        'nameKo': book.nameKo,
        'nameEn': book.nameEn,
        'chapterCount': chapterCount,
        'totalVerses': totalVerses,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
        'isComplete': true,
      });

      _downloadProgress[bookId] = DownloadProgress(
        bookId: bookId,
        status: DownloadStatus.completed,
        progress: 1.0,
        message: '다운로드 완료',
      );

      debugPrint('Book $bookId download complete');
      return true;
    } catch (e) {
      debugPrint('Download error for $bookId: $e');
      _downloadProgress[bookId] = DownloadProgress(
        bookId: bookId,
        status: DownloadStatus.error,
        progress: 0.0,
        message: '다운로드 실패: $e',
      );
      return false;
    } finally {
      _currentDownloadingBookId = null;
      notifyListeners();
    }
  }

  void _updateProgress(String bookId, double progress, String message) {
    _downloadProgress[bookId] = DownloadProgress(
      bookId: bookId,
      status: DownloadStatus.downloading,
      progress: progress,
      message: message,
    );
    notifyListeners();
  }

  /// 오프라인 저장된 구절 가져오기
  Future<List<Verse>> getCachedVerses(String bookId, int chapter) async {
    if (_textBox == null) return [];

    try {
      final chapterData = _textBox!.get('${bookId}_$chapter');
      if (chapterData == null) return [];

      final verses = <Verse>[];
      final data = chapterData as Map;

      for (final key in data.keys) {
        if (key.toString().startsWith('v')) {
          final verseData = data[key] as Map;
          verses.add(Verse(
            bookId: bookId,
            chapter: chapter,
            verse: verseData['verse'] as int,
            textKo: verseData['textKo'] as String? ?? '',
            textEn: verseData['textEn'] as String? ?? '',
          ));
        }
      }

      verses.sort((a, b) => a.verse.compareTo(b.verse));
      return verses;
    } catch (e) {
      debugPrint('Get cached verses error: $e');
      return [];
    }
  }

  /// 오프라인 저장된 단일 구절 가져오기
  Future<Verse?> getCachedVerse(String bookId, int chapter, int verse) async {
    if (_textBox == null) return null;

    try {
      final chapterData = _textBox!.get('${bookId}_$chapter');
      if (chapterData == null) return null;

      final verseData = (chapterData as Map)['v$verse'];
      if (verseData == null) return null;

      return Verse(
        bookId: bookId,
        chapter: chapter,
        verse: verseData['verse'] as int,
        textKo: verseData['textKo'] as String? ?? '',
        textEn: verseData['textEn'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('Get cached verse error: $e');
      return null;
    }
  }

  /// 책 삭제
  Future<bool> deleteBook(String bookId) async {
    if (_textBox == null || _metaBox == null) return false;

    try {
      final meta = _metaBox!.get('meta_$bookId');
      if (meta == null) return false;

      final chapterCount = meta['chapterCount'] as int;

      // 챕터 데이터 삭제
      for (int ch = 1; ch <= chapterCount; ch++) {
        await _textBox!.delete('${bookId}_$ch');
      }

      // 메타데이터 삭제
      await _metaBox!.delete('meta_$bookId');

      _downloadProgress.remove(bookId);
      notifyListeners();

      debugPrint('Book $bookId deleted from offline storage');
      return true;
    } catch (e) {
      debugPrint('Delete book error: $e');
      return false;
    }
  }

  /// 저장 공간 사용량 (대략적)
  Future<StorageInfo> getStorageInfo() async {
    if (_textBox == null || _metaBox == null) {
      return StorageInfo(usedBytes: 0, bookCount: 0);
    }

    try {
      int estimatedBytes = 0;
      int bookCount = 0;

      for (final key in _metaBox!.keys) {
        if (key.toString().startsWith('meta_')) {
          final meta = _metaBox!.get(key);
          if (meta != null && meta['isComplete'] == true) {
            bookCount++;
            // 대략적인 크기 추정 (구절당 평균 500바이트)
            final totalVerses = meta['totalVerses'] as int? ?? 0;
            estimatedBytes += totalVerses * 500;
          }
        }
      }

      return StorageInfo(usedBytes: estimatedBytes, bookCount: bookCount);
    } catch (e) {
      return StorageInfo(usedBytes: 0, bookCount: 0);
    }
  }

  /// 모든 오프라인 데이터 삭제
  Future<void> clearAll() async {
    if (_textBox != null) await _textBox!.clear();
    if (_metaBox != null) await _metaBox!.clear();
    _downloadProgress.clear();
    notifyListeners();
    debugPrint('All offline Bible data cleared');
  }

  /// 책 메타데이터 가져오기
  Map<String, dynamic>? getBookMeta(String bookId) {
    if (_metaBox == null) return null;
    final meta = _metaBox!.get('meta_$bookId');
    return meta != null ? Map<String, dynamic>.from(meta) : null;
  }
}

/// 다운로드 상태
enum DownloadStatus {
  idle,
  downloading,
  completed,
  error,
}

/// 다운로드 진행률
class DownloadProgress {
  final String bookId;
  final DownloadStatus status;
  final double progress;
  final String message;

  const DownloadProgress({
    required this.bookId,
    required this.status,
    required this.progress,
    required this.message,
  });
}

/// 저장 공간 정보
class StorageInfo {
  final int usedBytes;
  final int bookCount;

  const StorageInfo({
    required this.usedBytes,
    required this.bookCount,
  });

  String get usedMB => (usedBytes / (1024 * 1024)).toStringAsFixed(1);
}
