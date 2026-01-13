import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/sheet_all_api_service.dart';

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
        authProvider.isClient ? authProvider.currentUser as Client : null;
    final clientDiscountPercent = client?.discount ?? 0;
    final discount = clientDiscountPercent / 100.0;
    final total = cartProvider.getTotal(productsProvider.products, discount);
    final minOrderAmount = client?.minOrderAmount ?? 0.0;
    final isOrderValid = total >= minOrderAmount && total > 0;

    print(
        'DEBUG CartScreen: total=$total, minOrderAmount=$minOrderAmount, isOrderValid=$isOrderValid');

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
                      final product =
                          productsProvider.getProductById(productId);

                      return ListTile(
                        title: Text(product?.name ?? 'Товар недоступен'),
                        subtitle: Text(
                            '${product?.price.toStringAsFixed(2) ?? '0.00'} ₽ × $quantity'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => cartProvider.removeItem(productId),
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
                          context, cartProvider, productsProvider, client),
                  child: _isSubmitting
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Отправить заказ'),
                            if (minOrderAmount > 0 && !isOrderValid)
                              Text(
                                  'Мин. сумма: ${minOrderAmount.toStringAsFixed(2)} ₽',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.orange)),
                          ],
                        ),
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
    ProductsProvider productsProvider,
    Client client,
  ) async {
    setState(() => _isSubmitting = true);
    final sheetsService = SheetAllApiService();
    final now = DateTime.now();
    final orderDate = DateFormat('dd.MM.yyyy').format(now);

    try {
      // 🔁 Удаляем старые заказы: статус = "заказ"
      final deleteSuccess = await sheetsService.delete(
        sheetName: 'Заказы',
        filters: {
          'Телефон': client.phone,
          'Клиент': client.name,
          'Статус': 'заказ',
        },
      );

      if (!deleteSuccess) {
        throw Exception('Не удалось удалить старые заказы');
      }

      // ➕ Формируем новые заказы со статусом "оформлен"
      final ordersRows = <List<dynamic>>[];
      cartProvider.cartItems.forEach((productId, quantity) {
        final product =
            productsProvider.products.firstWhere((p) => p.id == productId);
        ordersRows.add([
          'оформлен', // Статус
          product.name, // Наименование
          quantity, // Количество
          product.price * quantity, // Итоговая цена
          orderDate, // Дата
          client.phone, // Телефон
          client.name, // Клиент
        ]);
      });

      if (ordersRows.isEmpty) return;

      // ➕ Создаём новые заказы
      final createSuccess = await sheetsService.create(
        sheetName: 'Заказы',
        data: ordersRows,
      );

      if (createSuccess) {
        cartProvider.clearAll();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Заказ успешно отправлен!')));
      } else {
        throw Exception('Не удалось создать заказ');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
