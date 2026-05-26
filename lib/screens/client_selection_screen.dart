// lib/screens/client_selection_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client.dart';
import '../models/order_item.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';

class ClientSelectionScreen extends StatefulWidget {
  final String phone;
  final List<Client> clients;

  const ClientSelectionScreen({
    super.key,
    required this.phone,
    required this.clients,
  });

  @override
  State<ClientSelectionScreen> createState() => _ClientSelectionScreenState();
}

class _ClientSelectionScreenState extends State<ClientSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // 🔥 ЗАЩИТА ОТ ПЕРЕМЕШИВАНИЯ: При возвращении на этот экран
    // сбрасываем временного клиента, которого мог оставить submitAllOrders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      if (cartProvider.isInitialized) {
        cartProvider.reset(); // Вернет _currentClient в null
      }
    });
  }

  // Расчет суммы клиента
  double _calculateClientTotal(
    Client client,
    List<OrderItem> orders,
  ) {
    double total = 0;

    final clientOrders = orders
        .where((o) =>
            o.clientPhone == client.phone &&
            o.clientName == client.name &&
            o.status == 'оформлен' && // Фильтруем ТОЛЬКО по статусу!
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

    // Проверяем, есть ли ЛОКАЛЬНЫЕ НЕОТПРАВЛЕННЫЕ заказы (синие не считаются!)
    bool hasUnsaved = false;
    if (authProvider.clientData != null) {
      hasUnsaved = authProvider.clientData!.orders.any((o) =>
          o.status == 'оформлен' && o.isLocalDraft == true && o.quantity > 0);
    }

    if (hasUnsaved) {
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
      debugPrint('❌ Ошибка при выходе: $error');
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
    final apiService = ApiService();

    // Берем из глобального списка всё, что оформлено
    final allOrders = authProvider.clientData!.orders;
    final ordersReadyToSend = allOrders
        .where((o) => o.status == 'оформлен' && o.quantity > 0)
        .toList();

    if (ordersReadyToSend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет заказов для отправки')),
      );
      return;
    }

    // 🔥 НОВАЯ ПРОВЕРКА: Есть ли хоть один НАСТОЯЩИЙ черновик?
    // Если все заказы на сервере (isLocalDraft == false), отправлять нечего.
    final hasActualDrafts =
        ordersReadyToSend.any((o) => o.isLocalDraft == true);
    if (!hasActualDrafts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Все текущие заказы уже отправлены на сервер'),
          backgroundColor: Colors.blue,
        ),
      );
      return; // Прерываем отправку
    }

    // Проверяем минимальные суммы для всех клиентов
    final clientsWithIssues = <String>[];

    for (var client in widget.clients) {
      final total = _calculateClientTotal(client, allOrders);
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

    // --- ЗДЕСЬ СОЗДАЮТСЯ ПЕРЕМЕННЫЕ ---
    final failedClients = clientsWithIssues;

    // Простая и понятная группировка по клиентам
    final validOrders = <String, List<OrderItem>>{};
    for (var item in ordersReadyToSend) {
      // Пропускаем тех, кто не прошел по минимальной сумме
      if (failedClients.any((f) => item.clientName.startsWith(f))) continue;

      final key = '${item.clientPhone}_${item.clientName}';
      validOrders.putIfAbsent(key, () => []);
      validOrders[key]!.add(item);
    }

    if (validOrders.isEmpty) return;

    // Вызываем отправку
    final success = await apiService
        .submitOrderBatch(validOrders.values.expand((list) => list).toList());

    // --- ЗДЕСЬ ОНИ ИСПОЛЬЗУЮТСЯ ---
    if (context.mounted) {
      if (success) {
        // Отправляем на сервер ТОЛЬКО те заказы, которые реально улетели
        final actuallySentOrders =
            validOrders.values.expand((list) => list).toList();

        if (actuallySentOrders.isNotEmpty) {
          authProvider.markOrdersAsSent(actuallySentOrders);
        }

        String successText =
            '✅ Успешно отправлено заказов: ${validOrders.length}';
        if (failedClients.isNotEmpty) {
          successText +=
              '\n⚠️ Пропущено из-за минималки: ${failedClients.length}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successText),
            backgroundColor:
                failedClients.isNotEmpty ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Ошибка при отправке заказов'),
            backgroundColor: Colors.red,
          ),
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
                children: const [
                  Text('Загрузка данных...'),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        // 🔥 ПРОВЕРКА НА НАЛИЧИЕ КЛИЕНТОВ
        if (widget.clients.isEmpty) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Нет клиентов для телефона ${widget.phone}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      authProvider.logout();
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (route) => false);
                    },
                    child: const Text('Выйти'),
                  ),
                ],
              ),
            ),
          );
        }

        // 🔥 Берем заказы напрямую из AuthProvider для отрисовки кнопок
        final orders = authProvider.clientData!.orders;

        // Рассчитываем суммы и проверяем минимальные для каждого клиента
        final clientsWithTotals = widget.clients.map((client) {
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

        // 🔥 НОВОЕ: Проверяем, есть ли ХОТЯ БЫ ОДИН заказ, который МОЖНО отправить
        final hasValidOrders = clientsWithTotals
            .any((item) => item.total > 0 && item.meetsMinimum);

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
              // 🔥 ОБНОВЛЕННАЯ КНОПКА ОФОРМИТЬ
              IconButton(
                icon: Icon(
                  Icons.shopping_cart_checkout,
                  // Активна только если есть валидные заказы
                  color: hasValidOrders
                      ? (hasIssues ? Colors.orange : null)
                      : Colors.grey.shade400,
                ),
                tooltip: !hasValidOrders
                    ? 'Все заказы ниже минимальной суммы'
                    : (hasIssues
                        ? 'Оформить (есть проблемы с минималкой)'
                        : 'Оформить все заказы'),
                // Выключена, если нет ни одного валидного заказа
                onPressed: hasValidOrders
                    ? () => _submitAllOrders(context, authProvider)
                    : null,
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

              if (!hasItems) {
                // Если нет товаров - рисуем обычную простую строку
                return ListTile(
                  title: Text(item.client.name ?? ''),
                  subtitle: Text(
                    'Минимальная сумма: ${item.client.minOrderAmount?.toStringAsFixed(0) ?? '0'} ₽',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    authProvider.selectClient(item.client);
                    Navigator.pushReplacementNamed(context, '/price');
                  },
                );
              }

              // 🔥 ЛОГИКА ОПРЕДЕЛЕНИЯ СТАТУСА ОТПРАВКИ
              final clientOrders = authProvider.clientData!.orders
                  .where((o) =>
                      o.clientPhone == item.client.phone &&
                      o.clientName == item.client.name &&
                      o.quantity > 0 &&
                      o.status == 'оформлен')
                  .toList();

              final hasUnsentDrafts =
                  clientOrders.any((o) => o.isLocalDraft == true);
              final isFullySent = clientOrders.isNotEmpty && !hasUnsentDrafts;

              // 🔥 НАСТРОЙКИ ЦВЕТОВ И ИКОНОК (без изменений)
              Color bgColor;
              Color borderColor;
              Color iconColor;
              Color textColor;
              IconData iconData;
              String tooltipMessage;
              double borderWidth = 1.0;

              if (hasUnsentDrafts) {
                if (!item.meetsMinimum) {
                  bgColor = Colors.red.shade50;
                  borderColor = Colors.red.shade400;
                  iconColor = Colors.orange.shade700;
                  textColor = Colors.red.shade800;
                  iconData = Icons.warning_amber_rounded;
                  tooltipMessage =
                      '⚠️ Закажите еще! Сумма меньше минималки. Заказ не отправлен!';
                  borderWidth = 2.0;
                } else {
                  bgColor = Colors.orange.shade50;
                  borderColor = Colors.orange.shade400;
                  iconColor = Colors.orange.shade700;
                  textColor = Colors.orange.shade800;
                  iconData = Icons.warning_amber_rounded;
                  tooltipMessage = '⚠️ Заказ готов к отправке (не отправлен)';
                  borderWidth = 2.0;
                }
              } else if (isFullySent) {
                bgColor = Colors.blue.shade50;
                borderColor = Colors.blue.shade200;
                iconColor = Colors.blue.shade700;
                textColor = Colors.blue.shade800;
                iconData = Icons.thumb_up;
                tooltipMessage = '✅ Заказ принят сервером';
              } else {
                bgColor = Colors.green.shade50;
                borderColor = Colors.green.shade200;
                iconColor = Colors.green.shade700;
                textColor = Colors.green.shade800;
                iconData = Icons.shopping_cart;
                tooltipMessage = 'Корзина';
              }

              // 🚀 НОВАЯ СТРОКА: РИСУЕМ КНОПКУ ПРЯМО ВНУТРИ ListTile
              return ListTile(
                title: Text(item.client.name ?? ''),
                subtitle: Text(
                  '${item.total.toStringAsFixed(2)} ₽',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Резервируем место справа шириной 120 пикселей
                contentPadding: const EdgeInsets.only(left: 16, right: 8),
                trailing: SizedBox(
                  width: 120, // Фиксированная ширина, чтобы сумма не прыгала
                  child: Tooltip(
                    message: tooltipMessage,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        authProvider.selectClient(item.client);
                        Navigator.pushNamed(context, '/cart');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: borderColor, width: borderWidth),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment:
                              MainAxisAlignment.end, // Прижимаем к правому краю
                          children: [
                            Icon(iconData, size: 18, color: iconColor),
                            const SizedBox(width: 4),
                            Flexible(
                              // Если сумма длинная, она сожмется, а не вылезет
                              child: Text(
                                '${item.total.toStringAsFixed(0)} ₽',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                onTap: () {
                  authProvider.selectClient(item.client);
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
