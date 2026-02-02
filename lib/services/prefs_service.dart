import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 전역 캐싱 서비스
/// - 앱 시작 시 한 번만 getInstance() 호출
/// - 이후 동기적으로 인스턴스 접근 가능
class PrefsService {
  static SharedPreferences? _instance;

  /// 비동기 인스턴스 접근 (초기화 안 됐으면 초기화)
  static Future<SharedPreferences> get instance async {
    _instance ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// 동기 인스턴스 접근 (init() 호출 후에만 사용)
  static SharedPreferences? get instanceSync => _instance;

  /// 앱 시작 시 초기화 (main.dart에서 호출)
  static Future<void> init() async {
    _instance = await SharedPreferences.getInstance();
  }

  /// 캐시 무효화 (테스트용)
  static void reset() {
    _instance = null;
  }
}
