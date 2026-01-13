// lib/screens/client_selection_screen.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../services/sheet_all_api_service.dart';
//import '../screens/price_list_screen.dart';

class ClientSelectionScreen extends StatelessWidget {
  final String phone;
  final List<Client> clients;

  const ClientSelectionScreen({
    Key? key,
    required this.phone,
    required this.clients,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Выберите адрес доставки'),
        actions: [
          // Кнопка выхода
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              // Показать диалог подтверждения
              final bool? confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Выход'),
                  content: Text('Вы действительно хотите выйти?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Выйти', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                // Очистить корзину
                final cartProvider =
                    Provider.of<CartProvider>(context, listen: false);
                cartProvider.clearAll();

                // Выйти из системы
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();

                // Автоматически вернуться на экран авторизации
                // (AuthOrHomeRouter сам перенаправит)
              }
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: clients.length,
        itemBuilder: (context, index) {
          final client = clients[index];
          return ListTile(
            title: Text(client.name),
            subtitle: Text(
              '${client.address} • Мин. заказ: ${(client.minOrderAmount ?? 0).toStringAsFixed(0)} ₽',
            ),
            onTap: () async {
              print('DEBUG: 🔄 Нажатие на клиента: ${client.name}');
              final productsProvider =
                  Provider.of<ProductsProvider>(context, listen: false);
              final cartProvider =
                  Provider.of<CartProvider>(context, listen: false);

              print('📊 Проверяем состояние прайса...');
              print(
                  '📊 productsProvider.products.isEmpty: ${productsProvider.products.isEmpty}');
              print(
                  '📊 productsProvider.isLoading: ${productsProvider.isLoading}');

              // Загрузить прайс-лист, если не загружен
              if (productsProvider.products.isEmpty &&
                  !productsProvider.isLoading) {
                print('DEBUG: 🚀 Запускаем загрузку прайса...');
                await productsProvider.loadProducts();
                print('DEBUG: ✅ Загрузка прайса завершена');
              } else {
                print('DEBUG: ℹ️ Прайс уже загружен или загружается');
              }

              // Дождаться завершения загрузки
              while (productsProvider.isLoading) {
                print('DEBUG: ⏳ Ожидаем загрузку прайса...');
                await Future.delayed(const Duration(milliseconds: 50));
              }

              if (productsProvider.error != null) {
                print('DEBUG: ❌ Ошибка прайса: ${productsProvider.error}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Ошибка прайса: ${productsProvider.error}')),
                );
                return;
              }

              print('DEBUG: 🔑 Загружаем заказы клиента ${client.name} ...');
              // 🔑 Шаг 3: ЗАГРУЗИТЬ ЗАКАЗЫ КЛИЕНТА и ЗАПОЛНИТЬ КОРЗИНУ
              final service = SheetAllApiService();
              final orders = await service.read(sheetName: 'Заказы', filters: [
                {'column': 'Телефон', 'value': client.phone},
                {'column': 'Клиент', 'value': client.name},
                {'column': 'Статус', 'value': 'заказ'}
              ]);

              print('DEBUG: 📦 Получено заказов: ${orders.length}');

              // Очистить и заполнить корзину
              cartProvider.clearAll();
              final products = productsProvider.products;
              print('DEBUG: 📦 Товаров в прайсе: ${products.length}');

              for (var order in orders) {
                final orderMap = order as Map<String, dynamic>;
                final productName = orderMap['Название']?.toString() ?? '';
                print('DEBUG: 🔍 Ищем товар: "$productName"');
                final product = products.firstWhereOrNull(
                  (p) => p.name == productName,
                );
                if (product != null) {
                  print('DEBUG: ✅ Найден товар: ${product.name}');
                  cartProvider.setTemporaryQuantity(
                      product.id, (orderMap['Количество'] as int?) ?? 0);
                } else {
                  print('DEBUG: ❌ Товар "$productName" не найден в прайсе!');
                }
              }

              // Инициализировать корзину и загрузить заказы
              cartProvider.initialize(SheetAllApiService(), client);
              await cartProvider.loadFromOrders(productsProvider.products);

              // Перейти к прайс-листу
              print('DEBUG: 🚀 Переход к прайс-листу...');
              Navigator.pushNamed(
                context,
                '/price',
                arguments: client,
              );
              print('DEBUG: ✅ Переход выполнен');
            },
          );
        },
      ),
    );
  }
}
