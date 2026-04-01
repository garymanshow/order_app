// lib/screens/client_selection_screen.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client.dart';
import '../models/order_item.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';

class ClientSelectionScreen extends StatelessWidget {
  final String phone;
  final List<Client> clients;

  const ClientSelectionScreen({
    Key? key,
    required this.phone,
    required this.clients,
  }) : super(key: key);

  // Расчет суммы клиента из его заказов
  double _calculateClientTotal(
    Client client,
    List<OrderItem> orders,
  ) {
    double total = 0;

    final clientOrders = orders
        .where((o) =>
            o.clientPhone == client.phone &&
            o.clientName == client.name &&
            o.quantity > 0)
        .toList();

    for (var order in clientOrders) {
      total += order.totalPrice;
    }

    return total;
  }

  // Проверка минимальной суммы для клиента
  bool _meetsMinimumOrder(Client client, double total) {
    final minAmount = client.minOrderAmount ?? 0;
    return total >= minAmount;
  }

  // Метод выхода с проверкой несохраненных изменений
  Future<void> _logoutAndReturnToAuth(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Проверяем, есть ли неотправленные заказы
    if (cartProvider.cartItems.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Несохраненные изменения'),
          content: const Text(
              'У вас есть неотправленные заказы. При выходе они будут потеряны.\n\n'
              'Хотите выйти без сохранения?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Остаться'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Выйти без сохранения'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    authProvider.logout().then((_) {
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }).catchError((error) {
      print('❌ Ошибка при выходе: $error');
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  // Метод сброса настроек (отладка)
  Future<void> _resetAppSettings(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс настроек'),
        content: const Text('Вы уверены? Это удалит все локальные данные.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки сброшены!')),
        );
      }
    }
  }

  // Отправка всех заказов
  Future<void> _submitAllOrders(
      BuildContext context, AuthProvider authProvider) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final apiService = ApiService();

    // Проверяем, есть ли заказы для отправки
    if (cartProvider.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет заказов для отправки')),
      );
      return;
    }

    // Проверяем минимальные суммы для всех клиентов
    final orders = authProvider.clientData!.orders;
    final clientsWithIssues = <String>[];

    for (var client in clients) {
      final total = _calculateClientTotal(client, orders);
      if (total > 0 && !_meetsMinimumOrder(client, total)) {
        clientsWithIssues.add(client.name ?? 'Неизвестный клиент');
      }
    }

    // Если есть проблемы с минимальными суммами
    if (clientsWithIssues.isNotEmpty) {
      final message =
          'Следующие заказы не соответствуют минимальной сумме:\n${clientsWithIssues.join('\n')}\n\nОтправить только соответствующие?';

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Внимание!'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Отправить соответствующие'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Оформить заказы'),
        content: const Text(
            'Все соответствующие требованиям заказы будут отправлены. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Оформить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 🔥 ПЕРЕДАЕМ СТАТУС "оформлен" ЯВНО
    // Это означает: "Удали старые заказы со статусом 'оформлен' и создай новые"
    final success = await cartProvider.submitAllOrders(
      context,
      apiService,
      deleteStatus: 'оформлен',
    );

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказы успешно отправлены!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при обновлении заказов')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CartProvider>(
      builder: (context, authProvider, cartProvider, child) {
        if (authProvider.clientData == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Загрузка данных...'),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        // 🔥 ПРОВЕРКА НА НАЛИЧИЕ КЛИЕНТОВ
        if (clients.isEmpty) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Нет клиентов для телефона $phone'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      authProvider.logout();
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (route) => false);
                    },
                    child: Text('Выйти'),
                  ),
                ],
              ),
            ),
          );
        }

        final orders = authProvider.clientData!.orders;
        final hasUnsavedOrders = cartProvider.cartItems.isNotEmpty;

        // Рассчитываем суммы и проверяем минимальные для каждого клиента
        final clientsWithTotals = clients.map((client) {
          final total = _calculateClientTotal(client, orders);
          final meetsMin = _meetsMinimumOrder(client, total);
          return _ClientWithTotal(
            client: client,
            total: total,
            meetsMinimum: meetsMin,
          );
        }).toList();

        // Общая сумма всех клиентов
        double totalAllClients =
            clientsWithTotals.fold(0, (sum, item) => sum + item.total);

        // Проверяем, есть ли проблемы с минимальными суммами
        final hasIssues = clientsWithTotals
            .any((item) => item.total > 0 && !item.meetsMinimum);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              totalAllClients > 0
                  ? 'Выберите клиента\n(всего на ${totalAllClients.toStringAsFixed(2)} ₽)'
                  : 'Выберите клиента',
              maxLines: 2,
              softWrap: true,
            ),
            toolbarHeight: totalAllClients > 0 ? 80.0 : kToolbarHeight,
            leading: IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Выйти из аккаунта',
              onPressed: () => _logoutAndReturnToAuth(context),
            ),
            actions: [
              if (totalAllClients > 0)
                IconButton(
                  icon: Icon(
                    Icons.shopping_cart_checkout,
                    color: hasIssues ? Colors.orange : null,
                  ),
                  tooltip: hasIssues
                      ? 'Оформить заказы (есть проблемы с минимальными суммами)'
                      : 'Оформить все заказы',
                  onPressed: () => _submitAllOrders(context, authProvider),
                ),
              if (kDebugMode)
                IconButton(
                  icon: const Icon(Icons.settings_backup_restore,
                      color: Colors.orange),
                  tooltip: 'Сбросить настройки (отладка)',
                  onPressed: () => _resetAppSettings(context),
                ),
            ],
          ),
          body: ListView.builder(
            itemCount: clientsWithTotals.length,
            itemBuilder: (context, index) {
              final item = clientsWithTotals[index];
              final hasItems = item.total > 0;

              return ListTile(
                title: Text(item.client.name ?? ''),
                subtitle: hasItems
                    ? Text(
                        '${item.total.toStringAsFixed(2)} ₽',
                        style: TextStyle(
                          color: item.meetsMinimum ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Text(
                        'Минимальная сумма: ${item.client.minOrderAmount?.toStringAsFixed(0) ?? '0'} ₽',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                trailing: hasItems
                    ? Chip(
                        label: Text('${item.total.toStringAsFixed(0)} ₽'),
                        backgroundColor: Colors.green.shade100,
                        avatar: const Icon(Icons.shopping_cart, size: 16),
                      )
                    : null,
                onTap: () {
                  print('🔍 Выбран клиент: ${item.client.name}');

                  // Устанавливаем клиента
                  authProvider.selectClient(item.client);

                  // Переход на прайс-лист
                  Navigator.pushReplacementNamed(context, '/price');
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ClientWithTotal {
  final Client client;
  final double total;
  final bool meetsMinimum;

  const _ClientWithTotal({
    required this.client,
    required this.total,
    required this.meetsMinimum,
  });
}
