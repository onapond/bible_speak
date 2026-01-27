import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart' show AuthorizationStatus;
import '../../models/notification_settings.dart' as app_settings;
import '../../services/notification/notification_service.dart';
import '../../services/notification/notification_settings_service.dart';
import '../../widgets/notification/notification_permission_dialog.dart';

/// 알림 설정 화면
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final NotificationSettingsService _settingsService = NotificationSettingsService();

  app_settings.NotificationSettings _settings = const app_settings.NotificationSettings();
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermission();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _checkPermission() async {
    final status = await _notificationService.getPermissionStatus();
    setState(() {
      _hasPermission = status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
    });
  }

  Future<void> _requestPermission() async {
    final granted = await showDialog<bool>(
      context: context,
      builder: (context) => const NotificationPermissionDialog(),
    );

    if (granted == true) {
      final result = await _notificationService.requestPermission();
      setState(() {
        _hasPermission = result;
      });

      if (result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림이 활성화되었습니다')),
        );
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await _settingsService.updateSetting(key, value);
    await _loadSettings();
  }

  Future<void> _showTimePickerDialog() async {
    final currentTime = TimeOfDay(
      hour: _settings.morningMannaHour,
      minute: _settings.morningMannaMinute,
    );

    final newTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      helpText: '아침 만나 알림 시간',
    );

    if (newTime != null) {
      final timeString = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
      await _settingsService.setMorningManna(time: timeString);
      await _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('알림 설정')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 설정'),
      ),
      body: ListView(
        children: [
          // 권한 상태 배너
          if (!_hasPermission && !kIsWeb)
            Container(
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '알림 권한이 필요합니다',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '푸시 알림을 받으려면 권한을 허용해주세요',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _requestPermission,
                    child: const Text('허용'),
                  ),
                ],
              ),
            ),

          // 웹 알림 안내
          if (kIsWeb)
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '웹에서는 브라우저 알림으로 제공됩니다. 브라우저 설정에서 알림을 허용해주세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 전체 알림 토글
          SwitchListTile(
            title: const Text('알림 받기'),
            subtitle: const Text('모든 푸시 알림을 켜거나 끕니다'),
            value: _settings.enabled,
            onChanged: (value) => _updateSetting('enabled', value),
            secondary: const Icon(Icons.notifications),
          ),

          const Divider(),

          // 알림 유형별 설정
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '알림 유형',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),

          // 아침 만나
          SwitchListTile(
            title: const Text('아침 만나'),
            subtitle: Text(
              _settings.morningMannaEnabled
                  ? '매일 ${_settings.morningMannaTime}에 알림'
                  : '비활성화됨',
            ),
            value: _settings.morningMannaEnabled,
            onChanged: _settings.enabled
                ? (value) => _settingsService.setMorningManna(enabled: value).then((_) => _loadSettings())
                : null,
            secondary: const Icon(Icons.wb_sunny),
          ),

          // 아침 만나 시간 설정
          if (_settings.morningMannaEnabled && _settings.enabled)
            ListTile(
              title: const Text('알림 시간'),
              subtitle: Text(_settings.morningMannaTime),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showTimePickerDialog,
              contentPadding: const EdgeInsets.only(left: 72, right: 16),
            ),

          // 스트릭 경고
          SwitchListTile(
            title: const Text('스트릭 경고'),
            subtitle: const Text('학습하지 않은 날 저녁 9시에 알림'),
            value: _settings.streakWarningEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('streakWarningEnabled', value)
                : null,
            secondary: const Icon(Icons.local_fire_department),
          ),

          // 찌르기 알림
          SwitchListTile(
            title: const Text('찌르기 알림'),
            subtitle: const Text('그룹 멤버의 격려 메시지'),
            value: _settings.nudgeEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('nudgeEnabled', value)
                : null,
            secondary: const Icon(Icons.pan_tool),
          ),

          // 반응 알림
          SwitchListTile(
            title: const Text('반응 알림'),
            subtitle: const Text('내 활동에 대한 반응'),
            value: _settings.reactionEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('reactionEnabled', value)
                : null,
            secondary: const Icon(Icons.favorite),
          ),

          // 주간 리포트
          SwitchListTile(
            title: const Text('주간 리포트'),
            subtitle: const Text('매주 일요일 저녁 6시'),
            value: _settings.weeklySummaryEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('weeklySummaryEnabled', value)
                : null,
            secondary: const Icon(Icons.bar_chart),
          ),

          const Divider(),

          // 소리 및 진동 설정
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '알림 설정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),

          SwitchListTile(
            title: const Text('소리'),
            value: _settings.soundEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('soundEnabled', value)
                : null,
            secondary: const Icon(Icons.volume_up),
          ),

          SwitchListTile(
            title: const Text('진동'),
            value: _settings.vibrationEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('vibrationEnabled', value)
                : null,
            secondary: const Icon(Icons.vibration),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
