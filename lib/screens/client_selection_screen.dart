// lib/screens/client_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart'; // ← добавлен импорт
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../services/google_sheets_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
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
                final cartProvider =
                    Provider.of<CartProvider>(context, listen: false);
                cartProvider.reset();

                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();
                // AuthOrHomeRouter автоматически вернёт на авторизацию
              }
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: clients.isEmpty
          ? Center(child: Text('Клиенты не найдены'))
          : ListView.builder(
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadOrdersForClient(client),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                          title: Text(client.name),
                          subtitle: Text('Загрузка...'));
                    }

                    double? total;
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final orderItems = snapshot.data!;
                      total = orderItems
                          .map((o) =>
                              double.tryParse(o['Итоговая цена'].toString()) ??
                              0.0)
                          .fold<double>(0.0, (double a, double b) => a + b);
                    }
                    return ListTile(
                      title: Text(client.name),
                      subtitle: Text(
                        total != null
                            ? 'Сумма заказа: ${total.toStringAsFixed(0)} ₽'
                            : 'Мин. заказ: ${(client.minOrderAmount ?? 0).toStringAsFixed(0)} ₽',
                        style: TextStyle(
                          color: total != null
                              ? Colors.green[700]
                              : Colors.grey[600],
                          fontWeight: total != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () async {
                        final productsProvider = Provider.of<ProductsProvider>(
                            context,
                            listen: false);
                        final cartProvider =
                            Provider.of<CartProvider>(context, listen: false);

                        if (productsProvider.products.isEmpty &&
                            !productsProvider.isLoading) {
                          await productsProvider.loadProducts();
                        }
                        while (productsProvider.isLoading) {
                          await Future.delayed(
                              const Duration(milliseconds: 50));
                        }

                        final service =
                            GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
                        await service.init();
                        cartProvider.initialize(service, client);

                        final ordersForClient = snapshot.data;
                        if (ordersForClient != null) {
                          for (var item in ordersForClient) {
                            final product =
                                productsProvider.products.firstWhereOrNull(
                              (p) => p.name == item['Название'],
                            );
                            if (product != null) {
                              cartProvider.setTemporaryQuantity(
                                product.id,
                                int.tryParse(item['Количество'].toString()) ??
                                    0,
                              );
                            }
                          }
                        }
                        Navigator.pushNamed(context, '/price',
                            arguments: client);
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadOrdersForClient(Client client) async {
    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    return await service.read(
      sheetName: 'Заказы',
      filters: [
        {'column': 'Телефон', 'value': client.phone},
        {'column': 'Клиент', 'value': client.name},
        {'column': 'Статус', 'value': 'оформлен'}
      ],
    );
  }
}
