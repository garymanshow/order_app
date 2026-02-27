// lib/widgets/product_image.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import 'app_image.dart';

class ProductImage extends StatelessWidget {
  final Product product;
  final double width;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;
  final bool
      useNetworkFallback; // использовать ли сетевой URL как запасной вариант

  const ProductImage({
    Key? key,
    required this.product,
    this.width = 60,
    this.height = 60,
    this.fit = BoxFit.contain,
    this.onTap,
    this.useNetworkFallback = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Формируем путь к asset на основе ID продукта
    final assetPath = 'assets/images/products/${product.id}.webp';

    return AppImage.asset(
      assetPath: assetPath,
      width: width,
      height: height,
      fit: fit,
      onTap: onTap,
      // 🔥 Используем errorWidget вместо errorBuilder
      errorWidget: _buildFallback(),
    );
  }

  Widget _buildFallback() {
    // Если разрешено использовать сетевой URL и он есть
    if (useNetworkFallback &&
        product.imageUrl != null &&
        product.imageUrl!.isNotEmpty) {
      return AppImage.network(
        url: product.imageUrl!,
        width: width,
        height: height,
        fit: fit,
        onTap: onTap,
        // 🔥 Используем errorWidget для сети
        errorWidget: _buildPlaceholder(),
      );
    }

    // Если нет network fallback - сразу заглушка
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_not_supported,
        size: 30,
        color: Colors.grey,
      ),
    );
  }
}
