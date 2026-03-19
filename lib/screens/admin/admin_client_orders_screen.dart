// lib/screens/admin_client_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_item.dart';
import '../../models/client.dart';
import '../../services/api_service.dart';
import '../../utils/parsing_utils.dart';

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

class _AdminClientOrdersScreenState extends State<AdminClientOrdersScreen>
    with SingleTickerProviderStateMixin {
  List<OrderItem> _orders = [];
  List<OrderItem> _filteredOrders = [];
  List<Client> _allClients = [];
  int _currentClientIndex = 0;

  // 👇 АНАЛИТИКА ПО ТОВАРАМ
  Map<String, Map<String, dynamic>> _productStats = {};

  bool _isLoading = false;
  String _statusFilter = 'all';
  String _periodFilter = 'all'; // 'day', 'week', 'month', 'all'

  late TabController _tabController;

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
    _tabController = TabController(length: 3, vsync: this);
    _loadAllClients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 👇 ЗАГРУЗКА ВСЕХ КЛИЕНТОВ
  void _loadAllClients() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _allClients = authProvider.clientData?.clients ?? [];

    _currentClientIndex =
        _allClients.indexWhere((c) => c.name == widget.clientName);
    if (_currentClientIndex == -1) _currentClientIndex = 0;

    _loadOrders();
  }

  // 👇 ЗАГРУЗКА ЗАКАЗОВ ТЕКУЩЕГО КЛИЕНТА
  void _loadOrders() {
    if (_allClients.isEmpty) return;

    final currentClient = _allClients[_currentClientIndex];

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];

    final filteredOrders = allOrders.where((order) {
      return order.clientName == currentClient.name;
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
      _calculateProductStats(); // 👈 РАСЧЕТ АНАЛИТИКИ
      _applyFilters();
    });

    print(
        '📊 Загружено заказов для ${currentClient.name}: ${filteredOrders.length}');
  }

  // 👇 РАСЧЕТ АНАЛИТИКИ ПО ТОВАРАМ
  void _calculateProductStats() {
    _productStats.clear();

    for (var order in _orders) {
      if (!_productStats.containsKey(order.priceListId)) {
        _productStats[order.priceListId] = {
          'name': order.displayName,
          'totalQuantity': 0,
          'totalAmount': 0.0,
          'orderCount': 0,
          'lastOrderDate': '',
          'avgPrice': 0.0,
        };
      }

      _productStats[order.priceListId]!['totalQuantity'] += order.quantity;
      _productStats[order.priceListId]!['totalAmount'] += order.totalPrice;
      _productStats[order.priceListId]!['orderCount'] += 1;

      // Средняя цена за единицу
      final avgPrice = _productStats[order.priceListId]!['totalAmount'] /
          _productStats[order.priceListId]!['totalQuantity'];
      _productStats[order.priceListId]!['avgPrice'] = avgPrice;

      // Обновляем дату последнего заказа
      if (order.date
              .compareTo(_productStats[order.priceListId]!['lastOrderDate']) >
          0) {
        _productStats[order.priceListId]!['lastOrderDate'] = order.date;
      }
    }
  }

  // 👇 ТОП-5 ТОВАРОВ ПО КОЛИЧЕСТВУ
  List<MapEntry<String, Map<String, dynamic>>> get topProductsByQuantity {
    var sorted = _productStats.entries.toList()
      ..sort((a, b) =>
          b.value['totalQuantity'].compareTo(a.value['totalQuantity']));
    return sorted.take(5).toList();
  }

  // 👇 ТОП-5 ТОВАРОВ ПО СУММЕ
  List<MapEntry<String, Map<String, dynamic>>> get topProductsByAmount {
    var sorted = _productStats.entries.toList()
      ..sort(
          (a, b) => b.value['totalAmount'].compareTo(a.value['totalAmount']));
    return sorted.take(5).toList();
  }

  // 👇 "СПЯЩИЕ" ТОВАРЫ (не заказывали более 30 дней)
  List<MapEntry<String, Map<String, dynamic>>> get sleepingProducts {
    final now = DateTime.now();
    return _productStats.entries.where((entry) {
      final lastDate = ParsingUtils.parseDate(entry.value['lastOrderDate']);
      if (lastDate == null) return false;
      return now.difference(lastDate).inDays > 30;
    }).toList()
      ..sort((a, b) {
        final dateA = ParsingUtils.parseDate(a.value['lastOrderDate']);
        final dateB = ParsingUtils.parseDate(b.value['lastOrderDate']);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB); // Сначала самые старые
      });
  }

  // 👇 ТОВАРЫ-ЛИДЕРЫ (больше всего заказов)
  List<MapEntry<String, Map<String, dynamic>>> get mostFrequentProducts {
    var sorted = _productStats.entries.toList()
      ..sort((a, b) => b.value['orderCount'].compareTo(a.value['orderCount']));
    return sorted.take(5).toList();
  }

  // 👇 ПЕРЕКЛЮЧЕНИЕ НА ДРУГОГО КЛИЕНТА
  void _navigateToClient(int direction) {
    setState(() {
      _currentClientIndex =
          (_currentClientIndex + direction) % _allClients.length;
      if (_currentClientIndex < 0) _currentClientIndex = _allClients.length - 1;
      _loadOrders();
    });
  }

  // 👇 ПРИМЕНЕНИЕ ФИЛЬТРОВ
  void _applyFilters() {
    List<OrderItem> filtered = _statusFilter == 'all'
        ? List.from(_orders)
        : _orders.where((o) => o.status == _statusFilter).toList();

    filtered = _applyPeriodFilter(filtered);

    setState(() {
      _filteredOrders = filtered;
    });
  }

  // 👇 ФИЛЬТР ПО ПЕРИОДУ
  List<OrderItem> _applyPeriodFilter(List<OrderItem> orders) {
    if (_periodFilter == 'all') return orders;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return orders.where((order) {
      final orderDate = ParsingUtils.parseDate(order.date);
      if (orderDate == null) return false;

      final orderDay = DateTime(orderDate.year, orderDate.month, orderDate.day);

      switch (_periodFilter) {
        case 'day':
          return orderDay.isAtSameMomentAs(today);
        case 'week':
          final weekAgo = today.subtract(const Duration(days: 7));
          return orderDay.isAfter(weekAgo) ||
              orderDay.isAtSameMomentAs(weekAgo);
        case 'month':
          final monthAgo = today.subtract(const Duration(days: 30));
          return orderDay.isAfter(monthAgo) ||
              orderDay.isAtSameMomentAs(monthAgo);
        default:
          return true;
      }
    }).toList();
  }

  // 👇 ПЕРЕКЛЮЧЕНИЕ ФИЛЬТРА ПЕРИОДА
  void _setPeriodFilter(String period) {
    setState(() {
      _periodFilter = period;
      _applyFilters();
    });
  }

  // 👇 ПЕРЕКЛЮЧЕНИЕ ФИЛЬТРА СТАТУСА
  void _setStatusFilter(String? status) {
    setState(() {
      _statusFilter = status ?? 'all';
      _applyFilters();
    });
  }

  // 👇 ПОДСЧЕТ СТАТИСТИКИ
  double get totalAmount =>
      _filteredOrders.fold(0.0, (sum, o) => sum + o.totalPrice);
  double get totalPaid =>
      _filteredOrders.fold(0.0, (sum, o) => sum + o.paymentAmount);
  double get totalDebt => totalAmount - totalPaid;

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
          .where((o) => o.clientName == _allClients[_currentClientIndex].name)
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
                tileColor: _getStatusColor(order.status).withValues(alpha: 0.1),
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
                subtitle: Text(
                    'Все ${_filteredOrders.length} позиций получат новый статус'),
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

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _periodFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setPeriodFilter(value),
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue,
    );
  }

  Map<String, List<OrderItem>> _groupOrdersByDate() {
    final grouped = <String, List<OrderItem>>{};
    for (var order in _filteredOrders) {
      final date = order.date.isNotEmpty ? order.date : 'Без даты';
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(order);
    }
    return grouped;
  }

  // 👇 ПОСТРОЕНИЕ СПИСКА ЗАКАЗОВ
  Widget _buildOrdersList() {
    final groupedOrders = _groupOrdersByDate();
    final dates = groupedOrders.keys.toList()
      ..sort((a, b) {
        final dateA = ParsingUtils.parseDate(a);
        final dateB = ParsingUtils.parseDate(b);
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

    return _filteredOrders.isEmpty
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
          );
  }

  // 👇 СТАТИСТИКА ПО ТОВАРАМ
  Widget _buildProductStats() {
    if (_productStats.isEmpty) {
      return const Center(
        child: Text('Нет данных для анализа'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Топ по количеству
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shopping_cart, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        '🏆 Топ-5 по количеству',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...topProductsByQuantity.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final product = entry.value.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: index == 1
                                  ? Colors.amber
                                  : index == 2
                                      ? Colors.grey[300]
                                      : index == 3
                                          ? Colors.brown[100]
                                          : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$index',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      index <= 3 ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${product['totalQuantity']} шт • ${product['orderCount']} заказов',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${product['totalAmount'].toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Топ по сумме
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        '💰 Топ-5 по выручке',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...topProductsByAmount.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final product = entry.value.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: index == 1
                                  ? Colors.amber
                                  : index == 2
                                      ? Colors.grey[300]
                                      : index == 3
                                          ? Colors.brown[100]
                                          : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$index',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      index <= 3 ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${product['totalQuantity']} шт',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${product['totalAmount'].toStringAsFixed(0)} ₽',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                '${(product['avgPrice']).toStringAsFixed(0)} ₽/шт',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Частота заказов
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.repeat, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        '🔄 Чаще всего заказывают',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...mostFrequentProducts.map((entry) {
                    final product = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record,
                              size: 8, color: Colors.purple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(product['name']),
                          ),
                          Text(
                            '${product['orderCount']} раз',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 👇 "СПЯЩИЕ" ТОВАРЫ
  Widget _buildSleepingProducts() {
    final sleeping = sleepingProducts;

    if (sleeping.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alarm_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет "спящих" товаров'),
            Text(
              'Все товары заказывали менее 30 дней назад',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sleeping.length,
      itemBuilder: (context, index) {
        final product = sleeping[index].value;
        final lastDate = ParsingUtils.parseDate(product['lastOrderDate']);
        final daysAgo =
            lastDate != null ? DateTime.now().difference(lastDate).inDays : 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.alarm, color: Colors.orange),
            title: Text(product['name']),
            subtitle: Text('Не заказывали $daysAgo дней'),
            trailing: Text(
              'было ${product['totalQuantity']} шт',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        );
      },
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
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
                                  color: statusColor.withValues(alpha: 0.2),
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
                  ],
                ),

                // Информация об оплате
                if (order.paymentAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.payment, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Оплачено: ${order.paymentAmount.toStringAsFixed(2)} ₽',
                        style: TextStyle(fontSize: 11, color: Colors.green),
                      ),
                      if (order.paymentAmount < order.totalPrice)
                        Text(
                          ' (долг: ${(order.totalPrice - order.paymentAmount).toStringAsFixed(2)} ₽)',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        ),
                    ],
                  ),
                ],

                // Номер платежного документа
                if (order.paymentDocument.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.receipt, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Документ: ${order.paymentDocument}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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

  @override
  Widget build(BuildContext context) {
    if (_allClients.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('Клиенты не найдены')),
      );
    }

    final currentClient = _allClients[_currentClientIndex];

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              _navigateToClient(-1);
            } else if (details.primaryVelocity! < 0) {
              _navigateToClient(1);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currentClient.name ?? 'Без имени',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_allClients.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentClientIndex + 1}/${_allClients.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              if (currentClient.phone != null)
                Text(
                  currentClient.phone!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(160),
          child: Column(
            children: [
              // Периоды
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _buildPeriodChip('📅 День', 'day'),
                    const SizedBox(width: 4),
                    _buildPeriodChip('📆 Неделя', 'week'),
                    const SizedBox(width: 4),
                    _buildPeriodChip('🗓️ Месяц', 'month'),
                    const SizedBox(width: 4),
                    _buildPeriodChip('📂 Всё', 'all'),
                  ],
                ),
              ),
              // Статистика
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💰 ${totalAmount.toStringAsFixed(2)} ₽',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '📦 ${_filteredOrders.length} ${_getPluralForm(_filteredOrders.length)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '💸 ${totalDebt.toStringAsFixed(2)} ₽',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: totalDebt > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                        Text(
                          '💳 ${totalPaid.toStringAsFixed(2)} ₽ опл.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Табы
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '📋 Заказы', icon: Icon(Icons.receipt)),
                  Tab(text: '🏆 Товары', icon: Icon(Icons.show_chart)),
                  Tab(text: '⏰ Спящие', icon: Icon(Icons.alarm)),
                ],
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: _setStatusFilter,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 18),
                    SizedBox(width: 8),
                    Text('Все статусы'),
                  ],
                ),
              ),
              ..._statusColors.keys.map((status) => PopupMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Icon(_statusIcons[status],
                            color: _statusColors[status]),
                        const SizedBox(width: 8),
                        Text(status),
                      ],
                    ),
                  )),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.group_work),
            onPressed:
                _filteredOrders.isNotEmpty ? _showBulkStatusChangeDialog : null,
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
          : IndexedStack(
              index: _tabController.index,
              children: [
                _buildOrdersList(),
                _buildProductStats(),
                _buildSleepingProducts(),
              ],
            ),
    );
  }
}
