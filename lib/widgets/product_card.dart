// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  const ProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // УДАЛЕНО: описание, так как его нет в модели Product
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${product.price.toStringAsFixed(2)} ₽',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildQuantityControls(context),
              ],
            ),
            if (quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${product.price.toStringAsFixed(2)} × $quantity = ${(product.price * quantity).toStringAsFixed(2)} ₽',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls(BuildContext context) {
    if (quantity == 0) {
      return OutlinedButton(
        onPressed: () => onQuantityChanged(1),
        child: const Text('Добавить'),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onQuantityChanged(quantity - 1),
          icon: const Icon(Icons.remove, size: 18),
        ),
        // ИСПРАВЛЕНО: используем SizedBox вместо minWidth
        SizedBox(
          width: 30,
          child: Text(
            '$quantity',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          onPressed: () => onQuantityChanged(quantity + 1),
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}
