// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final Function(int) onQuantityChanged;

  const ProductCard({
    Key? key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото товара
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildImage(),
            ),
            const SizedBox(width: 12),

            // Название товара
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price.toStringAsFixed(2)} ₽',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Выбор количества
            Expanded(
              flex: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Кнопка уменьшения
                      IconButton(
                        icon: const Icon(Icons.remove, size: 20),
                        tooltip: 'Меньше',
                        onPressed: quantity > 0
                            ? () {
                                print(
                                    '➖ Уменьшение: ${quantity - product.multiplicity}');
                                onQuantityChanged(
                                    quantity - product.multiplicity);
                              }
                            : null,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),

                      // Текущее количество
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          quantity.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Кнопка увеличения
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Больше',
                        onPressed: () {
                          print(
                              '➕ Увеличение: ${quantity + product.multiplicity}');
                          onQuantityChanged(quantity + product.multiplicity);
                        },
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  // Сумма за позицию (если выбрано)
                  if (quantity > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${(product.price * quantity).toStringAsFixed(2)} ₽',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (product.hasImageUrl || product.hasImageBase64) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          product.imageUrl ?? '',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.cake,
        size: 30,
        color: Colors.grey,
      ),
    );
  }
}
