// lib/screens/manager/manager_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_item.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/production_service.dart';
import '../../utils/user_utils.dart';
import '../../services/notification_history_service.dart';
import '../../models/notification_history.dart';

class ManagerOrdersScreen extends StatefulWidget {
  @override
  _ManagerOrdersScreenState createState() => _ManagerOrdersScreenState();
}

class _ManagerOrdersScreenState extends State<ManagerOrdersScreen> {
  final ApiService _apiService = ApiService();

  List<OrderItem> _orders = [];
  bool _isLoading = true;
  bool _hasReadyOrders = false;
  String _selectedFilter =
      'все'; // все, производство, готов, доставлен, корректировка

  final Map<String, Color> _statusColors = {
    'производство': Colors.blue,
    'готов': Colors.green,
    'доставлен': Colors.grey,
    'корректировка': Colors.red,
    'отменен': Colors.black,
  };

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.clientData == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Загружаем заказы из ClientData и фильтруем только нужные статусы
      final allOrders = authProvider.clientData!.orders;

      setState(() {
        _orders = allOrders
            .where((o) =>
                o.status == 'производство' ||
                o.status == 'готов' ||
                o.status == 'доставлен' ||
                o.status == 'корректировка')
            .toList();
        _isLoading = false;
      });

      // Проверяем готовые заказы
      _checkReadyOrders();
    } catch (e) {
      print('❌ Ошибка загрузки заказов: $e');
      setState(() => _isLoading = false);
    }
  }

  void _checkReadyOrders() {
    final readyOrders = _orders.where((o) => o.status == 'готов').toList();
    if (readyOrders.isNotEmpty) {
      setState(() {
        _hasReadyOrders = true;
      });
    }
  }

  Future<void> _markAsReady(OrderItem order) async {
    try {
      final productionService =
          Provider.of<ProductionService>(context, listen: false);

      // 🔥 Нужно преобразовать OrderItem в Order для productionService.completeOrder
      // Временно используем заглушку - вам нужно будет адаптировать этот метод
      print('Отметка заказа как готов: ${order.displayName}');

      // Обновляем статус через API
      final updatedOrder = order.copyWith(status: 'готов');
      final success = await _apiService.updateOrders([updatedOrder]);

      if (success) {
        // Обновляем локально
        setState(() {
          final index = _orders.indexWhere((o) =>
              o.clientPhone == order.clientPhone &&
              o.productName == order.productName &&
              o.date == order.date);
          if (index != -1) {
            _orders[index] = updatedOrder;
          }
        });

        // Уведомляем водителей
        final drivers = UserUtils.getUserPhonesByRole(context, 'Водитель');
        if (drivers.isNotEmpty) {
          await _apiService.sendBulkNotifications(
            targetPhones: drivers,
            title: '🚚 Заказ готов к доставке',
            body: 'Заказ для ${order.clientName} готов',
            data: {
              'type': 'order_ready',
              'clientName': order.clientName,
            },
          );
        }

        // Уведомляем клиента
        if (order.clientPhone.isNotEmpty) {
          await _apiService.sendClientNotification(
            clientPhone: order.clientPhone,
            title: '🎉 Заказ готов',
            body: 'Ваш заказ "${order.displayName}" готов к выдаче',
            orderId: order.priceListId,
          );

          // Сохраняем в историю
          final notification = NotificationHistory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            clientPhone: order.clientPhone,
            orderId: order.priceListId,
            title: '🎉 Заказ готов',
            body: 'Ваш заказ "${order.displayName}" готов к выдаче',
            sentAt: DateTime.now(),
            type: 'order_ready',
          );
          await NotificationHistoryService.saveNotification(notification);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Заказ для ${order.clientName} отмечен как "готов"'),
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

  Future<void> _returnToProduction(OrderItem order) async {
    try {
      final updatedOrder = order.copyWith(status: 'производство');
      final success = await _apiService.updateOrders([updatedOrder]);

      if (success) {
        setState(() {
          final index = _orders.indexWhere((o) =>
              o.clientPhone == order.clientPhone &&
              o.productName == order.productName &&
              o.date == order.date);
          if (index != -1) {
            _orders[index] = updatedOrder;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Заказ для ${order.clientName} возвращён в производство'),
          ),
        );
      }
    } catch (e) {
      print('❌ Ошибка: $e');
    }
  }

  List<OrderItem> get _filteredOrders {
    if (_selectedFilter == 'все') return _orders;
    return _orders.where((o) => o.status == _selectedFilter).toList();
  }

  String _getStatusDisplay(String status) {
    switch (status) {
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
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказы'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications),
                onPressed: () {
                  // TODO: открыть историю уведомлений
                },
              ),
              if (_hasReadyOrders)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadOrders,
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
                  _buildFilterChip('🏭 В производстве', 'производство'),
                  _buildFilterChip('✅ Готов', 'готов'),
                  _buildFilterChip('🚚 Доставлен', 'доставлен'),
                  _buildFilterChip('⚠️ Корректировка', 'корректировка'),
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
          order.displayName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${order.quantity} шт • ${order.clientName}'),
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
                _buildInfoRow('Клиент', order.clientName),
                _buildInfoRow('Телефон', order.clientPhone),
                _buildInfoRow('Дата', order.date),
                SizedBox(height: 16),
                if (order.status == 'производство')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsReady(order),
                      icon: Icon(Icons.check_circle),
                      label: Text('Отметить как готов'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (order.status == 'корректировка')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _returnToProduction(order),
                      icon: Icon(Icons.refresh),
                      label: Text('Вернуть в производство'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
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
            width: 80,
            child: Text('$label:', style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
