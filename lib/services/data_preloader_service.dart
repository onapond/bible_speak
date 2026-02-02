import 'dart:async';
import 'package:flutter/foundation.dart';
import 'review_service.dart';
import 'daily_quiz_service.dart';
import 'daily_goal_service.dart';
import 'stats_service.dart';
import 'social/streak_service.dart';
import 'social/morning_manna_service.dart';

/// 데이터 프리로딩 서비스
/// - 앱 시작 시 자주 사용하는 데이터 미리 로드
/// - 백그라운드에서 데이터 새로고침
/// - 캐시 상태 관리
class DataPreloaderService {
  static final DataPreloaderService _instance = DataPreloaderService._internal();
  factory DataPreloaderService() => _instance;
  DataPreloaderService._internal();

  // 서비스 인스턴스
  final _reviewService = ReviewService();
  final _quizService = DailyQuizService();
  final _dailyGoalService = DailyGoalService();
  final _statsService = StatsService();
  final _streakService = StreakService();
  final _morningMannaService = MorningMannaService();

  // 캐시된 데이터
  int? _dueReviewCount;
  bool? _hasCompletedQuiz;
  DateTime? _lastPreloadTime;
  PreloadedMainData? _cachedData; // 전체 캐시 데이터

  // 프리로드 상태
  bool _isPreloading = false;
  final _preloadCompleter = <Completer<void>>[];

  /// 프리로드가 필요한지 확인
  bool get needsPreload {
    if (_lastPreloadTime == null) return true;
    // 5분 이상 지났으면 새로고침 필요
    return DateTime.now().difference(_lastPreloadTime!).inMinutes >= 5;
  }

  /// 캐시된 복습 개수
  int? get cachedDueReviewCount => _dueReviewCount;

  /// 캐시된 퀴즈 완료 상태
  bool? get cachedHasCompletedQuiz => _hasCompletedQuiz;

  /// 메인 화면용 필수 데이터 프리로드
  /// - 타임아웃 적용 (3초)
  /// - 실패 시 null 반환 (UI에서 개별 로드)
  Future<PreloadedMainData?> preloadMainScreenData() async {
    if (_isPreloading) {
      // 이미 프리로딩 중이면 완료 대기
      final completer = Completer<void>();
      _preloadCompleter.add(completer);
      await completer.future;
      return _getCachedMainData();
    }

    _isPreloading = true;

    try {
      final results = await Future.wait([
        _reviewService.getDueItems().then((items) => items.length),
        _quizService.hasCompletedToday(),
        _dailyGoalService.init().then((_) => _dailyGoalService.todayGoal),
        _statsService.getUserStats(),
        _streakService.getStreak(),
        _morningMannaService.getDailyVerse(),
        _morningMannaService.hasClaimedEarlyBirdToday(),
      ]).timeout(const Duration(seconds: 3));

      _dueReviewCount = results[0] as int;
      _hasCompletedQuiz = results[1] as bool;
      _lastPreloadTime = DateTime.now();

      final data = PreloadedMainData(
        dueReviewCount: results[0] as int,
        hasCompletedQuiz: results[1] as bool,
        dailyGoal: results[2],
        userStats: results[3],
        streak: results[4],
        dailyVerse: results[5],
        hasClaimedEarlyBird: results[6] as bool,
      );

      // 캐시에 저장
      _cachedData = data;

      return data;
    } catch (e) {
      debugPrint('⚠️ 메인 데이터 프리로드 실패: $e');
      return null;
    } finally {
      _isPreloading = false;
      // 대기 중인 completer들 완료
      for (final completer in _preloadCompleter) {
        completer.complete();
      }
      _preloadCompleter.clear();
    }
  }

  PreloadedMainData? _getCachedMainData() {
    if (_lastPreloadTime == null) return null;
    // 캐시 만료 확인 (5분)
    if (needsPreload) return null;
    // 캐시된 데이터 반환
    return _cachedData;
  }

  /// 백그라운드 새로고침
  Future<void> refreshInBackground() async {
    if (_isPreloading) return;

    // 비동기로 새로고침 (결과 무시)
    unawaited(_refreshData());
  }

  Future<void> _refreshData() async {
    try {
      final results = await Future.wait([
        _reviewService.getDueItems().then((items) => items.length),
        _quizService.hasCompletedToday(),
      ]).timeout(const Duration(seconds: 2));

      _dueReviewCount = results[0] as int;
      _hasCompletedQuiz = results[1] as bool;
      _lastPreloadTime = DateTime.now();
    } catch (_) {
      // 실패 무시
    }
  }

  /// 특정 데이터 무효화
  void invalidate(PreloadDataType type) {
    switch (type) {
      case PreloadDataType.review:
        _dueReviewCount = null;
        break;
      case PreloadDataType.quiz:
        _hasCompletedQuiz = null;
        break;
      case PreloadDataType.all:
        _dueReviewCount = null;
        _hasCompletedQuiz = null;
        _lastPreloadTime = null;
        break;
    }
  }

  /// 캐시 완전 초기화
  void clearCache() {
    _dueReviewCount = null;
    _hasCompletedQuiz = null;
    _lastPreloadTime = null;
    _cachedData = null;
  }
}

/// 프리로드된 메인 화면 데이터
class PreloadedMainData {
  final int dueReviewCount;
  final bool hasCompletedQuiz;
  final dynamic dailyGoal;
  final dynamic userStats;
  final dynamic streak;
  final dynamic dailyVerse;
  final bool hasClaimedEarlyBird;

  const PreloadedMainData({
    required this.dueReviewCount,
    required this.hasCompletedQuiz,
    this.dailyGoal,
    this.userStats,
    this.streak,
    this.dailyVerse,
    required this.hasClaimedEarlyBird,
  });
}

/// 프리로드 데이터 타입
enum PreloadDataType {
  review,
  quiz,
  all,
}

/// unawaited 유틸 함수 (dart:async에서 제공)
void unawaited(Future<void>? future) {}
