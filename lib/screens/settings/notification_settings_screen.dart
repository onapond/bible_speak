import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart' show AuthorizationStatus;
import '../../models/notification_settings.dart' as app_settings;
import '../../services/notification/notification_service.dart';
import '../../services/notification/notification_settings_service.dart';
import '../../styles/parchment_theme.dart';
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

  // Parchment 테마 색상
  static const _cardColor = ParchmentTheme.softPapyrus;
  static const _accentColor = ParchmentTheme.manuscriptGold;

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
          SnackBar(
            content: const Text('알림이 활성화되었습니다'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await _settingsService.updateSetting(key, value);
    await _loadSettings();
  }

  Future<void> _showMorningTimePickerDialog() async {
    final currentTime = TimeOfDay(
      hour: _settings.morningMannaHour,
      minute: _settings.morningMannaMinute,
    );

    final newTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      helpText: '아침 만나 알림 시간',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentColor,
              surface: _cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newTime != null) {
      final timeString = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
      await _settingsService.setMorningManna(time: timeString);
      await _loadSettings();
    }
  }

  Future<void> _showEveningTimePickerDialog() async {
    final currentTime = TimeOfDay(
      hour: _settings.eveningReminderHour,
      minute: _settings.eveningReminderMinute,
    );

    final newTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      helpText: '저녁 학습 리마인더 시간',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentColor,
              surface: _cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newTime != null) {
      final timeString = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
      await _settingsService.setEveningReminder(time: timeString);
      await _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ParchmentTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      color: ParchmentTheme.ancientInk,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        '알림 설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParchmentTheme.ancientInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _accentColor))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 권한 상태 배너
                          if (!_hasPermission && !kIsWeb) _buildPermissionBanner(),

                          // 웹 알림 안내
                          if (kIsWeb) _buildWebNotice(),

                          // 전체 알림 토글
                          _buildMainToggle(),
                          const SizedBox(height: 16),

                          // 알림 유형 섹션
                          _buildSectionTitle('알림 유형'),
                          const SizedBox(height: 12),
                          _buildNotificationTypeCard(),
                          const SizedBox(height: 16),

                          // 알림 옵션 섹션
                          _buildSectionTitle('알림 옵션'),
                          const SizedBox(height: 12),
                          _buildNotificationOptionsCard(),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParchmentTheme.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParchmentTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ParchmentTheme.warning.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber, color: ParchmentTheme.warning, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '알림 권한이 필요합니다',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ParchmentTheme.ancientInk,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '푸시 알림을 받으려면 권한을 허용해주세요',
                  style: TextStyle(fontSize: 12, color: ParchmentTheme.fadedScript),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _requestPermission,
            style: TextButton.styleFrom(
              backgroundColor: ParchmentTheme.warning,
              foregroundColor: ParchmentTheme.softPapyrus,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('허용'),
          ),
        ],
      ),
    );
  }

  Widget _buildWebNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _accentColor, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '웹에서는 브라우저 알림으로 제공됩니다.',
              style: TextStyle(fontSize: 13, color: ParchmentTheme.fadedScript),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: SwitchListTile(
        title: const Text(
          '알림 받기',
          style: TextStyle(color: ParchmentTheme.ancientInk, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          '모든 푸시 알림을 켜거나 끕니다',
          style: TextStyle(color: ParchmentTheme.fadedScript, fontSize: 13),
        ),
        value: _settings.enabled,
        onChanged: (value) => _updateSetting('enabled', value),
        activeColor: _accentColor,
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications, color: _accentColor, size: 24),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: ParchmentTheme.fadedScript,
        ),
      ),
    );
  }

  Widget _buildNotificationTypeCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.wb_sunny,
            iconColor: Colors.amber,
            title: '아침 만나',
            subtitle: _settings.morningMannaEnabled
                ? '매일 ${_settings.morningMannaTime}에 알림'
                : '비활성화됨',
            value: _settings.morningMannaEnabled,
            onChanged: _settings.enabled
                ? (value) => _settingsService.setMorningManna(enabled: value).then((_) => _loadSettings())
                : null,
            showTimePicker: _settings.morningMannaEnabled && _settings.enabled,
            onTimeTap: _showMorningTimePickerDialog,
          ),
          _buildDivider(),
          _buildNotificationTile(
            icon: Icons.nightlight_round,
            iconColor: Colors.indigo,
            title: '저녁 학습 리마인더',
            subtitle: _settings.eveningReminderEnabled
                ? '매일 ${_settings.eveningReminderTime}에 목표 확인'
                : '비활성화됨',
            value: _settings.eveningReminderEnabled,
            onChanged: _settings.enabled
                ? (value) => _settingsService.setEveningReminder(enabled: value).then((_) => _loadSettings())
                : null,
            showTimePicker: _settings.eveningReminderEnabled && _settings.enabled,
            onTimeTap: _showEveningTimePickerDialog,
            timeLabel: '알림 시간: ${_settings.eveningReminderTime}',
          ),
          _buildDivider(),
          _buildNotificationTile(
            icon: Icons.local_fire_department,
            iconColor: Colors.deepOrange,
            title: '연속 학습 알림',
            subtitle: '학습하지 않은 날 저녁 9시에 리마인드',
            value: _settings.streakWarningEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('streakWarningEnabled', value)
                : null,
          ),
          _buildDivider(),
          _buildNotificationTile(
            icon: Icons.pan_tool,
            iconColor: Colors.pink,
            title: '찌르기 알림',
            subtitle: '그룹 멤버의 격려 메시지',
            value: _settings.nudgeEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('nudgeEnabled', value)
                : null,
          ),
          _buildDivider(),
          _buildNotificationTile(
            icon: Icons.favorite,
            iconColor: Colors.red,
            title: '반응 알림',
            subtitle: '내 활동에 대한 반응',
            value: _settings.reactionEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('reactionEnabled', value)
                : null,
          ),
          _buildDivider(),
          _buildNotificationTile(
            icon: Icons.bar_chart,
            iconColor: Colors.teal,
            title: '주간 리포트',
            subtitle: '매주 일요일 저녁 6시',
            value: _settings.weeklySummaryEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('weeklySummaryEnabled', value)
                : null,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        boxShadow: ParchmentTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.volume_up,
            iconColor: Colors.blue,
            title: '소리',
            subtitle: '알림 소리 켜기/끄기',
            value: _settings.soundEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('soundEnabled', value)
                : null,
          ),
          _buildDivider(),
          _buildNotificationTile(
            icon: Icons.vibration,
            iconColor: Colors.purple,
            title: '진동',
            subtitle: '알림 진동 켜기/끄기',
            value: _settings.vibrationEnabled,
            onChanged: _settings.enabled
                ? (value) => _updateSetting('vibrationEnabled', value)
                : null,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool isLast = false,
    bool showTimePicker = false,
    VoidCallback? onTimeTap,
    String? timeLabel,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SwitchListTile(
            title: Text(
              title,
              style: TextStyle(
                color: onChanged != null ? ParchmentTheme.ancientInk : ParchmentTheme.weatheredGray,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: onChanged != null ? ParchmentTheme.fadedScript : ParchmentTheme.warmVellum,
                fontSize: 12,
              ),
            ),
            value: value,
            onChanged: onChanged,
            activeColor: _accentColor,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
        ),
        if (showTimePicker)
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: InkWell(
              onTap: onTimeTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeLabel ?? '알림 시간: ${_settings.morningMannaTime}',
                      style: const TextStyle(color: _accentColor, fontSize: 13),
                    ),
                    const Icon(Icons.edit, color: _accentColor, size: 16),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: ParchmentTheme.warmVellum.withValues(alpha: 0.5), height: 1),
    );
  }
}
