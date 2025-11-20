// lib/screens/price_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/products_provider.dart';
import '../screens/cart_screen.dart';
import '../widgets/product_item.dart';

class PriceListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final productsProvider = Provider.of<ProductsProvider>(context);

    // Загружаем товары при первом входе
    if (productsProvider.products.isEmpty && !productsProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        productsProvider.loadProducts();
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text('Прайс-лист')),
      body: productsProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : productsProvider.error != null
              ? Center(child: Text(productsProvider.error!))
              : productsProvider.products.isEmpty
                  ? Center(child: Text('Нет товаров'))
                  : ListView.builder(
                      itemCount: productsProvider.products.length,
                      itemBuilder: (context, index) {
                        return ProductItem(
                            product: productsProvider.products[index]);
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => CartScreen()));
        },
        child: Icon(Icons.shopping_cart),
      ),
    );
  }
}
