// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/sheets_api_service.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final productsProvider = Provider.of<ProductsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Получаем данные клиента (если есть)
    final client =
        authProvider.isClient ? authProvider.currentUser as Client : null;

    // Рассчитываем скидку
    final clientDiscountPercent = client?.discount ?? 0;
    final discount = clientDiscountPercent / 100.0;
    final total = cartProvider.getTotal(productsProvider.products, discount);

    // 🔄 Загрузка товаров
    if (productsProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Корзина')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка прайс-листа...'),
            ],
          ),
        ),
      );
    }

    // ❌ Ошибка загрузки
    if (productsProvider.error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Корзина')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'Не удалось загрузить товары',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(productsProvider.error!),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  productsProvider.loadProducts();
                },
                child: Text('Повторить'),
              ),
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
                    child: Text(
                      'Корзина пуста',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    itemCount: cartProvider.cartItems.length,
                    itemBuilder: (context, index) {
                      final productId =
                          cartProvider.cartItems.keys.elementAt(index);
                      final quantity = cartProvider.cartItems[productId]!;
                      final product =
                          productsProvider.getProductById(productId);

                      return ListTile(
                        title: Text(
                          product?.name ?? 'Товар недоступен (ID: $productId)',
                          style: product != null
                              ? null
                              : TextStyle(
                                  color: Colors.red,
                                  fontStyle: FontStyle.italic),
                        ),
                        subtitle: Text(
                          product != null
                              ? '${product.price.toStringAsFixed(2)} ₽ × $quantity'
                              : 'Товар удалён из прайс-листа',
                        ),
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
                // Скидка (если есть)
                if (clientDiscountPercent > 0)
                  Text(
                    'Скидка: ${clientDiscountPercent}%',
                    style: TextStyle(fontSize: 16, color: Colors.green),
                  ),
                SizedBox(height: 4),
                // Итог
                Text(
                  'Итого: ${total.toStringAsFixed(2)} ₽',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                // Кнопка отправки
                ElevatedButton(
                  onPressed: (cartProvider.cartItems.isEmpty || client == null)
                      ? null
                      : () async {
                          final success = await _submitOrder(
                            context,
                            cartProvider,
                            productsProvider,
                            client,
                          );
                          if (success) {
                            cartProvider.clearAll();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Заказ успешно отправлен!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка отправки заказа')),
                            );
                          }
                        },
                  child: Text('Отправить заказ'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Отправка заказа в Google Sheets
  Future<bool> _submitOrder(
    BuildContext context,
    CartProvider cartProvider,
    ProductsProvider productsProvider,
    Client client,
  ) async {
    final now = DateTime.now();
    final formatter = DateFormat('dd.MM.yyyy');
    final orderDate = formatter.format(now);

    final sheetsService = SheetsApiService();

    // 🔁 Помечаем старые позиции как "Изменено клиентом"
    await sheetsService.updateOrderStatus(
      phone: client.phone,
      date: orderDate,
      newStatus: 'Изменено клиентом',
    );

    // ➕ Формируем новые позиции
    final ordersRows = <List<dynamic>>[];
    cartProvider.cartItems.forEach((productId, quantity) {
      final product = productsProvider.getProductById(productId);
      if (product != null) {
        ordersRows.add([
          'Новый', // Статус
          client.phone, // Телефон клиента
          product.name, // Наименование товара
          quantity, // Количество
          product.price, // Цена за единицу
          product.price * quantity, // Сумма позиции
          orderDate, // Дата заказа
          '', // TG ID (оставляем пустым)
          client.name, // Клиент
        ]);
      }
    });

    if (ordersRows.isEmpty) return false;
    return await sheetsService.appendOrders(ordersRows);
  }
}
