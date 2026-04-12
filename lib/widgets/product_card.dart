// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_image.dart'; // ← Импортируем новый виджет

class ProductCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final Function(int) onQuantityChanged;

  const ProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 Фото товара через ProductImage
            ProductImage(
              product: product,
              width: 60,
              height: 60,
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

  // 🔥 Методы _buildImage и _buildPlaceholder больше не нужны,
  // так как всю логику берет на себя ProductImage
}
