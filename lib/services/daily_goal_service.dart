import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_goal.dart';
import 'auth_service.dart';

/// 일일 학습 목표 서비스
class DailyGoalService {
  static const _keyTodayGoal = 'bible_speak_daily_goal';
  static const _keyGoalPreset = 'bible_speak_goal_preset';
  static const _keyCustomTargets = 'bible_speak_custom_targets';

  SharedPreferences? _prefs;
  DailyGoal? _todayGoal;

  /// 초기화
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadTodayGoal();
  }

  /// 오늘의 목표 가져오기
  DailyGoal get todayGoal {
    if (_todayGoal == null || !_todayGoal!.isToday) {
      _todayGoal = _createNewDayGoal();
      _saveTodayGoal();
    }
    return _todayGoal!;
  }

  /// 목표 프리셋 가져오기
  DailyGoalPreset get currentPreset {
    final presetIndex = _prefs?.getInt(_keyGoalPreset) ?? 1;
    return DailyGoalPreset.values[presetIndex.clamp(0, DailyGoalPreset.values.length - 1)];
  }

  /// 목표 프리셋 설정
  Future<void> setPreset(DailyGoalPreset preset) async {
    await _prefs?.setInt(_keyGoalPreset, preset.index);
    // 새 프리셋으로 오늘 목표 재설정 (진행률은 유지)
    final current = todayGoal;
    _todayGoal = DailyGoal(
      date: current.date,
      targetWords: preset.targetWords,
      studiedWords: current.studiedWords,
      targetQuizzes: preset.targetQuizzes,
      completedQuizzes: current.completedQuizzes,
      targetFlashcards: preset.targetFlashcards,
      completedFlashcards: current.completedFlashcards,
      goalAchieved: current.goalAchieved,
      bonusClaimed: current.bonusClaimed,
    );
    await _saveTodayGoal();
  }

  /// 사용자 정의 목표 설정
  Future<void> setCustomTargets({
    required int targetWords,
    required int targetQuizzes,
    required int targetFlashcards,
  }) async {
    await _prefs?.setString(_keyCustomTargets, jsonEncode({
      'targetWords': targetWords,
      'targetQuizzes': targetQuizzes,
      'targetFlashcards': targetFlashcards,
    }));
    await _prefs?.setInt(_keyGoalPreset, DailyGoalPreset.custom.index);

    final current = todayGoal;
    _todayGoal = DailyGoal(
      date: current.date,
      targetWords: targetWords,
      studiedWords: current.studiedWords,
      targetQuizzes: targetQuizzes,
      completedQuizzes: current.completedQuizzes,
      targetFlashcards: targetFlashcards,
      completedFlashcards: current.completedFlashcards,
      goalAchieved: current.goalAchieved,
      bonusClaimed: current.bonusClaimed,
    );
    await _saveTodayGoal();
  }

  /// 단어 학습 기록
  Future<void> recordWordStudy(int count) async {
    final goal = todayGoal;
    _todayGoal = goal.copyWith(
      studiedWords: goal.studiedWords + count,
    );
    await _checkAndUpdateGoalAchievement();
    await _saveTodayGoal();
  }

  /// 퀴즈 완료 기록
  Future<void> recordQuizCompletion() async {
    final goal = todayGoal;
    _todayGoal = goal.copyWith(
      completedQuizzes: goal.completedQuizzes + 1,
    );
    await _checkAndUpdateGoalAchievement();
    await _saveTodayGoal();
  }

  /// 플래시카드 완료 기록
  Future<void> recordFlashcardCompletion() async {
    final goal = todayGoal;
    _todayGoal = goal.copyWith(
      completedFlashcards: goal.completedFlashcards + 1,
    );
    await _checkAndUpdateGoalAchievement();
    await _saveTodayGoal();
  }

  /// 목표 달성 체크 및 보너스 지급
  Future<bool> _checkAndUpdateGoalAchievement() async {
    final goal = todayGoal;

    if (goal.isGoalMet && !goal.goalAchieved) {
      _todayGoal = goal.copyWith(goalAchieved: true);

      // 보너스 달란트 지급 (아직 안 받았다면)
      if (!goal.bonusClaimed) {
        final earnedBonus = await AuthService().addDailyGoalBonus();
        if (earnedBonus) {
          _todayGoal = _todayGoal!.copyWith(bonusClaimed: true);
        }
      }
      return true;
    }
    return false;
  }

  /// 보너스 수령 (수동 호출용)
  Future<bool> claimBonus() async {
    final goal = todayGoal;
    if (goal.isGoalMet && !goal.bonusClaimed) {
      final success = await AuthService().addDailyGoalBonus();
      if (success) {
        _todayGoal = goal.copyWith(bonusClaimed: true);
        await _saveTodayGoal();
        return true;
      }
    }
    return false;
  }

  /// 오늘의 목표 로드
  Future<void> _loadTodayGoal() async {
    final json = _prefs?.getString(_keyTodayGoal);
    if (json != null) {
      try {
        final goal = DailyGoal.fromJson(jsonDecode(json));
        if (goal.isToday) {
          _todayGoal = goal;
          return;
        }
      } catch (e) {
        // 파싱 실패 시 새로 생성
      }
    }
    _todayGoal = _createNewDayGoal();
    await _saveTodayGoal();
  }

  /// 새 하루 목표 생성
  DailyGoal _createNewDayGoal() {
    final preset = currentPreset;

    if (preset == DailyGoalPreset.custom) {
      final customJson = _prefs?.getString(_keyCustomTargets);
      if (customJson != null) {
        try {
          final custom = jsonDecode(customJson);
          return DailyGoal.today(
            targetWords: custom['targetWords'] ?? 10,
            targetQuizzes: custom['targetQuizzes'] ?? 1,
            targetFlashcards: custom['targetFlashcards'] ?? 1,
          );
        } catch (e) {
          // 파싱 실패 시 기본값
        }
      }
    }

    return DailyGoal.today(
      targetWords: preset.targetWords,
      targetQuizzes: preset.targetQuizzes,
      targetFlashcards: preset.targetFlashcards,
    );
  }

  /// 오늘의 목표 저장
  Future<void> _saveTodayGoal() async {
    if (_todayGoal != null) {
      await _prefs?.setString(_keyTodayGoal, jsonEncode(_todayGoal!.toJson()));
    }
  }
}
