// lib/widgets/product_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';

class ProductItem extends StatelessWidget {
  final Product product;

  const ProductItem({Key? key, required this.product}) : super(key: key);

  /// Округляет значение вверх до ближайшей кратности
  int _roundUpToMultiplicity(int value, int multiplicity) {
    if (multiplicity <= 0 || value <= 0) return 0;
    return ((value + multiplicity - 1) ~/ multiplicity) * multiplicity;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final productsProvider =
        Provider.of<ProductsProvider>(context, listen: false);
    final currentQuantity = cartProvider.getQuantity(product.id);

    void _updateQuantity(int newQuantity) {
      if (newQuantity < 0) return;
      cartProvider.setQuantity(
        product.id,
        newQuantity,
        product.multiplicity,
        productsProvider.products,
      );
    }

    void _handleInput(String input) {
      if (input.isEmpty) {
        _updateQuantity(0);
        return;
      }

      final parsed = int.tryParse(input);
      if (parsed == null || parsed < 0) {
        _updateQuantity(0);
        return;
      }

      final rounded = _roundUpToMultiplicity(parsed, product.multiplicity);
      if (rounded != parsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Округлено до кратности ${product.multiplicity}: $rounded'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _updateQuantity(rounded);
    }

    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        children: [
          // Изображение товара
          product.hasImageUrl
              ? Image.network(
                  product.imageUrl!,
                  height: 150,
                  fit: BoxFit.cover,
                )
              : product.hasImageBase64
                  ? Image.memory(
                      base64Decode(product.imageBase64!),
                      height: 150,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 150,
                      color: Colors.grey[300],
                      child: Center(child: Text('Нет изображения')),
                    ),

          // Информация о товаре
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),

                // 💰 ЦЕНА — с двумя знаками после запятой
                Text(
                  '${product.price.toStringAsFixed(2)} ₽',
                  style: TextStyle(fontSize: 16, color: Colors.green),
                ),
                SizedBox(height: 12),

                // Кратность
                Text(
                  'Кратность: ${product.multiplicity}',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12),

                // Управление количеством
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _updateQuantity(
                        currentQuantity - product.multiplicity,
                      ),
                      icon: Icon(Icons.remove, color: Colors.red),
                    ),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        controller: TextEditingController(
                          text: currentQuantity.toString(),
                        ),
                        onChanged: _handleInput,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _updateQuantity(
                        currentQuantity + product.multiplicity,
                      ),
                      icon: Icon(Icons.add, color: Colors.green),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed:
                          (currentQuantity > 0 && !productsProvider.isLoading)
                              ? () {
                                  cartProvider.addItem(
                                    product.id,
                                    currentQuantity,
                                    productsProvider.products,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Добавлено ${currentQuantity} шт. "${product.name}"',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                      child: Text('Добавить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
