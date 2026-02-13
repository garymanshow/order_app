// lib/screens/driver_route_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/status_update.dart';

class DriverRouteScreen extends StatefulWidget {
  @override
  _DriverRouteScreenState createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  List<ClientWithAddress> _clientsForDelivery = [];
  Map<String, String> _deliveryStatuses = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadClientsForDelivery();
  }

  void _loadClientsForDelivery() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];
    final allClients = authProvider.clientData?.clients ?? [];

    // Найти всех клиентов, у которых есть заказы "готов к отправке"
    final clientNamesFromOrders = <String>{};
    for (var order in allOrders) {
      if (order.status == 'готов к отправке' &&
          order.clientName != null &&
          order.clientName.isNotEmpty) {
        clientNamesFromOrders.add(order.clientName);
      }
    }

    // Сопоставить с данными клиентов
    _clientsForDelivery = [];
    for (var client in allClients) {
      // 🔥 Проверяем, что name не null и совпадает
      if (client.name != null && clientNamesFromOrders.contains(client.name)) {
        _clientsForDelivery.add(ClientWithAddress(
          name: client.name ?? 'Клиент не указан',
          address: client.deliveryAddress ?? 'Адрес не указан',
          phone: client.phone ?? '',
        ));
      }
    }

    _clientsForDelivery.sort((a, b) => a.name.compareTo(b.name));
    _deliveryStatuses.clear();
    setState(() {});
  }

  bool get _canSubmitReport {
    return _clientsForDelivery.isNotEmpty &&
        _clientsForDelivery
            .every((client) => _deliveryStatuses.containsKey(client.name));
  }

  void _setDeliveryStatus(String clientName, String status) {
    setState(() {
      _deliveryStatuses[clientName] = status;
    });
  }

  Future<void> _submitReport() async {
    try {
      final statusUpdates = <StatusUpdate>[];

      for (var client in _clientsForDelivery) {
        final newStatus = _deliveryStatuses[client.name];
        if (newStatus != null) {
          statusUpdates.add(StatusUpdate(
            client: client.name,
            phone: client.phone,
            oldStatus: 'готов к отправке',
            newStatus: newStatus,
          ));
        }
      }

      if (statusUpdates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Нет данных для отправки')),
        );
        return;
      }

      final apiService = ApiService();
      final success = await apiService.updateOrderStatuses(statusUpdates);

      if (success) {
        // TODO: Отправить уведомления через NotificationService
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Отчет успешно отправлен!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки отчета')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Маршрутный лист'),
        backgroundColor: Colors.blue[50],
      ),
      body: Column(
        children: [
          if (_clientsForDelivery.isEmpty)
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
                itemCount: _clientsForDelivery.length,
                itemBuilder: (context, index) {
                  final client = _clientsForDelivery[index];
                  final currentStatus = _deliveryStatuses[client.name];
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
                            client.name,
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
                                        _setDeliveryStatus(
                                            client.name, 'доставлен');
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
                                        _setDeliveryStatus(
                                            client.name, 'корректировка');
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
}

class ClientWithAddress {
  final String name;
  final String address;
  final String phone;

  ClientWithAddress({
    required this.name,
    required this.address,
    required this.phone,
  });
}
