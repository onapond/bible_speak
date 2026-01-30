import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/daily_verse.dart';
import '../bible_data_service.dart';
import '../esv_service.dart';

/// 아침 만나 서비스
class MorningMannaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BibleDataService _bibleData = BibleDataService.instance;
  final EsvService _esv = EsvService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// 오늘 날짜 문자열
  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 오늘의 구절 가져오기
  Future<DailyVerse?> getDailyVerse() async {
    try {
      // 1. Firestore에서 글로벌 오늘의 구절 확인
      final globalDoc = await _firestore
          .collection('global')
          .doc('dailyVerse')
          .get();

      if (globalDoc.exists && globalDoc.data()?['date'] == _today) {
        return DailyVerse.fromMap(globalDoc.data()!);
      }

      // 2. 시즌 구절 확인
      final seasonalVerse = SeasonalVerse.getForDate(DateTime.now());
      if (seasonalVerse != null) {
        return await _createDailyVerseFromSeasonal(seasonalVerse);
      }

      // 3. 큐레이션 구절 사용
      final curatedData = CuratedVerses.getForDate(DateTime.now());
      return await _createDailyVerseFromCurated(curatedData);
    } catch (e) {
      print('Get daily verse error: $e');
      // Fallback to first curated verse
      final fallback = CuratedVerses.pool[0];
      return DailyVerse(
        reference: fallback['reference'],
        bookId: fallback['bookId'],
        chapter: fallback['chapter'],
        verse: fallback['verse'],
        textEn: '',
        textKo: fallback['textKo'],
        date: _today,
        source: 'curated',
      );
    }
  }

  /// 시즌 구절로 DailyVerse 생성
  Future<DailyVerse> _createDailyVerseFromSeasonal(SeasonalVerse seasonal) async {
    String textEn = '';
    try {
      final bookNameEn = await _bibleData.getBookNameEn(seasonal.bookId);
      final verses = await _esv.getChapter(
        book: bookNameEn,
        chapter: seasonal.chapter,
      );
      final verse = verses.firstWhere(
        (v) => v.verse == seasonal.verse,
        orElse: () => verses.first,
      );
      textEn = verse.english;
    } catch (e) {
      print('Error fetching English text: $e');
    }

    return DailyVerse(
      reference: seasonal.reference,
      bookId: seasonal.bookId,
      chapter: seasonal.chapter,
      verse: seasonal.verse,
      textEn: textEn,
      textKo: seasonal.textKo,
      date: _today,
      source: 'seasonal',
    );
  }

  /// 큐레이션 구절로 DailyVerse 생성
  Future<DailyVerse> _createDailyVerseFromCurated(Map<String, dynamic> curated) async {
    String textEn = '';
    try {
      final bookNameEn = await _bibleData.getBookNameEn(curated['bookId']);
      final verses = await _esv.getChapter(
        book: bookNameEn,
        chapter: curated['chapter'],
      );
      final verse = verses.firstWhere(
        (v) => v.verse == curated['verse'],
        orElse: () => verses.first,
      );
      textEn = verse.english;
    } catch (e) {
      print('Error fetching English text: $e');
    }

    return DailyVerse(
      reference: curated['reference'],
      bookId: curated['bookId'],
      chapter: curated['chapter'],
      verse: curated['verse'],
      textEn: textEn,
      textKo: curated['textKo'],
      date: _today,
      source: 'curated',
    );
  }

  /// Early Bird 보너스 상태 가져오기
  EarlyBirdBonus getEarlyBirdBonus() {
    return EarlyBirdBonus.calculate(DateTime.now());
  }

  /// Early Bird 보너스 클레임 여부 확인
  Future<bool> hasClaimedEarlyBirdToday() async {
    final uid = currentUserId;
    if (uid == null) return true; // 로그인 안됐으면 true 반환 (중복 방지)

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final lastClaimed = doc.data()?['earlyBird']?['lastClaimedDate'] as String?;
      return lastClaimed == _today;
    } catch (e) {
      return false;
    }
  }

  /// Early Bird 보너스 클레임
  /// 반환: 획득한 보너스 금액 (0이면 이미 클레임됨)
  Future<int> claimEarlyBirdBonus() async {
    final uid = currentUserId;
    if (uid == null) return 0;

    // 이미 오늘 클레임했는지 확인
    final alreadyClaimed = await hasClaimedEarlyBirdToday();
    if (alreadyClaimed) return 0;

    // 현재 시간대 보너스 확인
    final bonus = getEarlyBirdBonus();
    if (!bonus.isEligible || bonus.bonusAmount <= 0) return 0;

    try {
      // set with merge로 보너스 지급 (문서가 없어도 동작)
      final userRef = _firestore.collection('users').doc(uid);

      await userRef.set({
        'talants': FieldValue.increment(bonus.bonusAmount),
        'earlyBird': {
          'lastClaimedDate': _today,
          'lastClaimedTime': DateTime.now().toIso8601String(),
          'totalBonusEarned': FieldValue.increment(bonus.bonusAmount),
        },
      }, SetOptions(merge: true));

      print('✅ Early Bird 보너스 지급 완료: +${bonus.bonusAmount} 달란트');
      return bonus.bonusAmount;
    } catch (e) {
      print('❌ Claim early bird bonus error: $e');
      return 0;
    }
  }

  /// Early Bird 통계 가져오기
  Future<Map<String, dynamic>> getEarlyBirdStats() async {
    final uid = currentUserId;
    if (uid == null) {
      return {'totalBonusEarned': 0, 'daysWithBonus': 0};
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final earlyBird = doc.data()?['earlyBird'] as Map<String, dynamic>?;

      return {
        'totalBonusEarned': earlyBird?['totalBonusEarned'] ?? 0,
        'lastClaimedDate': earlyBird?['lastClaimedDate'],
        'lastClaimedTime': earlyBird?['lastClaimedTime'],
      };
    } catch (e) {
      return {'totalBonusEarned': 0};
    }
  }
}
