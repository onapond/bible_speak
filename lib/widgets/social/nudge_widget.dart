import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/nudge.dart';
import '../../styles/parchment_theme.dart';

/// 비활성 멤버 목록 위젯
class InactiveMembersWidget extends StatelessWidget {
  final List<InactiveMember> members;
  final Function(InactiveMember) onNudge;
  final NudgeDailyStats stats;

  const InactiveMembersWidget({
    super.key,
    required this.members,
    required this.onNudge,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '😴',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '독려가 필요해요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 남은 찌르기 횟수
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stats.canSendNudge
                        ? ParchmentTheme.manuscriptGold.withValues(alpha: 0.2)
                        : ParchmentTheme.weatheredGray.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '💌 ${stats.remainingNudges}/${stats.dailyLimit}',
                    style: TextStyle(
                      color: stats.canSendNudge ? ParchmentTheme.manuscriptGold : ParchmentTheme.weatheredGray,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 멤버 목록
          ...members.take(5).map((member) => _buildMemberTile(context, member)),

          // 하단 여백
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          Text('🎉', style: TextStyle(fontSize: 24)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '모두 열심히 하고 있어요!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '3일 이상 미접속 멤버가 없습니다',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, InactiveMember member) {
    final canNudge = stats.canNudgeUser(member.odId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // 상태 이모지
          Text(
            member.statusEmoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 12),

          // 이름 & 상태
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: member.isHighlighted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  member.statusMessage,
                  style: TextStyle(
                    color: member.isHighlighted ? ParchmentTheme.warning : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 찌르기 버튼
          GestureDetector(
            onTap: canNudge ? () => onNudge(member) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: canNudge
                    ? ParchmentTheme.manuscriptGold.withValues(alpha: 0.2)
                    : ParchmentTheme.weatheredGray.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: canNudge
                    ? Border.all(color: ParchmentTheme.manuscriptGold.withValues(alpha: 0.5))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '💌',
                    style: TextStyle(
                      fontSize: 14,
                      color: canNudge ? null : ParchmentTheme.weatheredGray,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '찌르기',
                    style: TextStyle(
                      color: canNudge ? ParchmentTheme.manuscriptGold : ParchmentTheme.weatheredGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 찌르기 메시지 선택 다이얼로그
class NudgeMessageDialog extends StatefulWidget {
  final String targetName;
  final Function(String message, String? templateId) onSend;

  const NudgeMessageDialog({
    super.key,
    required this.targetName,
    required this.onSend,
  });

  @override
  State<NudgeMessageDialog> createState() => _NudgeMessageDialogState();
}

class _NudgeMessageDialogState extends State<NudgeMessageDialog> {
  String? _selectedTemplateId;
  final _customController = TextEditingController();
  bool _isCustom = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  const Text('💌', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.targetName}님에게 찌르기',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 메시지 선택
              const Text(
                '메시지 선택:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),

              // 템플릿 목록
              ...NudgeTemplate.templates.map((template) => _buildTemplateOption(template)),

              // 직접 작성
              _buildCustomOption(),

              // 커스텀 입력
              if (_isCustom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customController,
                  maxLength: 50,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(color: Colors.white38),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: 20),

              // 버튼
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _canSend ? _send : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParchmentTheme.manuscriptGold,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: ParchmentTheme.weatheredGray,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '보내기',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSend {
    if (_isCustom) {
      return _customController.text.trim().isNotEmpty;
    }
    return _selectedTemplateId != null;
  }

  void _send() {
    if (_isCustom) {
      widget.onSend(_customController.text.trim(), null);
    } else {
      final template = NudgeTemplate.getById(_selectedTemplateId!);
      if (template != null) {
        widget.onSend('${template.message} ${template.emoji}', template.id);
      }
    }
    Navigator.pop(context);
  }

  Widget _buildTemplateOption(NudgeTemplate template) {
    final isSelected = _selectedTemplateId == template.id && !_isCustom;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedTemplateId = template.id;
          _isCustom = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? ParchmentTheme.manuscriptGold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: ParchmentTheme.manuscriptGold, width: 2)
              : Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Text(template.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '"${template.message}"',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: ParchmentTheme.manuscriptGold, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomOption() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedTemplateId = null;
          _isCustom = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isCustom
              ? ParchmentTheme.manuscriptGold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: _isCustom
              ? Border.all(color: ParchmentTheme.manuscriptGold, width: 2)
              : Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Text('✏️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '직접 작성하기',
                style: TextStyle(
                  color: _isCustom ? Colors.white : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            if (_isCustom)
              const Icon(Icons.check_circle, color: ParchmentTheme.manuscriptGold, size: 20),
          ],
        ),
      ),
    );
  }
}

/// 찌르기 수신 다이얼로그
class NudgeReceivedDialog extends StatelessWidget {
  final Nudge nudge;
  final VoidCallback onDismiss;
  final VoidCallback onGoStudy;

  const NudgeReceivedDialog({
    super.key,
    required this.nudge,
    required this.onDismiss,
    required this.onGoStudy,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이모지
            const Text(
              '💌',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),

            // 타이틀
            Text(
              '${nudge.fromUserName}님의 찌르기!',
              style: const TextStyle(
                color: ParchmentTheme.manuscriptGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"${nudge.message}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onDismiss,
                    child: const Text(
                      '나중에',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onGoStudy,
                    icon: const Icon(Icons.menu_book, size: 18),
                    label: const Text(
                      '암송하러 가기',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParchmentTheme.manuscriptGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 찌르기 성공 스낵바
class NudgeSentSnackBar extends SnackBar {
  NudgeSentSnackBar({super.key, required String targetName})
      : super(
          content: Row(
            children: [
              const Text('💌', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text('$targetName님에게 찌르기를 보냈어요!'),
            ],
          ),
          backgroundColor: ParchmentTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        );
}
