/// Firestore 컬렉션/문서 경로 상수
class FirestorePaths {
  FirestorePaths._();

  // ============ Collections ============

  /// 성경 컬렉션
  static const String bible = 'bible';

  /// 단어 컬렉션
  static const String vocabulary = 'vocabulary';

  /// 사용자 컬렉션
  static const String users = 'users';

  /// 그룹 컬렉션
  static const String groups = 'groups';

  /// 리더보드 컬렉션
  static const String leaderboard = 'leaderboard';

  // ============ Sub-collections ============

  /// 챕터 서브컬렉션
  static const String chapters = 'chapters';

  /// 구절 서브컬렉션
  static const String verses = 'verses';

  /// 진행 상태 서브컬렉션
  static const String progress = 'progress';

  /// 구독 서브컬렉션
  static const String subscription = 'subscription';

  // ============ Path Builders ============

  /// 성경책 문서 경로
  /// 예: bible/malachi
  static String bookDoc(String bookId) => '$bible/$bookId';

  /// 챕터 컬렉션 경로
  /// 예: bible/malachi/chapters
  static String chaptersCollection(String bookId) => '$bible/$bookId/$chapters';

  /// 챕터 문서 경로
  /// 예: bible/malachi/chapters/1
  static String chapterDoc(String bookId, int chapter) =>
      '$bible/$bookId/$chapters/$chapter';

  /// 구절 컬렉션 경로
  /// 예: bible/malachi/chapters/1/verses
  static String versesCollection(String bookId, int chapter) =>
      '$bible/$bookId/$chapters/$chapter/$verses';

  /// 구절 문서 경로
  /// 예: bible/malachi/chapters/1/verses/1
  static String verseDoc(String bookId, int chapter, int verse) =>
      '$bible/$bookId/$chapters/$chapter/$verses/$verse';

  /// 단어 문서 경로
  /// 예: vocabulary/malachi_1
  static String vocabularyDoc(String bookId, int chapter) =>
      '$vocabulary/${bookId}_$chapter';

  /// 사용자 문서 경로
  static String userDoc(String uid) => '$users/$uid';

  /// 사용자 진행 상태 컬렉션 경로
  static String userProgressCollection(String uid) =>
      '$users/$uid/$progress';

  /// 사용자 구독 문서 경로
  static String userSubscriptionDoc(String uid) =>
      '$users/$uid/$subscription/current';
}
