// lib/screens/driver_route_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/order_item.dart';

class ClientWithOrders {
  final String clientName;
  final String address;
  final List<OrderItem> orders;

  ClientWithOrders({
    required this.clientName,
    required this.address,
    required this.orders,
  });
}

class DriverRouteScreen extends StatefulWidget {
  @override
  _DriverRouteScreenState createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  Map<String, ClientWithOrders> _groupedClients = {};
  Map<String, String> _clientStatuses = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadClients();
  }

  void _loadClients() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];

    // Фильтруем только заказы "готов к отправке"
    final readyOrders =
        allOrders.where((order) => order.status == 'готов к отправке').toList();

    // Группируем по полю "Клиент" из заказов
    final ordersByClient = <String, List<OrderItem>>{};
    for (var order in readyOrders) {
      final clientName = order.clientName;
      if (clientName != null && clientName.isNotEmpty) {
        if (!ordersByClient.containsKey(clientName)) {
          ordersByClient[clientName] = [];
        }
        ordersByClient[clientName]!.add(order);
      }
    }

    // Создаем список клиентов для маршрутного листа
    _groupedClients = {};
    for (var clientName in ordersByClient.keys) {
      final orders = ordersByClient[clientName]!;

      // Попробуем получить адрес из первого заказа
      String address = 'Адрес не указан';
      if (orders.isNotEmpty && orders.first.deliveryAddress != null) {
        address = orders.first.deliveryAddress!;
      }

      _groupedClients[clientName] = ClientWithOrders(
        clientName: clientName,
        address: address,
        orders: orders,
      );
    }

    _clientStatuses.clear();
    setState(() {});
  }

  bool get _canSubmitReport {
    return _groupedClients.isNotEmpty &&
        _groupedClients.keys
            .every((clientName) => _clientStatuses.containsKey(clientName));
  }

  void _setClientStatus(String clientName, String status) {
    setState(() {
      _clientStatuses[clientName] = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clientsList = _groupedClients.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Маршрутный лист'),
        backgroundColor: Colors.blue[50],
      ),
      body: Column(
        children: [
          if (clientsList.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Нет клиентов для доставки',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: clientsList.length,
                itemBuilder: (context, index) {
                  final client = clientsList[index];
                  final currentStatus = _clientStatuses[client.clientName];
                  final isDelivered = currentStatus == 'доставлен';
                  final isCorrection = currentStatus == 'корректировка';
                  final hasStatus = isDelivered || isCorrection;

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.clientName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            client.address,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDelivered
                                      ? Colors.green
                                      : Colors.grey[300],
                                  foregroundColor: isDelivered
                                      ? Colors.white
                                      : Colors.grey[600],
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: hasStatus && !isDelivered
                                    ? null
                                    : () {
                                        _setClientStatus(
                                            client.clientName, 'доставлен');
                                      },
                                child: Text('Доставлен',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isCorrection
                                      ? Colors.red
                                      : Colors.grey[300],
                                  foregroundColor: isCorrection
                                      ? Colors.white
                                      : Colors.grey[600],
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: hasStatus && !isCorrection
                                    ? null
                                    : () {
                                        _setClientStatus(
                                            client.clientName, 'корректировка');
                                      },
                                child: Text('Корректировка',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _canSubmitReport ? _submitReport : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmitReport ? Colors.blue : Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Оформить отчет',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    // TODO: Реализуем после создания ApiService и NotificationService
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Отчет отправлен!')),
    );
    Navigator.pop(context);
  }
}
