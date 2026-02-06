import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'texture_provider.g.dart';

/// 텍스처 설정 상태
@immutable
class TextureSettings {
  const TextureSettings({
    this.enabled = true,
    this.coarseOpacity = 0.24,
    this.fineOpacity = 0.16,
  });

  /// 텍스처 활성화 여부
  final bool enabled;

  /// Perlin 노이즈 강도 (부드러운 얼룩)
  final double coarseOpacity;

  /// 그레인 노이즈 강도 (미세한 결)
  final double fineOpacity;

  TextureSettings copyWith({
    bool? enabled,
    double? coarseOpacity,
    double? fineOpacity,
  }) {
    return TextureSettings(
      enabled: enabled ?? this.enabled,
      coarseOpacity: coarseOpacity ?? this.coarseOpacity,
      fineOpacity: fineOpacity ?? this.fineOpacity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextureSettings &&
        other.enabled == enabled &&
        other.coarseOpacity == coarseOpacity &&
        other.fineOpacity == fineOpacity;
  }

  @override
  int get hashCode => Object.hash(enabled, coarseOpacity, fineOpacity);
}

/// 텍스처 설정 Provider (앱 전역)
@Riverpod(keepAlive: true)
class TextureSettingsNotifier extends _$TextureSettingsNotifier {
  @override
  TextureSettings build() => const TextureSettings();

  /// 텍스처 활성화/비활성화 토글
  void toggle() {
    state = state.copyWith(enabled: !state.enabled);
  }

  /// 텍스처 활성화 상태 설정
  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  /// Perlin 노이즈 강도 설정 (0.0 ~ 0.2 권장)
  void setCoarseOpacity(double opacity) {
    state = state.copyWith(coarseOpacity: opacity.clamp(0.0, 0.3));
  }

  /// 그레인 노이즈 강도 설정 (0.0 ~ 0.15 권장)
  void setFineOpacity(double opacity) {
    state = state.copyWith(fineOpacity: opacity.clamp(0.0, 0.2));
  }

  /// 모든 설정 초기화
  void reset() {
    state = const TextureSettings();
  }
}
