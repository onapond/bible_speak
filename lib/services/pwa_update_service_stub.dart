import 'package:flutter/material.dart';

/// 웹이 아닌 플랫폼용 스텁 구현
class PwaUpdateService {
  static final PwaUpdateService _instance = PwaUpdateService._internal();
  factory PwaUpdateService() => _instance;
  PwaUpdateService._internal();

  bool get updateReady => false;
  String get currentVersion => 'native';
  Stream<bool> get onUpdateAvailable => Stream.value(false);

  void initialize() {}
  void setContext(BuildContext context) {}
  void showUpdateDialog(BuildContext context) {}
  void showUpdateSnackBar(BuildContext context) {}
  void applyUpdate() {}
  void forceRefresh() {}
  Future<bool> checkForUpdate() async => false;
  void dispose() {}
}
