import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:novopharma/design/design.dart';

/// Robust image loader for products and banners.
/// Handles:
/// 1. Trimming of Firestore URLs.
/// 2. Downscaled memory decoding (`memCacheWidth` / `memCacheHeight`) so large images (e.g. 3000x2000 PNGs) do not cause OOM.
/// 3. Standard HTTP Accept headers.
/// 4. Automatic fallback to `Image.network` if `CachedNetworkImage` encounters any cache or format issue.
class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, dynamic error)? errorWidget;
  final IconData errorIcon;
  final double errorIconSize;
  final Color? errorIconColor;
  final Color? backgroundColor;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.errorIcon = Icons.inventory_2_outlined,
    this.errorIconSize = 24.0,
    this.errorIconColor,
    this.backgroundColor,
  });

  Widget _buildFallback(BuildContext context, [String? url, dynamic error]) {
    if (errorWidget != null && url != null) {
      return errorWidget!(context, url, error);
    }
    // A quiet tile: the icon says what is missing without shouting about it.
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? AppColors.surfaceSunken,
      alignment: Alignment.center,
      child: Icon(
        errorIcon,
        size: errorIconSize,
        color: errorIconColor ?? AppColors.lineStrong,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, String url) {
    if (placeholder != null) {
      return placeholder!(context, url);
    }
    // The shimmer paints over whatever is opaque, so the fill only has to
    // mark out the image's box.
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        color: AppColors.line,
      ),
    );
  }

  Widget _clip(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl?.trim() ?? '';
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
      return _clip(_buildFallback(context));
    }

    final Widget imageWidget = CachedNetworkImage(
      imageUrl: cleanUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache ?? memCacheWidth,
      maxHeightDiskCache: maxHeightDiskCache ?? memCacheHeight,
      httpHeaders: const {
        'Accept': '*/*',
      },
      placeholder: (context, url) => _buildPlaceholder(context, url),
      errorWidget: (context, url, error) {
        debugPrint('âš ï¸ CachedNetworkImage failed for $url: $error. Trying Image.network fallback...');
        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          headers: const {
            'Accept': '*/*',
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _buildPlaceholder(context, url);
          },
          errorBuilder: (context, error2, stackTrace) {
            debugPrint('âŒ Image.network fallback also failed for $url: $error2');
            return _buildFallback(context, url, error2);
          },
        );
      },
    );

    return _clip(imageWidget);
  }
}
