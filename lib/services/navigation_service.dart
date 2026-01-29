import 'package:flutter/material.dart';

/// 글로벌 네비게이션 서비스
/// 위젯 트리 외부(알림 탭 등)에서 네비게이션을 가능하게 함
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 현재 네비게이터 상태
  NavigatorState? get navigator => navigatorKey.currentState;

  /// 현재 컨텍스트
  BuildContext? get context => navigatorKey.currentContext;

  /// 화면 푸시
  Future<T?>? push<T>(Route<T> route) {
    return navigator?.push(route);
  }

  /// MaterialPageRoute로 화면 푸시
  Future<T?>? pushWidget<T>(Widget widget) {
    return navigator?.push(MaterialPageRoute(builder: (_) => widget));
  }

  /// 교체하면서 푸시
  Future<T?>? pushReplacement<T, TO>(Route<T> route) {
    return navigator?.pushReplacement(route);
  }

  /// 모두 제거하고 푸시
  Future<T?>? pushAndRemoveUntil<T>(Route<T> route) {
    return navigator?.pushAndRemoveUntil(route, (_) => false);
  }

  /// 뒤로가기
  void pop<T>([T? result]) {
    navigator?.pop(result);
  }

  /// 특정 라우트까지 팝
  void popUntil(RoutePredicate predicate) {
    navigator?.popUntil(predicate);
  }
}
