import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/texture_provider.dart';
import '../../styles/parchment_theme.dart';

/// 양피지 질감 오버레이 (코드 생성)
///
/// Perlin 노이즈와 그레인 노이즈를 결합하여 진정한 양피지 질감 구현
/// Riverpod을 통해 설정을 관리하며 성능 최적화를 위해 RepaintBoundary 사용
class ParchmentTextureOverlay extends ConsumerWidget {
  const ParchmentTextureOverlay({
    super.key,
    this.seed = 42,
  });

  /// 노이즈 생성을 위한 시드 값
  final int seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(textureSettingsNotifierProvider);

    if (!settings.enabled) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Perlin 노이즈 (coarse - 부드러운 얼룩)
            if (settings.coarseOpacity > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: settings.coarseOpacity,
                  child: CustomPaint(
                    painter: PerlinNoisePainter(seed: seed),
                    isComplex: true,
                    willChange: false,
                  ),
                ),
              ),
            // Grain 노이즈 (fine - 미세한 결)
            if (settings.fineOpacity > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: settings.fineOpacity,
                  child: CustomPaint(
                    painter: GrainNoisePainter(seed: seed + 1),
                    isComplex: true,
                    willChange: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 카드용 텍스처 오버레이 (단일 위젯)
///
/// 카드 내부에 적용하기 위한 경량 버전
/// ClipRRect와 함께 사용하여 카드 모서리에 맞춤
class ParchmentCardTexture extends StatelessWidget {
  const ParchmentCardTexture({
    super.key,
    this.coarseOpacity = 0.04,
    this.fineOpacity = 0.03,
    this.seed = 42,
    this.borderRadius,
  });

  final double coarseOpacity;
  final double fineOpacity;
  final int seed;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(ParchmentTheme.radiusLarge);

    return RepaintBoundary(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              if (coarseOpacity > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: coarseOpacity,
                    child: CustomPaint(
                      painter: PerlinNoisePainter(seed: seed),
                      isComplex: true,
                      willChange: false,
                    ),
                  ),
                ),
              if (fineOpacity > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: fineOpacity,
                    child: CustomPaint(
                      painter: GrainNoisePainter(seed: seed + 1),
                      isComplex: true,
                      willChange: false,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Perlin 노이즈 페인터 (부드러운 얼룩)
///
/// 양피지의 자연스러운 색상 변화와 얼룩을 표현
/// Simplex noise 알고리즘의 단순화 버전 사용
class PerlinNoisePainter extends CustomPainter {
  PerlinNoisePainter({
    this.seed = 42,
    this.scale = 0.008,
    this.octaves = 3,
  }) : _random = math.Random(seed);

  final int seed;
  final double scale;
  final int octaves;
  final math.Random _random;

  // Permutation table for noise
  late final List<int> _perm = _generatePermutation();

  List<int> _generatePermutation() {
    final p = List<int>.generate(256, (i) => i);
    for (var i = 255; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = p[i];
      p[i] = p[j];
      p[j] = temp;
    }
    return [...p, ...p]; // Double for overflow handling
  }

  double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);

  double _lerp(double a, double b, double t) => a + t * (b - a);

  double _grad(int hash, double x, double y) {
    final h = hash & 3;
    final u = h < 2 ? x : y;
    final v = h < 2 ? y : x;
    return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
  }

  double _noise2D(double x, double y) {
    final xi = x.floor() & 255;
    final yi = y.floor() & 255;
    final xf = x - x.floor();
    final yf = y - y.floor();

    final u = _fade(xf);
    final v = _fade(yf);

    final aa = _perm[_perm[xi] + yi];
    final ab = _perm[_perm[xi] + yi + 1];
    final ba = _perm[_perm[xi + 1] + yi];
    final bb = _perm[_perm[xi + 1] + yi + 1];

    final x1 = _lerp(_grad(aa, xf, yf), _grad(ba, xf - 1, yf), u);
    final x2 = _lerp(_grad(ab, xf, yf - 1), _grad(bb, xf - 1, yf - 1), u);

    return _lerp(x1, x2, v);
  }

  double _fractalNoise(double x, double y) {
    var total = 0.0;
    var frequency = 1.0;
    var amplitude = 1.0;
    var maxValue = 0.0;

    for (var i = 0; i < octaves; i++) {
      total += _noise2D(x * frequency, y * frequency) * amplitude;
      maxValue += amplitude;
      amplitude *= 0.5;
      frequency *= 2.0;
    }

    return total / maxValue;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 세피아 톤 색상들 (양피지 얼룩)
    const baseColor = ParchmentTheme.warmVellum;
    final darkColor = ParchmentTheme.agedParchment.withValues(alpha: 0.8);
    final lightColor = ParchmentTheme.softPapyrus.withValues(alpha: 0.6);

    // 저해상도로 샘플링하여 성능 최적화
    const step = 6.0;

    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        final noiseValue = (_fractalNoise(x * scale, y * scale) + 1) / 2;

        // 노이즈 값에 따라 색상 혼합
        Color color;
        if (noiseValue < 0.4) {
          color = Color.lerp(darkColor, baseColor, noiseValue / 0.4)!;
        } else if (noiseValue > 0.6) {
          color = Color.lerp(baseColor, lightColor, (noiseValue - 0.6) / 0.4)!;
        } else {
          color = baseColor;
        }

        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(x, y, step + 1, step + 1),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PerlinNoisePainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.scale != scale ||
        oldDelegate.octaves != octaves;
  }
}

/// 그레인 노이즈 페인터 (미세한 결)
///
/// 종이의 섬유질 질감을 표현
/// 고주파 노이즈로 미세한 입자감 생성
class GrainNoisePainter extends CustomPainter {
  GrainNoisePainter({
    this.seed = 42,
    this.density = 0.15,
  });

  final int seed;
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 그레인 색상 (어두운 세피아와 밝은 세피아)
    final darkGrain = ParchmentTheme.fadedScript.withValues(alpha: 0.3);
    final lightGrain = ParchmentTheme.softPapyrus.withValues(alpha: 0.5);

    // 그레인 입자 크기
    const grainSize = 2.0;

    // 랜덤 시드 재설정 (일관된 패턴)
    final localRandom = math.Random(seed);

    for (var y = 0.0; y < size.height; y += grainSize) {
      for (var x = 0.0; x < size.width; x += grainSize) {
        if (localRandom.nextDouble() < density) {
          // 랜덤하게 어둡거나 밝은 그레인
          final isLight = localRandom.nextBool();
          paint.color = isLight ? lightGrain : darkGrain;

          // 약간의 크기 변화
          final actualSize = grainSize * (0.5 + localRandom.nextDouble() * 0.5);

          canvas.drawRect(
            Rect.fromLTWH(x, y, actualSize, actualSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GrainNoisePainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.density != density;
  }
}

/// 빈티지 에지 효과 페인터
///
/// 양피지 가장자리의 어두운 번인 효과
/// vignette 스타일로 가장자리를 어둡게 처리
class VintageEdgePainter extends CustomPainter {
  VintageEdgePainter({
    this.intensity = 0.15,
  });

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height) * 0.7;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Colors.transparent,
          ParchmentTheme.warmVellum.withValues(alpha: intensity * 0.5),
          ParchmentTheme.fadedScript.withValues(alpha: intensity),
        ],
        [0.5, 0.8, 1.0],
      );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant VintageEdgePainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}
