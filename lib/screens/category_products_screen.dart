// lib/screens/category_products_screen.dart
import 'package:flutter/material.dart';
import '../models/price_category.dart';
import '../models/product.dart';
import '../models/price_item.dart';
import 'admin/admin_price_item_form_screen.dart';

class CategoryProductsScreen extends StatelessWidget {
  final PriceCategory category;
  final List<Product> products;
  final Map<String, dynamic> stats;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.products,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminPriceItemFormScreen(
                    initialCategoryId: category.id,
                    initialCategoryName: category.name,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('В этой категории пока нет товаров'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminPriceItemFormScreen(
                            initialCategoryId: category.id,
                            initialCategoryName: category.name,
                          ),
                        ),
                      );
                    },
                    child: const Text('Добавить товар'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(context, product);
              },
            ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
              ? (product.imageUrl!.startsWith('http')
                  ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                  : Image.asset(product.imageUrl!, fit: BoxFit.cover))
              : Icon(Icons.image, color: Colors.grey[400]),
        ),
        title: Text(
          product.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${product.price.toStringAsFixed(0)} ₽ • Кратность: ${product.multiplicity}',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          final priceItem = PriceItem(
            id: product.id,
            name: product.name,
            price: product.price,
            category: product.categoryName,
            unit: 'шт',
            weight: double.tryParse(product.weight) ?? 0.0,
            multiplicity: product.multiplicity,
            photoUrl: product.imageUrl,
            description: product.composition,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminPriceItemFormScreen(item: priceItem),
            ),
          );
        },
      ),
    );
  }
}
