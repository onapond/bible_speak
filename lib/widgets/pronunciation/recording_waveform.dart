import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 녹음 중 표시할 음파 애니메이션 위젯
///
/// 사인파 기반 시뮬레이션으로 바 형태의 음파를 그린다.
/// 중앙 바가 가장 높고 양쪽으로 점점 낮아지는 가우시안 엔벨로프 적용.
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({
    super.key,
    this.barCount = 24,
    this.height = 60,
    this.color = const Color(0xFFEF4444),
    this.animate = true,
  });

  /// 바 개수
  final int barCount;

  /// 위젯 높이
  final double height;

  /// 바 색상
  final Color color;

  /// 애니메이션 활성화 토글
  final bool animate;

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return SizedBox(height: widget.height);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _WaveformPainter(
            progress: _controller.value,
            barCount: widget.barCount,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.barCount,
    required this.color,
  });

  final double progress;
  final int barCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (barCount * 2 - 1);
    final maxBarHeight = size.height * 0.85;
    final minBarHeight = size.height * 0.08;
    final centerY = size.height * 0.48; // 반사 효과를 위해 약간 위로

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final reflectionPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      // 가우시안 엔벨로프: 중앙이 가장 높고 양쪽으로 감소
      final normalizedPos = (i - barCount / 2) / (barCount / 2);
      final gaussian = math.exp(-normalizedPos * normalizedPos * 2.5);

      // 사인파로 각 바의 높이를 시간에 따라 변동
      // 각 바마다 다른 위상(phase)과 주파수
      final phase1 = progress * 2 * math.pi + i * 0.35;
      final phase2 = progress * 2 * math.pi * 1.7 + i * 0.5;
      final phase3 = progress * 2 * math.pi * 0.8 + i * 0.25;

      final wave = (math.sin(phase1) * 0.4 +
              math.sin(phase2) * 0.35 +
              math.sin(phase3) * 0.25) *
          0.5 +
          0.5; // 0~1 범위로 정규화

      final barHeight =
          minBarHeight + (maxBarHeight - minBarHeight) * gaussian * wave;

      final x = i * barWidth * 2 + barWidth / 2;

      // 메인 바 그라디언트
      final opacity = 0.6 + gaussian * 0.4;
      paint.color = color.withValues(alpha: opacity);

      // 메인 바 (위쪽)
      final barRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, centerY - barHeight / 2),
          width: barWidth * 0.75,
          height: barHeight,
        ),
        Radius.circular(barWidth * 0.4),
      );
      canvas.drawRRect(barRect, paint);

      // 반사 효과 (아래쪽, 더 짧고 투명)
      final reflectionHeight = barHeight * 0.25;
      reflectionPaint.color = color.withValues(alpha: opacity * 0.15);
      final reflectionRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, centerY + reflectionHeight / 2 + 2),
          width: barWidth * 0.75,
          height: reflectionHeight,
        ),
        Radius.circular(barWidth * 0.4),
      );
      canvas.drawRRect(reflectionRect, reflectionPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
