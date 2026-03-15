// lib/screens/driver_route_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/web_push_service.dart';
import '../services/env_service.dart';
import '../models/status_update.dart';
import '../models/employee.dart';

class DriverRouteScreen extends StatefulWidget {
  @override
  _DriverRouteScreenState createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  final ApiService _apiService = ApiService();
  final WebPushService _pushService = WebPushService();

  List<ClientWithAddress> _clientsForDelivery = [];
  Map<String, String> _deliveryStatuses = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initPushService();
  }

  Future<void> _initPushService() async {
    try {
      await _pushService.initialize(EnvService.vapidPublicKey);
      print('✅ Push сервис инициализирован');
    } catch (e) {
      print('⚠️ Ошибка инициализации push: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadClientsForDelivery();
  }

  void _loadClientsForDelivery() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];
    final allClients = authProvider.clientData?.clients ?? [];

    final clientNamesFromOrders = <String>{};
    for (var order in allOrders) {
      if (order.status == 'готов' && order.clientName.isNotEmpty) {
        clientNamesFromOrders.add(order.clientName);
      }
    }

    _clientsForDelivery = [];
    for (var client in allClients) {
      if (client.name != null && clientNamesFromOrders.contains(client.name)) {
        _clientsForDelivery.add(ClientWithAddress(
          name: client.name!,
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

  // 🔥 Получение сводки по доставкам
  Map<String, dynamic> _getDeliverySummary() {
    int delivered = 0;
    int corrections = 0;

    for (var client in _clientsForDelivery) {
      final status = _deliveryStatuses[client.name];
      if (status == 'доставлен') delivered++;
      if (status == 'корректировка') corrections++;
    }

    return {
      'delivered': delivered,
      'corrections': corrections,
      'total': _clientsForDelivery.length,
      'summary': 'Доставлено: $delivered, Корректировка: $corrections'
    };
  }

  // 🔥 Отправка уведомлений менеджерам через ApiService
  Future<void> _sendNotificationsToManagers() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null || currentUser.phone == null) {
        print('⚠️ Пользователь не авторизован');
        return;
      }

      // Находим всех менеджеров
      final managers = authProvider.clientData?.clients
              .whereType<Employee>()
              .where((e) =>
                  e.role == 'Менеджер' &&
                  e.phone != null &&
                  e.phone!.isNotEmpty)
              .toList() ??
          [];

      if (managers.isEmpty) {
        print('ℹ️ Нет менеджеров для уведомлений');
        return;
      }

      final summary = _getDeliverySummary()['summary'] as String;

      // Отправляем уведомление каждому менеджеру через ApiService
      int successCount = 0;

      for (var manager in managers) {
        try {
          final success = await _apiService.sendNotification(
            targetPhone: manager.phone!,
            title: 'Отчет о доставке',
            body: 'Водитель завершил маршрут. $summary',
          );

          if (success) {
            successCount++;
            print('📨 Уведомление отправлено менеджеру: ${manager.name}');
          } else {
            print(
                '⚠️ Не удалось отправить уведомление менеджеру: ${manager.name}');
          }

          // Небольшая задержка между отправками
          await Future.delayed(Duration(milliseconds: 200));
        } catch (e) {
          print('❌ Ошибка отправки менеджеру ${manager.name}: $e');
        }
      }

      print('📨 Отправлено уведомлений: $successCount из ${managers.length}');
    } catch (e) {
      print('⚠️ Ошибка отправки уведомлений: $e');
    }
  }

  // 🔥 Отправка отчета
  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      final statusUpdates = <StatusUpdate>[];

      for (var client in _clientsForDelivery) {
        final newStatus = _deliveryStatuses[client.name];
        if (newStatus != null) {
          statusUpdates.add(StatusUpdate(
            client: client.name,
            phone: client.phone,
            oldStatus: 'готов',
            newStatus: newStatus,
          ));
        }
      }

      if (statusUpdates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет данных для отправки')),
        );
        return;
      }

      // Отправляем обновления статусов
      final success = await _apiService.updateOrderStatuses(statusUpdates);

      if (success) {
        // Обновляем локальные данные
        await _updateLocalOrders(statusUpdates);

        // Отправляем уведомления менеджерам (не ждем завершения)
        _sendNotificationsToManagers().catchError((e) {
          print('⚠️ Фоновая отправка уведомлений: $e');
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Отчет успешно отправлен!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Ошибка отправки отчета');
      }
    } catch (e) {
      print('❌ Ошибка: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateLocalOrders(List<StatusUpdate> updates) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      for (var update in updates) {
        for (int i = 0; i < authProvider.clientData!.orders.length; i++) {
          final order = authProvider.clientData!.orders[i];
          if (order.clientName == update.client && order.status == 'готов') {
            authProvider.clientData!.orders[i] =
                order.copyWith(status: update.newStatus);
          }
        }
      }

      authProvider.clientData!.buildIndexes();

      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));

      print('✅ Локальные заказы обновлены');
    } catch (e) {
      print('⚠️ Ошибка обновления локальных заказов: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _getDeliverySummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Маршрутный лист'),
        backgroundColor: Colors.blue[50],
        bottom: _clientsForDelivery.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    summary['summary'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_clientsForDelivery.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Нет клиентов для доставки',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _clientsForDelivery.length,
                      itemBuilder: (context, index) {
                        final client = _clientsForDelivery[index];
                        final currentStatus = _deliveryStatuses[client.name];
                        final isDelivered = currentStatus == 'доставлен';
                        final isCorrection = currentStatus == 'корректировка';
                        final hasStatus = isDelivered || isCorrection;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDelivered
                                            ? Colors.green
                                            : isCorrection
                                                ? Colors.red
                                                : Colors.blue,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            client.address,
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatusButton(
                                      label: 'Доставлен',
                                      color: Colors.green,
                                      isSelected: isDelivered,
                                      onPressed: hasStatus && !isDelivered
                                          ? null
                                          : () => _setDeliveryStatus(
                                              client.name, 'доставлен'),
                                    ),
                                    _buildStatusButton(
                                      label: 'Корректировка',
                                      color: Colors.red,
                                      isSelected: isCorrection,
                                      onPressed: hasStatus && !isCorrection
                                          ? null
                                          : () => _setDeliveryStatus(
                                              client.name, 'корректировка'),
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
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _canSubmitReport ? _submitReport : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _canSubmitReport ? Colors.blue : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
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

  Widget _buildStatusButton({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? color : Colors.grey[300],
            foregroundColor: isSelected ? Colors.white : Colors.grey[600],
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
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
