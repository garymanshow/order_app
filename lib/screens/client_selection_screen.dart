// lib/screens/client_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import '../models/client.dart';
import '../models/order_item.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart'; // ← ДОБАВЛЕН ИМПОРТ

class ClientSelectionScreen extends StatefulWidget {
  final String phone;
  final List<Client> clients;

  const ClientSelectionScreen({
    Key? key,
    required this.phone,
    required this.clients,
  }) : super(key: key);

  @override
  _ClientSelectionScreenState createState() => _ClientSelectionScreenState();
}

class _ClientSelectionScreenState extends State<ClientSelectionScreen> {
  late Future<List<ClientWithOrderInfo>> _clientsWithOrderInfoFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _clientsWithOrderInfoFuture = _loadClientsWithOrderInfo(widget.clients);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Выберите адрес доставки'),
        actions: [
          // 🔥 КНОПКА ОЧИСТКИ КЭША (только в debug)
          if (kDebugMode)
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _showClearCacheDialog(context),
              tooltip: 'Очистить весь кэш',
            ),
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
              }
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: widget.clients.isEmpty
          ? Center(child: Text('Клиенты не найдены'))
          : RefreshIndicator(
              onRefresh: () async {
                _refreshData();
                setState(() {});
                return Future.delayed(Duration(milliseconds: 500));
              },
              child: FutureBuilder<List<ClientWithOrderInfo>>(
                future: _clientsWithOrderInfoFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('Клиенты не найдены'));
                  }
                  final clientsWithInfo = snapshot.data!;
                  return ListView.builder(
                    itemCount: clientsWithInfo.length,
                    itemBuilder: (context, index) {
                      final clientInfo = clientsWithInfo[index];
                      final total = clientInfo.lastOrderTotal;

                      return ListTile(
                        title: Text(clientInfo.client.name ?? ''),
                        subtitle: Text(
                          total != null
                              ? 'Сумма заказа: ${total.toStringAsFixed(0)} ₽'
                              : 'Мин. заказ: ${(clientInfo.client.minOrderAmount ?? 0).toStringAsFixed(0)} ₽',
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
                          final productsProvider =
                              Provider.of<ProductsProvider>(context,
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

                          cartProvider.setClient(clientInfo.client);

                          if (clientInfo.activeOrders.isNotEmpty) {
                            for (var order in clientInfo.activeOrders) {
                              final product =
                                  productsProvider.products.firstWhereOrNull(
                                (p) => p.name == order.productName,
                              );
                              if (product != null) {
                                cartProvider.setQuantity(
                                  product.id,
                                  order.quantity,
                                  product.multiplicity,
                                  productsProvider.products,
                                );
                              }
                            }
                          }

                          Navigator.pushNamed(
                            context,
                            '/price',
                            arguments: clientInfo.client,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Future<List<ClientWithOrderInfo>> _loadClientsWithOrderInfo(
    List<Client> clients,
  ) async {
    final allOrders = await _loadAllCachedOrders();

    final List<ClientWithOrderInfo> result = [];

    for (var client in clients) {
      final phone = client.phone ?? '';
      final name = client.name ?? '';

      if (phone.isEmpty || name.isEmpty) {
        continue;
      }

      final clientOrders =
          allOrders.where((order) => order.clientName == name).toList();

      final activeOrders =
          clientOrders.where((order) => order.status == 'оформлен').toList();

      if (activeOrders.isNotEmpty) {
        double total =
            activeOrders.fold(0.0, (sum, order) => sum + order.totalPrice);
        result.add(ClientWithOrderInfo(
          client: client,
          lastOrderTotal: total,
          activeOrders: activeOrders,
        ));
      } else {
        result.add(ClientWithOrderInfo(client: client));
      }
    }

    return result;
  }

  Future<List<OrderItem>> _loadAllCachedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString('client_orders_data');

      if (ordersJson != null) {
        final list = jsonDecode(ordersJson) as List;
        return list
            .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Ошибка загрузки кэшированных заказов: $e');
    }
    return [];
  }

  // 🔥 НОВЫЙ МЕТОД: Диалог очистки кэша
  Future<void> _showClearCacheDialog(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Очистка кэша', style: TextStyle(color: Colors.red)),
        content: Text('Вы уверены, что хотите очистить ВЕСЬ кэш приложения?\n\n'
            'Это удалит все сохранённые данные, включая товары, заказы и настройки.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.clearAllCache();

      // Перезапуск приложения
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }
}

class ClientWithOrderInfo {
  final Client client;
  final double? lastOrderTotal;
  final List<OrderItem> activeOrders;

  ClientWithOrderInfo({
    required this.client,
    this.lastOrderTotal,
    this.activeOrders = const [],
  });
}
