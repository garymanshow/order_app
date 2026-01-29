// lib/screens/admin_clients_with_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';
import '../models/order_item.dart';
import '../widgets/order_card.dart';

class AdminClientsWithOrdersScreen extends StatefulWidget {
  @override
  _AdminClientsWithOrdersScreenState createState() =>
      _AdminClientsWithOrdersScreenState();
}

class _AdminClientsWithOrdersScreenState
    extends State<AdminClientsWithOrdersScreen> {
  late OrdersProvider _ordersProvider;
  List<OrderItem> _filteredOrders = [];
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    await _ordersProvider.loadOrdersIfNeeded();
    _filterOrders();
  }

  void _filterOrders() {
    if (_selectedStatus == 'all') {
      setState(() {
        _filteredOrders = _ordersProvider.orders;
      });
    } else {
      setState(() {
        _filteredOrders = _ordersProvider.orders
            .where((order) => order.status == _selectedStatus)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказы клиентов'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          // Фильтр по статусам
          _buildStatusFilter(),
          // Список заказов
          Expanded(
            child: Consumer<OrdersProvider>(
              builder: (context, ordersProvider, child) {
                if (ordersProvider.orders.isEmpty) {
                  return Center(child: Text('Нет заказов'));
                }
                return ListView.builder(
                  itemCount: _filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = _filteredOrders[index];
                    return OrderCard(
                      order: order,
                      onApprove: () async {
                        await ordersProvider.approveOrderForProduction(order);
                        _loadOrders(); // Обновляем список
                      },
                      onReject: () {
                        // Логика отклонения
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Text('Статус: '),
          DropdownButton<String>(
            value: _selectedStatus,
            items: [
              DropdownMenuItem(value: 'all', child: Text('Все')),
              DropdownMenuItem(value: 'оформлен', child: Text('Оформлен')),
              DropdownMenuItem(
                  value: 'в производстве', child: Text('В производстве')),
              DropdownMenuItem(value: 'в работе', child: Text('В работе')),
              DropdownMenuItem(
                  value: 'готов к отправке', child: Text('Готов к отправке')),
              DropdownMenuItem(value: 'доставлен', child: Text('Доставлен')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
              _filterOrders();
            },
          ),
        ],
      ),
    );
  }
}
