// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';
import '../models/order_item.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CartProvider>(
      builder: (context, authProvider, cartProvider, child) {
        final cartItems = cartProvider.cartItems;
        final products = authProvider.clientData?.products ?? [];

        if (cartItems.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Корзина'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(child: Text('Корзина пуста')),
          );
        }

        double total = 0;
        for (var order in cartItems) {
          total += order.totalPrice;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Корзина: ${total.toStringAsFixed(2)} ₽'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: cartItems.length,
            itemBuilder: (context, index) {
              final order = cartItems[index];
              final product = products.firstWhere(
                (p) => p.id == order.priceListId,
                orElse: () =>
                    Product(id: '', name: order.productName, price: 0.0),
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cake, color: Colors.grey),
                  ),
                  title: Text(order.productName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${product.price.toStringAsFixed(2)} ₽ × ${order.quantity}'),
                      Text(
                        '= ${order.totalPrice.toStringAsFixed(2)} ₽',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          cartProvider.setQuantity(
                            order.priceListId,
                            order.quantity - product.multiplicity,
                            product.multiplicity,
                          );
                        },
                      ),
                      Container(
                        width: 30,
                        alignment: Alignment.center,
                        child: Text(order.quantity.toString()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          cartProvider.setQuantity(
                            order.priceListId,
                            order.quantity + product.multiplicity,
                            product.multiplicity,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
