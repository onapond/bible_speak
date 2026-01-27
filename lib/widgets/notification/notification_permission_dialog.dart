import 'package:flutter/material.dart';

/// 알림 권한 요청 다이얼로그
class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          const Text('알림 권한'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '바이블 스픽에서 다음 알림을 보내드려요:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            Icons.wb_sunny,
            '아침 만나',
            '매일 아침 말씀과 함께 시작',
          ),
          const SizedBox(height: 8),
          _buildFeatureRow(
            Icons.local_fire_department,
            '스트릭 알림',
            '연속 학습을 놓치지 않도록',
          ),
          const SizedBox(height: 8),
          _buildFeatureRow(
            Icons.people,
            '그룹 알림',
            '멤버들의 격려 메시지',
          ),
          const SizedBox(height: 16),
          Text(
            '알림은 설정에서 언제든 변경할 수 있어요.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('허용하기'),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
