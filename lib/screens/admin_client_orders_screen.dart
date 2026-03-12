// lib/screens/admin_client_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../models/order_item.dart';
import '../services/api_service.dart';
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
  List<OrderItem> _orders = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  // Цвета статусов
  final Map<String, Color> _statusColors = {
    'оформлен': Colors.grey,
    'производство': Colors.orange,
    'готов': Colors.blue,
    'доставлен': Colors.green,
    'отменен': Colors.red,
  };

  // Иконки статусов
  final Map<String, IconData> _statusIcons = {
    'оформлен': Icons.description_outlined,
    'производство': Icons.factory_outlined,
    'готов': Icons.check_circle_outline,
    'доставлен': Icons.local_shipping_outlined,
    'отменен': Icons.cancel_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // ЗАГРУЗКА ЗАКАЗОВ ИЗ ЛОКАЛЬНЫХ ДАННЫХ
  void _loadOrders() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];

    final filteredOrders = allOrders.where((order) {
      return order.clientPhone == widget.phone;
    }).toList();

    filteredOrders.sort((a, b) {
      final dateA = ParsingUtils.parseDate(a.date);
      final dateB = ParsingUtils.parseDate(b.date);

      if (dateA == null && dateB == null) {
        // Обе даты null — сортируем по статусу
      } else if (dateA == null) {
        return 1;
      } else if (dateB == null) {
        return -1;
      } else {
        final dateComparison = dateB.compareTo(dateA);
        if (dateComparison != 0) {
          return dateComparison;
        }
      }

      const statusOrder = {
        'оформлен': 0,
        'производство': 1,
        'готов': 2,
        'доставлен': 3,
        'отменен': 4,
      };
      final orderA = statusOrder[a.status] ?? 999;
      final orderB = statusOrder[b.status] ?? 999;
      return orderA.compareTo(orderB);
    });

    setState(() {
      _orders = filteredOrders;
    });

    print(
        '📊 Загружено заказов для ${widget.clientName}: ${filteredOrders.length}');
  }

  // СОХРАНЕНИЕ В SHAREDPREFERENCES
  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }

  // ОБНОВЛЕНИЕ СТАТУСА КОНКРЕТНОЙ ПОЗИЦИИ
  Future<void> _updateOrderStatus(OrderItem order, String newStatus) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final index = authProvider.clientData!.orders.indexWhere((o) =>
          o.clientPhone == order.clientPhone &&
          o.productName == order.productName &&
          o.date == order.date);

      if (index != -1) {
        final updatedOrder = order.copyWith(status: newStatus);

        final success = await _apiService.updateOrderStatus(
          orderId: '${order.clientPhone}_${order.productName}_${order.date}',
          newStatus: newStatus,
        );

        if (success) {
          authProvider.clientData!.orders[index] = updatedOrder;
          authProvider.clientData!.buildIndexes();
          await _saveToPrefs(authProvider);
          _loadOrders();

          _showSnackBar('Статус изменен на "$newStatus"', Colors.green);
        } else {
          throw Exception('Ошибка обновления статуса на сервере');
        }
      }
    } catch (e) {
      print('❌ Ошибка обновления статуса: $e');
      _showSnackBar('Ошибка: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ОБНОВЛЕНИЕ СТАТУСА ВСЕХ ПОЗИЦИЙ
  Future<void> _updateAllOrdersStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final clientOrders = authProvider.clientData!.orders
          .where((o) => o.clientPhone == widget.phone)
          .toList();

      final updatedOrders = clientOrders.map((order) {
        return order.copyWith(status: newStatus);
      }).toList();

      final success = await _apiService.updateOrdersBatch(updatedOrders);

      if (success) {
        for (int i = 0; i < clientOrders.length; i++) {
          final oldOrder = clientOrders[i];
          final index = authProvider.clientData!.orders.indexWhere((o) =>
              o.clientPhone == oldOrder.clientPhone &&
              o.productName == oldOrder.productName &&
              o.date == oldOrder.date);

          if (index != -1) {
            authProvider.clientData!.orders[index] = updatedOrders[i];
          }
        }

        authProvider.clientData!.buildIndexes();
        await _saveToPrefs(authProvider);
        _loadOrders();

        _showSnackBar(
            'Статус всех заказов изменен на "$newStatus"', Colors.green);
      } else {
        throw Exception('Ошибка массового обновления на сервере');
      }
    } catch (e) {
      print('❌ Ошибка массового обновления: $e');
      _showSnackBar('Ошибка: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStatusColor(String status) {
    return _statusColors[status] ?? Colors.grey;
  }

  IconData _getStatusIcon(String status) {
    return _statusIcons[status] ?? Icons.help_outline;
  }

  void _showStatusChangeDialog(OrderItem order) {
    final availableStatuses = order.getAvailableStatuses();
    if (availableStatuses.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                title: Text(
                  order.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Текущий статус: ${order.status}'),
                tileColor: _getStatusColor(order.status).withOpacity(0.1),
              ),
              const Divider(),
              ...availableStatuses.map((status) {
                return ListTile(
                  leading: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                  ),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                title: const Text('Изменить статус всего заказа'),
                subtitle:
                    Text('Все ${_orders.length} позиций получат новый статус'),
                leading: const Icon(Icons.group_work),
              ),
              const Divider(),
              _buildStatusTile('производство', Icons.factory, Colors.orange),
              _buildStatusTile('готов', Icons.check_circle, Colors.blue),
              _buildStatusTile('доставлен', Icons.local_shipping, Colors.green),
              _buildStatusTile('отменен', Icons.cancel, Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusTile(String status, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text('В $status'),
      onTap: () {
        Navigator.pop(context);
        _updateAllOrdersStatus(status);
      },
    );
  }

  Map<String, List<OrderItem>> _groupOrdersByDate() {
    final grouped = <String, List<OrderItem>>{};
    for (var order in _orders) {
      final date = order.date.isNotEmpty ? order.date : 'Без даты';
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(order);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedOrders = _groupOrdersByDate();
    final dates = groupedOrders.keys.toList()
      ..sort((a, b) {
        final dateA = ParsingUtils.parseDate(a);
        final dateB = ParsingUtils.parseDate(b);
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Заказы'),
            Text(
              widget.clientName,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_work),
            onPressed: _orders.isNotEmpty ? _showBulkStatusChangeDialog : null,
            tooltip: 'Изменить статус всего заказа',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: dates.length,
                  itemBuilder: (context, dateIndex) {
                    final date = dates[dateIndex];
                    final dateOrders = groupedOrders[date]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '📅 $date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${dateOrders.length} ${_getPluralForm(dateOrders.length)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...dateOrders.map((order) => _buildOrderCard(order)),
                      ],
                    );
                  },
                ),
    );
  }

  String _getPluralForm(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'позиция';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'позиции';
    }
    return 'позиций';
  }

  Widget _buildOrderCard(OrderItem order) {
    final statusColor = _getStatusColor(order.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showStatusChangeDialog(order),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: statusColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order.status,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${order.quantity} шт × ${order.totalPrice} ₽',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${order.totalPrice} ₽',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет заказов',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'У клиента пока нет заказов',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
