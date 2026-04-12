// lib/screens/admin/admin_client_orders_screen.dart
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
    super.key, // 🔥 Исправлено: super.key
    required this.phone,
    required this.clientName,
  });

  @override
  State<AdminClientOrdersScreen> createState() =>
      _AdminClientOrdersScreenState();
}

class _AdminClientOrdersScreenState extends State<AdminClientOrdersScreen>
    with SingleTickerProviderStateMixin {
  List<OrderItem> _orders = [];
  List<OrderItem> _filteredOrders = [];
  List<Client> _allClients = [];
  int _currentClientIndex = 0;

  final Map<String, Map<String, dynamic>> _productStats =
      {}; // 🔥 Исправлено: final

  // Общая воронка по компании
  final Map<String, int> _overallStatusCounts = {}; // 🔥 Исправлено: final
  List<MapEntry<String, int>> _overallTopProducts = [];

  bool _isLoading = false;
  String _statusFilter = 'all';
  String _periodFilter = 'all';

  late TabController _tabController;

  final ApiService _apiService = ApiService();

  final Map<String, Color> _statusColors = {
    'оформлен': Colors.grey,
    'производство': Colors.orange,
    'готов': Colors.blue,
    'доставлен': Colors.green,
    'оплачен': Colors.yellow[700]!,
    'отменен': Colors.red,
  };

  final Map<String, IconData> _statusIcons = {
    'оформлен': Icons.description_outlined,
    'производство': Icons.factory_outlined,
    'готов': Icons.check_circle_outline,
    'доставлен': Icons.local_shipping_outlined,
    'оплачен': Icons.attach_money_outlined,
    'отменен': Icons.cancel_outlined,
  };

  final List<String> _funnelStatuses = const [
    'оформлен',
    'производство',
    'готов',
    'доставлен',
    'оплачен',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadAllClients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAllClients() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _allClients = authProvider.clientData?.clients ?? [];
    _currentClientIndex =
        _allClients.indexWhere((c) => c.name == widget.clientName);
    if (_currentClientIndex == -1) _currentClientIndex = 0;
    _loadOrders();
  }

  void _loadOrders() {
    if (_allClients.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];

    _calculateOverallStats(allOrders);

    final currentClient = _allClients[_currentClientIndex];
    final filteredOrders = allOrders.where((order) {
      return order.clientName == currentClient.name;
    }).toList();

    filteredOrders.sort((a, b) {
      final dateA = ParsingUtils.parseDate(a.date);
      final dateB = ParsingUtils.parseDate(b.date);

      if (dateA == null && dateB == null) {
        // Обе даты null
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
      _calculateProductStats();
      _applyFilters();
    });

    debugPrint(
        '📊 Загружено заказов для ${currentClient.name}: ${filteredOrders.length}'); // 🔥 Исправлено: debugPrint
  }

  void _calculateOverallStats(List<OrderItem> allOrders) {
    _overallStatusCounts.clear();
    Map<String, int> productCounts = {};

    for (var order in allOrders) {
      if (_funnelStatuses.contains(order.status)) {
        _overallStatusCounts[order.status] =
            (_overallStatusCounts[order.status] ?? 0) + 1;
      }
      if (order.displayName.isNotEmpty) {
        productCounts[order.displayName] =
            (productCounts[order.displayName] ?? 0) + order.quantity;
      }
    }

    _overallTopProducts = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _overallTopProducts = _overallTopProducts.take(10).toList();
  }

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
      _productStats[order.priceListId]!['avgPrice'] =
          _productStats[order.priceListId]!['totalAmount'] /
              _productStats[order.priceListId]!['totalQuantity'];

      if (order.date
              .compareTo(_productStats[order.priceListId]!['lastOrderDate']) >
          0) {
        _productStats[order.priceListId]!['lastOrderDate'] = order.date;
      }
    }
  }

  List<MapEntry<String, Map<String, dynamic>>> get topProductsByQuantity {
    var sorted = _productStats.entries.toList()
      ..sort((a, b) =>
          b.value['totalQuantity'].compareTo(a.value['totalQuantity']));
    return sorted.take(5).toList();
  }

  List<MapEntry<String, Map<String, dynamic>>> get topProductsByAmount {
    var sorted = _productStats.entries.toList()
      ..sort(
          (a, b) => b.value['totalAmount'].compareTo(a.value['totalAmount']));
    return sorted.take(5).toList();
  }

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
        return dateA.compareTo(dateB);
      });
  }

  List<MapEntry<String, Map<String, dynamic>>> get mostFrequentProducts {
    var sorted = _productStats.entries.toList()
      ..sort((a, b) => b.value['orderCount'].compareTo(a.value['orderCount']));
    return sorted.take(5).toList();
  }

  void _navigateToClient(int direction) {
    setState(() {
      _currentClientIndex =
          (_currentClientIndex + direction) % _allClients.length;
      if (_currentClientIndex < 0) {
        _currentClientIndex = _allClients.length - 1;
      }
      _loadOrders();
    });
  }

  void _applyFilters() {
    List<OrderItem> filtered = _statusFilter == 'all'
        ? List.from(_orders)
        : _orders.where((o) => o.status == _statusFilter).toList();

    filtered = _applyPeriodFilter(filtered);

    setState(() {
      _filteredOrders = filtered;
    });
  }

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

  void _setPeriodFilter(String period) {
    setState(() {
      _periodFilter = period;
      _applyFilters();
    });
  }

  void _setStatusFilter(String? status) {
    setState(() {
      _statusFilter = status ?? 'all';
      _applyFilters();
    });
  }

  double get totalAmount =>
      _filteredOrders.fold(0.0, (sum, o) => sum + o.totalPrice);
  double get totalPaid =>
      _filteredOrders.fold(0.0, (sum, o) => sum + o.paymentAmount);
  double get totalDebt => totalAmount - totalPaid;

  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      debugPrint('❌ Ошибка сохранения ClientData: $e');
    }
  }

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
      _showSnackBar('Ошибка: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
                tileColor: _getStatusColor(order.status)
                    .withValues(alpha: 0.1), // 🔥 Исправлено: withValues
              ),
              const Divider(),
              ...availableStatuses.map((status) {
                // 🔥 Исправлено: убрано лишнее .toList()
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
              }),
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

  // ================= ЕДИНЫЙ МЕТОД BUILD =================

  @override
  Widget build(BuildContext context) {
    if (_allClients.isEmpty) {
      return Scaffold(
          appBar: AppBar(title: const Text('Ошибка')),
          body: const Center(child: Text('Клиенты не найдены')));
    }

    final currentClient = _allClients[_currentClientIndex];
    final bool isOverallTab = _tabController.index == 3;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onHorizontalDragEnd: isOverallTab
              ? null
              : (details) {
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
                      isOverallTab
                          ? '📊 Аналитика компании'
                          : currentClient.name ?? 'Без имени',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_allClients.length > 1 && !isOverallTab)
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
              if (!isOverallTab && currentClient.phone != null)
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
              if (!isOverallTab)
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
              if (!isOverallTab)
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
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '📋 Заказы', icon: Icon(Icons.receipt, size: 20)),
                  Tab(
                      text: '🏆 Товары',
                      icon: Icon(Icons.show_chart, size: 20)),
                  Tab(text: '⏰ Спящие', icon: Icon(Icons.alarm, size: 20)),
                  Tab(text: '🏢 Общее', icon: Icon(Icons.business, size: 20)),
                ],
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
              ),
            ],
          ),
        ),
        actions: [
          if (!isOverallTab)
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
          if (!isOverallTab)
            IconButton(
              icon: const Icon(Icons.group_work),
              onPressed: _filteredOrders.isNotEmpty
                  ? _showBulkStatusChangeDialog
                  : null,
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
                _buildOverallAnalytics(),
              ],
            ),
    );
  }

  // ================= ВКЛАДКА ОБЩЕЙ АНАЛИТИКИ =================

  Widget _buildOverallAnalytics() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Воронка заказов (все клиенты)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                ..._funnelStatuses.map((status) {
                  final count = _overallStatusCounts[status] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(status,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: count > 0 ? 1.0 : 0.0,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      _getStatusColor(status).withValues(
                                          alpha:
                                              0.7)), // 🔥 Исправлено: withValues
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          count.toString(),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: count > 0
                                  ? _getStatusColor(status)
                                  : Colors.grey),
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
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🏆 Топ-10 товаров (компания)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (_overallTopProducts.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Нет данных')))
                else
                  ..._overallTopProducts.asMap().entries.map((entry) {
                    // 🔥 Исправлено: убрано лишнее .toList()
                    final index = entry.key;
                    final product = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  color: index < 3
                                      ? Colors.amber
                                      : Colors.grey[300],
                                  shape: BoxShape.circle),
                              child: Center(
                                  child: Text('${index + 1}',
                                      style: TextStyle(
                                          color: index < 3
                                              ? Colors.white
                                              : Colors.black54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(product.key,
                                  style: const TextStyle(fontSize: 14))),
                          Text('${product.value} шт',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _buildProductStats() {
    if (_productStats.isEmpty) {
      return const Center(child: Text('Нет данных для анализа'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.shopping_cart, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('🏆 Топ-5 по количеству',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))
                  ]),
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
                                  shape: BoxShape.circle),
                              child: Center(
                                  child: Text('$index',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: index <= 3
                                              ? Colors.black
                                              : Colors.grey)))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(product['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                Text(
                                    '${product['totalQuantity']} шт • ${product['orderCount']} заказов',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[600]))
                              ])),
                          Text('${product['totalAmount'].toStringAsFixed(0)} ₽',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.attach_money, color: Colors.green),
                    SizedBox(width: 8),
                    Text('💰 Топ-5 по выручке',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))
                  ]),
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
                                  shape: BoxShape.circle),
                              child: Center(
                                  child: Text('$index',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: index <= 3
                                              ? Colors.black
                                              : Colors.grey)))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(product['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                Text('${product['totalQuantity']} шт',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[600]))
                              ])),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    '${product['totalAmount'].toStringAsFixed(0)} ₽',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                                Text(
                                    '${product['avgPrice'].toStringAsFixed(0)} ₽/шт',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey[500]))
                              ]),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.repeat, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('🔄 Чаще всего заказывают',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))
                  ]),
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
                          Expanded(child: Text(product['name'])),
                          Text('${product['orderCount']} раз',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.purple)),
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
            Text('Все товары заказывали менее 30 дней назад',
                style: TextStyle(color: Colors.grey)),
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
            trailing: Text('было ${product['totalQuantity']} шт',
                style: const TextStyle(color: Colors.grey)),
          ),
        );
      },
    );
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
            border: Border(left: BorderSide(color: statusColor, width: 4)),
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
                          borderRadius: BorderRadius.circular(
                              8)), // 🔥 Исправлено: withValues
                      child: Icon(_getStatusIcon(order.status),
                          color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(
                                        12)), // 🔥 Исправлено: withValues
                                child: Text(order.status,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: statusColor,
                                        fontWeight: FontWeight.w500)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                  '${order.quantity} шт × ${order.totalPrice} ₽',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (order.paymentAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.payment, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                          'Оплачено: ${order.paymentAmount.toStringAsFixed(2)} ₽',
                          style: TextStyle(fontSize: 11, color: Colors.green)),
                      if (order.paymentAmount < order.totalPrice)
                        Text(
                            ' (долг: ${(order.totalPrice - order.paymentAmount).toStringAsFixed(2)} ₽)',
                            style: TextStyle(fontSize: 11, color: Colors.red)),
                    ],
                  ),
                ],
                if (order.paymentDocument.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.receipt, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text('Документ: ${order.paymentDocument}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis)),
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
          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Нет заказов',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('У клиента пока нет заказов',
              style: TextStyle(color: Colors.grey[500])),
        ],
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
}
