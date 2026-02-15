// lib/screens/admin_client_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/google_sheets_service.dart';
import '../models/admin_order.dart';
import '../utils/parsing_utils.dart';

class AdminClientOrdersScreen extends StatefulWidget {
  final String phone;
  final String clientName;

  const AdminClientOrdersScreen({
    Key? key,
    required this.phone,
    required this.clientName,
  }) : super(key: key);

  @override
  _AdminClientOrdersScreenState createState() =>
      _AdminClientOrdersScreenState();
}

class _AdminClientOrdersScreenState extends State<AdminClientOrdersScreen> {
  late Future<List<AdminOrder>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    _ordersFuture = service.init().then((_) async {
      final allOrders = await service.read(sheetName: 'Заказы');

      final List<AdminOrder> orders = [];
      int idCounter = 1;

      for (var row in allOrders) {
        if (row['Телефон']?.toString() == widget.phone &&
            row['Клиент']?.toString() == widget.clientName) {
          orders.add(AdminOrder(
            id: idCounter.toString(),
            status: row['Статус']?.toString() ?? 'оформлен',
            productName: row['Название']?.toString() ?? '',
            quantity: int.tryParse(row['Количество']?.toString() ?? '0') ?? 0,
            totalPrice:
                double.tryParse(row['Итоговая цена']?.toString() ?? '0') ?? 0,
            date: row['Дата']?.toString() ?? '',
            phone: widget.phone,
            clientName: widget.clientName,
          ));
          idCounter++;
        }
      }

      // Сортировка: новые даты сверху, затем по статусу
      orders.sort((a, b) {
        final dateA = ParsingUtils.parseDate(a.date);
        final dateB = ParsingUtils.parseDate(b.date);

        // Обработка null-дат: null считается "старее", т.е. идет вниз списка
        if (dateA == null && dateB == null) {
          // Обе даты null — сортируем по статусу
        } else if (dateA == null) {
          return 1; // a идет после b
        } else if (dateB == null) {
          return -1; // b идет после a
        } else {
          // Обе даты не null — сортируем по дате (новые сверху)
          final dateComparison = dateB.compareTo(dateA);
          if (dateComparison != 0) {
            return dateComparison;
          }
        }

        // Сортировка по статусу
        final statusOrder = {
          'оформлен': 0,
          'производство': 1,
          'готов': 2,
          'доставлен': 3
        };
        final orderA = statusOrder[a.status] ?? 999;
        final orderB = statusOrder[b.status] ?? 999;
        return orderA.compareTo(orderB);
      });

      return orders;
    });
  }

  // 🔥 Обновление существующей строки (не создание новой!)
  Future<void> _updateOrderStatus(AdminOrder order, String newStatus) async {
    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    // Фильтры для поиска конкретной позиции заказа
    final filters = [
      {'column': 'Телефон', 'value': order.phone},
      {'column': 'Клиент', 'value': order.clientName},
      {'column': 'Название', 'value': order.productName},
      {'column': 'Дата', 'value': order.date},
      // Не включаем 'Статус' в фильтры, чтобы найти строку независимо от текущего статуса
    ];

    final updates = {'Статус': newStatus};

    await service.update(
      sheetName: 'Заказы',
      filters: filters,
      data: updates,
    );

    setState(() {
      _loadOrders();
    });
  }

  // 🔥 Изменение статуса ВСЕГО заказа (всех позиций)
  Future<void> _updateAllOrdersStatus(String newStatus) async {
    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    // Фильтры для поиска всех позиций клиента
    final filters = [
      {'column': 'Телефон', 'value': widget.phone},
      {'column': 'Клиент', 'value': widget.clientName},
    ];

    final updates = {'Статус': newStatus};

    await service.update(
      sheetName: 'Заказы',
      filters: filters,
      data: updates,
    );

    setState(() {
      _loadOrders();
    });
  }

  void _showStatusChangeDialog(AdminOrder order) {
    final availableStatuses = order.getAvailableStatuses();
    if (availableStatuses.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Текущий статус: ${order.status}'),
                tileColor: order.getStatusColor().withOpacity(0.2),
              ),
              ...availableStatuses.map((status) {
                return ListTile(
                  title: Text('Изменить на: $status'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateOrderStatus(order, status);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showBulkStatusChangeDialog() {
    // Определяем доступный статус для всего заказа
    // Берём минимальный статус из всех позиций
    final currentStatuses = <String>{};
    // Здесь можно добавить логику определения общего статуса

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Изменить статус всего заказа'),
                subtitle: Text('Все позиции получат новый статус'),
              ),
              ListTile(
                title: Text('На производство'),
                onTap: () {
                  Navigator.pop(context);
                  _updateAllOrdersStatus('производство');
                },
              ),
              ListTile(
                title: Text('Готов'),
                onTap: () {
                  Navigator.pop(context);
                  _updateAllOrdersStatus('готов');
                },
              ),
              ListTile(
                title: Text('Доставлен'),
                onTap: () {
                  Navigator.pop(context);
                  _updateAllOrdersStatus('доставлен');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказы: ${widget.clientName}'),
        actions: [
          // Кнопка массового изменения статуса
          IconButton(
            icon: Icon(Icons.group_work),
            onPressed: _showBulkStatusChangeDialog,
            tooltip: 'Изменить статус всего заказа',
          ),
        ],
      ),
      body: FutureBuilder<List<AdminOrder>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Нет заказов'));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  leading: Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: order.getStatusColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(order.productName),
                  subtitle: Text(
                    '${order.quantity} шт × ${order.totalPrice} ₽\n'
                    'Дата: ${order.date}\n'
                    'Статус: ${order.status}',
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  tileColor: order.getStatusColor().withOpacity(0.1),
                  onTap: () => _showStatusChangeDialog(order),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
