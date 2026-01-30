import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 접근성 설정 서비스
/// - 텍스트 크기 조절
/// - 고대비 모드
/// - 애니메이션 감소
class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  static const String _keyTextScale = 'a11y_text_scale';
  static const String _keyHighContrast = 'a11y_high_contrast';
  static const String _keyReduceMotion = 'a11y_reduce_motion';
  static const String _keyLargerTapTargets = 'a11y_larger_tap_targets';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // 기본값
  double _textScaleFactor = 1.0;
  bool _highContrastMode = false;
  bool _reduceMotion = false;
  bool _largerTapTargets = false;

  // Getters
  double get textScaleFactor => _textScaleFactor;
  bool get highContrastMode => _highContrastMode;
  bool get reduceMotion => _reduceMotion;
  bool get largerTapTargets => _largerTapTargets;
  bool get isInitialized => _isInitialized;

  /// 텍스트 크기 옵션
  static const List<TextScaleOption> textScaleOptions = [
    TextScaleOption(label: '작게', value: 0.85),
    TextScaleOption(label: '기본', value: 1.0),
    TextScaleOption(label: '크게', value: 1.15),
    TextScaleOption(label: '매우 크게', value: 1.3),
  ];

  /// 초기화
  Future<void> init() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    _isInitialized = true;
    notifyListeners();
  }

  void _loadSettings() {
    _textScaleFactor = _prefs?.getDouble(_keyTextScale) ?? 1.0;
    _highContrastMode = _prefs?.getBool(_keyHighContrast) ?? false;
    _reduceMotion = _prefs?.getBool(_keyReduceMotion) ?? false;
    _largerTapTargets = _prefs?.getBool(_keyLargerTapTargets) ?? false;
  }

  /// 텍스트 크기 설정
  Future<void> setTextScaleFactor(double value) async {
    if (value < 0.5 || value > 2.0) return;
    _textScaleFactor = value;
    await _prefs?.setDouble(_keyTextScale, value);
    notifyListeners();
  }

  /// 고대비 모드 설정
  Future<void> setHighContrastMode(bool enabled) async {
    _highContrastMode = enabled;
    await _prefs?.setBool(_keyHighContrast, enabled);
    notifyListeners();
  }

  /// 애니메이션 감소 설정
  Future<void> setReduceMotion(bool enabled) async {
    _reduceMotion = enabled;
    await _prefs?.setBool(_keyReduceMotion, enabled);
    notifyListeners();
  }

  /// 큰 터치 영역 설정
  Future<void> setLargerTapTargets(bool enabled) async {
    _largerTapTargets = enabled;
    await _prefs?.setBool(_keyLargerTapTargets, enabled);
    notifyListeners();
  }

  /// 애니메이션 지속 시간 (reduceMotion 적용)
  Duration getAnimationDuration(Duration normalDuration) {
    if (_reduceMotion) {
      return Duration.zero;
    }
    return normalDuration;
  }

  /// 최소 터치 영역 크기
  double get minTapTargetSize => _largerTapTargets ? 56.0 : 48.0;

  /// 설정 초기화
  Future<void> resetToDefaults() async {
    _textScaleFactor = 1.0;
    _highContrastMode = false;
    _reduceMotion = false;
    _largerTapTargets = false;

    await _prefs?.remove(_keyTextScale);
    await _prefs?.remove(_keyHighContrast);
    await _prefs?.remove(_keyReduceMotion);
    await _prefs?.remove(_keyLargerTapTargets);

    notifyListeners();
  }
}

/// 텍스트 크기 옵션
class TextScaleOption {
  final String label;
  final double value;

  const TextScaleOption({
    required this.label,
    required this.value,
  });
}

/// 고대비 색상 정의
class HighContrastColors {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color primary = Color(0xFFFFFF00); // 노란색 (고대비)
  static const Color onPrimary = Color(0xFF000000);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF00FF7F);
}
