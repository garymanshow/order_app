// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';
import '../models/user.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final productsProvider = Provider.of<ProductsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final client =
        authProvider.isClient ? authProvider.currentUser as Client? : null;
    final clientDiscountPercent = client?.discount ?? 0;
    final discount = clientDiscountPercent / 100.0;
    final total = cartProvider.getTotal(productsProvider.products, discount);
    final minOrderAmount = client?.minOrderAmount ?? 0.0;
    final isOrderValid = total >= minOrderAmount && total > 0;

    if (productsProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Корзина')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (productsProvider.error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Корзина')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text('Ошибка загрузки товаров', style: TextStyle(fontSize: 18)),
              Text(productsProvider.error!),
            ],
          ),
        ),
      );
    }

    final products = productsProvider.products;

    return Scaffold(
      appBar: AppBar(title: Text('Корзина')),
      body: Column(
        children: [
          Expanded(
            child: cartProvider.cartItems.isEmpty
                ? Center(
                    child:
                        Text('Корзина пуста', style: TextStyle(fontSize: 18)))
                : ListView.builder(
                    itemCount: cartProvider.cartItems.length,
                    itemBuilder: (context, index) {
                      final productId =
                          cartProvider.cartItems.keys.elementAt(index);
                      final quantity = cartProvider.cartItems[productId]!;
                      final product = products.firstWhere(
                        (p) => p.id == productId,
                        orElse: () => Product(
                          id: '',
                          name: 'Товар недоступен',
                          price: 0.0,
                          multiplicity: 1,
                        ),
                      );

                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                            '${product.price.toStringAsFixed(2)} ₽ × $quantity'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              cartProvider.removeItem(productId, products),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (clientDiscountPercent > 0)
                  Text('Скидка: ${clientDiscountPercent}%',
                      style: TextStyle(color: Colors.green)),
                SizedBox(height: 4),
                Text('Итого: ${total.toStringAsFixed(2)} ₽',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (client == null || !isOrderValid || _isSubmitting)
                      ? null
                      : () => _submitOrder(
                          context, cartProvider, products, client!),
                  child: _isSubmitting
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white))
                      : Text('Оформить заказ'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder(
    BuildContext context,
    CartProvider cartProvider,
    List<Product> products,
    Client client,
  ) async {
    setState(() => _isSubmitting = true);

    try {
      // ✅ Используем метод из CartProvider
      await cartProvider.submitOrder(products);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Заказ успешно оформлен!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка оформления: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
