// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isSubmitting = false;
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CartProvider>(
      builder: (context, authProvider, cartProvider, child) {
        // Проверка авторизации
        if (!authProvider.isAuthenticated || authProvider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Корзина')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // 🔥 ИНИЦИАЛИЗАЦИЯ CartProvider при первом рендере
        if (!_isInitialized && authProvider.clientData != null) {
          _isInitialized = true;
          cartProvider.setClientData(authProvider.clientData);
          if (authProvider.currentUser is Client) {
            cartProvider.setClient(authProvider.currentUser as Client);
          }
        }

        final client = authProvider.currentUser as Client?;
        final clientData = authProvider.clientData;

        // Проверка наличия данных
        if (client == null || clientData == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ошибка')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Данные не загружены'),
                  ElevatedButton(
                    onPressed: () async {
                      await authProvider
                          .login(authProvider.currentUser!.phone!);
                    },
                    child: const Text('Повторить загрузку'),
                  ),
                ],
              ),
            ),
          );
        }

        final products = clientData.products;
        final discount = (client.discount ?? 0) / 100.0;
        final minOrderAmount = client.minOrderAmount ?? 0.0;
        final total = cartProvider.getTotal(products, discount);
        final isOrderValid = total >= minOrderAmount && total > 0;

        return Scaffold(
          appBar: AppBar(title: const Text('Корзина')),
          body: Column(
            children: [
              Expanded(
                child: _buildCartItems(cartProvider, products),
              ),
              _buildOrderSummary(client, discount, total, minOrderAmount),
              _buildSubmitButton(isOrderValid),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartItems(CartProvider cartProvider, List<Product> products) {
    final cartItems = cartProvider.cartItems;

    if (cartItems.isEmpty) {
      return const Center(child: Text('Корзина пуста'));
    }

    return ListView.builder(
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        final productId = cartItems.keys.elementAt(index);
        final quantity = cartItems[productId]!;

        final product = products.firstWhere(
          (p) => p.id == productId,
          orElse: () => Product(
            id: 'not_found',
            name: 'Товар не найден',
            price: 0.0,
            multiplicity: 1,
            composition: '',
            weight: '',
            nutrition: '',
            storage: '',
            packaging: '',
            categoryName: '',
            categoryId: '',
          ),
        );

        final totalForItem = product.price * quantity;

        return ListTile(
          title: Text(product.name),
          subtitle: Text(
            'Цена: ${product.price.toStringAsFixed(2)} ₽ × $quantity шт',
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (quantity > 0)
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.red),
                  onPressed: () {
                    cartProvider.setQuantity(
                      productId,
                      quantity - product.multiplicity,
                      product.multiplicity,
                      products,
                    );
                  },
                ),
              Text('$quantity',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.green),
                onPressed: () {
                  cartProvider.setQuantity(
                    productId,
                    quantity + product.multiplicity,
                    product.multiplicity,
                    products,
                  );
                },
              ),
            ],
          ),
          leading: Text('${totalForItem.toStringAsFixed(2)} ₽'),
        );
      },
    );
  }

  Widget _buildOrderSummary(
      Client client, double discount, double total, double minOrderAmount) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (discount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Скидка клиента:'),
                Text('${(discount * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${total.toStringAsFixed(2)} ₽',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          if (total < minOrderAmount && total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Минимальная сумма заказа: ${minOrderAmount.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isOrderValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton(
        onPressed: (!isOrderValid || _isSubmitting)
            ? null
            : () => _submitOrder(context),
        child: _isSubmitting
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
            : const Text('Оформить заказ', style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 48),
          backgroundColor: isOrderValid ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }

  Future<void> _submitOrder(BuildContext context) async {
    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final client = authProvider.currentUser as Client;
      final clientData = authProvider.clientData;

      if (clientData == null) {
        throw Exception('Данные клиента недоступны');
      }

      final products = clientData.products;
      final apiService = ApiService();

      await Provider.of<CartProvider>(context, listen: false)
          .submitOrder(products, apiService);

      _showSuccessMessage(context);

      Navigator.pushNamedAndRemoveUntil(context, '/price', (route) => false);
    } catch (e) {
      _showErrorMessage(context, e.toString());
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Заказ успешно оформлен!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Ошибка: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
