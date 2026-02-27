import 'dart:convert';
import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  final String? assetPath;
  final String? networkUrl;
  final String? base64Data;
  final double width;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool useCache; // для будущего использования

  const AppImage({
    Key? key,
    this.assetPath,
    this.networkUrl,
    this.base64Data,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.onTap,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.useCache = true,
  }) : super(key: key);

  // Фабричные конструкторы для удобства
  factory AppImage.asset({
    required String assetPath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    VoidCallback? onTap,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    return AppImage(
      assetPath: assetPath,
      width: width,
      height: height,
      fit: fit,
      onTap: onTap,
      placeholder: placeholder,
      errorWidget: errorWidget,
      borderRadius: borderRadius,
    );
  }

  factory AppImage.network({
    required String url,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    VoidCallback? onTap,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    bool useCache = true,
  }) {
    return AppImage(
      networkUrl: url,
      width: width,
      height: height,
      fit: fit,
      onTap: onTap,
      placeholder: placeholder,
      errorWidget: errorWidget,
      borderRadius: borderRadius,
      useCache: useCache,
    );
  }

  factory AppImage.base64({
    required String base64,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    VoidCallback? onTap,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    return AppImage(
      base64Data: base64,
      width: width,
      height: height,
      fit: fit,
      onTap: onTap,
      placeholder: placeholder,
      errorWidget: errorWidget,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    // Определяем источник изображения
    if (assetPath != null) {
      return _buildAssetImage();
    } else if (networkUrl != null) {
      return _buildNetworkImage();
    } else if (base64Data != null) {
      return _buildBase64Image();
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildAssetImage() {
    return Image.asset(
      assetPath!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Ошибка загрузки asset: $assetPath');
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildNetworkImage() {
    return Image.network(
      networkUrl!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Ошибка загрузки сети: $networkUrl');
        return _buildErrorWidget();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildLoadingIndicator(
          progress: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
              : null,
        );
      },
    );
  }

  Widget _buildBase64Image() {
    try {
      final bytes = base64.decode(base64Data!);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Ошибка декодирования base64');
          return _buildErrorWidget();
        },
      );
    } catch (e) {
      print('❌ Ошибка base64: $e');
      return _buildErrorWidget();
    }
  }

  Widget _buildLoadingIndicator({double? progress}) {
    if (placeholder != null) return placeholder!;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: Center(
        child: progress != null
            ? CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
              )
            : const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (errorWidget != null) return errorWidget!;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.broken_image,
        size: 30,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) return placeholder!;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_not_supported,
        size: 30,
        color: Colors.grey,
      ),
    );
  }
}
