import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 네트워크 연결 상태 관리 서비스
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _isInitialized = false;

  /// 현재 온라인 상태
  bool get isOnline => _isOnline;

  /// 현재 오프라인 상태
  bool get isOffline => !_isOnline;

  /// 초기화 완료 여부
  bool get isInitialized => _isInitialized;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 현재 상태 확인
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);

      // 연결 상태 변경 리스닝
      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (e) {
          print('Connectivity error: $e');
          _isOnline = false;
          notifyListeners();
        },
      );

      _isInitialized = true;
    } catch (e) {
      print('Connectivity initialization error: $e');
      _isOnline = true; // 오류 시 온라인으로 가정
      _isInitialized = true;
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;

    // none이 아닌 결과가 있으면 온라인
    _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      print('Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
      notifyListeners();
    }
  }

  /// 현재 연결 상태 다시 확인
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
      return _isOnline;
    } catch (e) {
      return _isOnline;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// 싱글톤 인스턴스
final connectivityService = ConnectivityService();
