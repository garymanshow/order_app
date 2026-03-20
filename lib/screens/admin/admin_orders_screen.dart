// lib/screens/admin/admin_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_item.dart';
import '../../models/client.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/user_utils.dart';

class AdminOrdersScreen extends StatefulWidget {
  @override
  _AdminOrdersScreenState createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final ApiService _apiService = ApiService();

  List<OrderItem> _allOrders = [];
  List<Client> _allClients = [];
  bool _isLoading = true;
  String _selectedFilter =
      'все'; // все, оформлен, производство, готов, доставлен

  final Map<String, Color> _statusColors = {
    'оформлен': Colors.orange,
    'производство': Colors.blue,
    'готов': Colors.green,
    'доставлен': Colors.grey,
    'корректировка': Colors.red,
    'отменен': Colors.black,
    'оплачен': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.clientData == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Загружаем все заказы и клиентов из ClientData
      _allOrders = authProvider.clientData!.orders;
      _allClients = authProvider.clientData!.clients;

      setState(() {
        _isLoading = false;
      });

      // Проверяем новые заказы
      _checkNewOrders();
    } catch (e) {
      print('❌ Ошибка загрузки данных: $e');
      setState(() => _isLoading = false);
    }
  }

  void _checkNewOrders() {
    final newOrders = _allOrders.where((o) => o.status == 'оформлен').toList();
    if (newOrders.isNotEmpty) {
      // Показываем уведомление
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📦 Поступило ${newOrders.length} новых заказов'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      print('📦 Новых заказов: ${newOrders.length}');
    }
  }

  Future<void> _startProduction(OrderItem order) async {
    try {
      // Обновляем статус через API
      final updatedOrder = order.copyWith(status: 'производство');
      final success = await _apiService.updateOrders([updatedOrder]);

      if (success) {
        // Обновляем локально
        setState(() {
          final index = _allOrders.indexWhere((o) =>
              o.clientPhone == order.clientPhone &&
              o.productName == order.productName &&
              o.date == order.date);
          if (index != -1) {
            _allOrders[index] = updatedOrder;
          }
        });

        // Уведомляем менеджеров
        final managers = UserUtils.getUserPhonesByRole(context, 'Менеджер');
        if (managers.isNotEmpty) {
          await _apiService.sendBulkNotifications(
            targetPhones: managers,
            title: '🏭 Запущен в производство',
            body: 'Заказ для ${order.clientName} запущен в работу',
            data: {'type': 'production_started', 'orderId': order.priceListId},
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Заказ для ${order.clientName} запущен в производство'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Ошибка: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelOrder(OrderItem order) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Отмена заказа'),
          content: Text('Отменить заказ для ${order.clientName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Нет'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Да, отменить'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final updatedOrder = order.copyWith(status: 'отменен');
      final success = await _apiService.updateOrders([updatedOrder]);

      if (success) {
        setState(() {
          final index = _allOrders.indexWhere((o) =>
              o.clientPhone == order.clientPhone &&
              o.productName == order.productName &&
              o.date == order.date);
          if (index != -1) {
            _allOrders[index] = updatedOrder;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Заказ отменен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Ошибка: $e');
    }
  }

  String _getClientName(String clientPhone, String clientName) {
    // Пытаемся найти клиента по имени или телефону
    final client = _allClients.firstWhere(
      (c) => c.name == clientName || c.phone == clientPhone,
      orElse: () => Client(name: clientName, phone: clientPhone),
    );
    return client.name ?? clientName;
  }

  List<OrderItem> get _filteredOrders {
    if (_selectedFilter == 'все') return _allOrders;
    return _allOrders.where((o) => o.status == _selectedFilter).toList();
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'оформлен':
        return '🆕 Оформлен';
      case 'производство':
        return '🏭 В производстве';
      case 'готов':
        return '✅ Готов';
      case 'доставлен':
        return '🚚 Доставлен';
      case 'корректировка':
        return '⚠️ Корректировка';
      case 'отменен':
        return '❌ Отменен';
      case 'оплачен':
        return '💰 Оплачен';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все заказы'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Все', 'все'),
                  _buildFilterChip('🆕 Оформлен', 'оформлен'),
                  _buildFilterChip('🏭 В производстве', 'производство'),
                  _buildFilterChip('✅ Готов', 'готов'),
                  _buildFilterChip('🚚 Доставлен', 'доставлен'),
                  _buildFilterChip('⚠️ Корректировка', 'корректировка'),
                  _buildFilterChip('❌ Отменен', 'отменен'),
                  _buildFilterChip('💰 Оплачен', 'оплачен'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'Нет заказов',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = _filteredOrders[index];
                    return _buildOrderCard(order);
                  },
                ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final color = _statusColors[value] ?? Colors.blue;

    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: color.withValues(alpha: 0.2),
        checkmarkColor: color,
      ),
    );
  }

  Widget _buildOrderCard(OrderItem order) {
    final color = _statusColors[order.status] ?? Colors.grey;
    final clientName = _getClientName(order.clientPhone, order.clientName);
    final availableStatuses = order.getAvailableStatuses();

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        title: Text(
          order.displayName, // Используем displayName вместо productName
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${order.quantity} шт • $clientName'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${order.totalPrice} ₽',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Статус', _getStatusDisplay(order.status)),
                _buildInfoRow('Клиент', clientName),
                _buildInfoRow('Телефон', order.clientPhone),
                _buildInfoRow('Дата', order.date), // date уже String

                if (order.paymentAmount > 0)
                  _buildInfoRow('Оплачено', '${order.paymentAmount} ₽'),

                if (order.paymentDocument.isNotEmpty)
                  _buildInfoRow('Документ', order.paymentDocument),

                if (order.notificationSent)
                  _buildInfoRow('Уведомление', 'Отправлено'),

                SizedBox(height: 16),

                // Кнопки действий
                Row(
                  children: [
                    if (order.status == 'оформлен')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startProduction(order),
                          icon: Icon(Icons.play_arrow),
                          label: Text('Запустить'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (availableStatuses.contains('отменен'))
                      Padding(
                        padding: EdgeInsets.only(
                            left: order.status == 'оформлен' ? 8 : 0),
                        child: IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _cancelOrder(order),
                          tooltip: 'Отменить заказ',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('$label:', style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
