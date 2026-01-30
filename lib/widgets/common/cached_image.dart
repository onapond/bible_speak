import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shimmer_loading.dart';

/// 캐시된 네트워크 이미지 위젯
/// - 자동 캐싱 및 메모리/디스크 저장
/// - 스켈레톤 로딩 플레이스홀더
/// - 에러 시 기본 아이콘 표시
class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? placeholderColor;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.placeholderColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
      memCacheWidth: width != null ? (width! * 2).toInt() : null,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        ShimmerLoading(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: placeholderColor ?? const Color(0xFF2E2E4E),
              borderRadius: borderRadius,
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF2E2E4E),
            borderRadius: borderRadius,
          ),
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.white38,
            size: (width ?? height ?? 40) * 0.4,
          ),
        );
  }
}

/// 캐시된 아바타 이미지
/// - 원형 프로필 이미지용
/// - 이니셜 폴백 지원
class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? name;
  final Color? backgroundColor;

  const CachedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.name,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildInitialAvatar();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => _buildLoadingAvatar(),
      errorWidget: (context, url, error) => _buildInitialAvatar(),
      fadeInDuration: const Duration(milliseconds: 200),
      memCacheWidth: (radius * 4).toInt(),
      memCacheHeight: (radius * 4).toInt(),
    );
  }

  Widget _buildLoadingAvatar() {
    return ShimmerLoading(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF2E2E4E),
      ),
    );
  }

  Widget _buildInitialAvatar() {
    final initial = _getInitial();
    final bgColor = backgroundColor ?? _getColorFromName();

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitial() {
    if (name == null || name!.isEmpty) return '?';
    return name![0].toUpperCase();
  }

  Color _getColorFromName() {
    if (name == null || name!.isEmpty) return Colors.grey;

    // 이름 기반 일관된 색상 생성
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];

    final hash = name!.codeUnits.fold(0, (prev, curr) => prev + curr);
    return colors[hash % colors.length];
  }
}

/// 캐시된 썸네일 이미지
/// - 그리드/리스트 아이템용
/// - 고정 비율 유지
class CachedThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double aspectRatio;
  final BorderRadius? borderRadius;
  final IconData? fallbackIcon;

  const CachedThumbnail({
    super.key,
    required this.imageUrl,
    this.width = 100,
    this.aspectRatio = 1.0,
    this.borderRadius,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final height = width / aspectRatio;

    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      errorWidget: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF2E2E4E),
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: Icon(
          fallbackIcon ?? Icons.image,
          color: Colors.white38,
          size: width * 0.3,
        ),
      ),
    );
  }
}

/// 이미지 캐시 유틸리티
class ImageCacheUtils {
  /// 이미지 미리 로드 (prefetch)
  static Future<void> prefetchImage(BuildContext context, String url) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(url),
        context,
      );
    } catch (_) {
      // 프리페치 실패는 무시
    }
  }

  /// 여러 이미지 미리 로드
  static Future<void> prefetchImages(
    BuildContext context,
    List<String> urls,
  ) async {
    await Future.wait(
      urls.map((url) => prefetchImage(context, url)),
    );
  }

  /// 캐시 비우기
  static Future<void> clearCache() async {
    await CachedNetworkImage.evictFromCache('');
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// 특정 이미지 캐시에서 제거
  static Future<void> evictImage(String url) async {
    await CachedNetworkImage.evictFromCache(url);
  }
}
