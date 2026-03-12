// lib/screens/admin_clients_with_orders_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:charset_converter/charset_converter.dart';
import 'dart:io';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/order_item.dart';
import '../screens/admin_orders_calendar_screen.dart';
import '../screens/admin_client_orders_screen.dart';

class AdminClientsWithOrdersScreen extends StatefulWidget {
  @override
  _AdminClientsWithOrdersScreenState createState() =>
      _AdminClientsWithOrdersScreenState();
}

class _AdminClientsWithOrdersScreenState
    extends State<AdminClientsWithOrdersScreen> {
  final ApiService _apiService = ApiService();

  String _selectedStatus = 'all';
  List<OrderItem> _filteredOrders = [];
  Map<String, List<OrderItem>> _groupedOrders = {};
  double _totalAmount = 0.0;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFilter();
  }

  Future<void> _loadSavedFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFilter = prefs.getString('admin_orders_filter') ?? 'all';
    setState(() {
      _selectedStatus = savedFilter;
    });
    _loadOrders();
  }

  Future<void> _saveFilter(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_orders_filter', filter);
  }

  bool get _canExport {
    return _selectedStatus == 'доставлен';
  }

  List<OrderItem> _getExportableOrders() {
    return _filteredOrders
        .where((order) =>
            order.status == 'доставлен' && order.paymentDocument.isEmpty)
        .toList();
  }

  String? _getNextStatusForFilter(String currentFilter) {
    switch (currentFilter) {
      case 'оформлен':
        return 'производство';
      case 'производство':
        return 'готов';
      case 'готов':
        return 'доставлен';
      case 'доставлен':
        return 'оплачен';
      default:
        return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOrders();
  }

  void _loadOrders() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];

    if (_selectedStatus == 'all') {
      _filteredOrders = List.from(allOrders);
    } else {
      _filteredOrders =
          allOrders.where((order) => order.status == _selectedStatus).toList();
    }

    _groupedOrders = {};
    for (var order in _filteredOrders) {
      final key = '${order.clientPhone}-${order.clientName}';
      if (!_groupedOrders.containsKey(key)) {
        _groupedOrders[key] = [];
      }
      _groupedOrders[key]!.add(order);
    }

    _totalAmount =
        _filteredOrders.fold(0.0, (sum, order) => sum + order.totalPrice);

    setState(() {});
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'оформлен':
        return Colors.blue;
      case 'производство':
        return Colors.orange;
      case 'готов':
        return Colors.purple;
      case 'доставлен':
        return Colors.green;
      case 'оплачен':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'оформлен':
        return 'Оформлен';
      case 'производство':
        return 'В работе';
      case 'готов':
        return 'Готов';
      case 'доставлен':
        return 'Доставлен';
      case 'оплачен':
        return 'Оплачен';
      default:
        return status;
    }
  }

  // ОБНОВЛЕНИЕ СТАТУСА ВСЕХ ЗАКАЗОВ КЛИЕНТА
  Future<void> _updateClientStatus(String clientKey, String newStatus) async {
    setState(() => _isUpdating = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final clientOrders = _groupedOrders[clientKey] ?? [];

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
            'Статус изменен на "${_getStatusText(newStatus)}"', Colors.green);
      } else {
        throw Exception('Не удалось обновить статусы на сервере');
      }
    } catch (e) {
      print('❌ Ошибка обновления статусов: $e');
      _showSnackBar('Ошибка обновления статусов: $e', Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
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

  // ПОКАЗ SNACKBAR
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ЭКСПОРТ В CSV
  Future<void> _exportOrdersToCsv() async {
    final orders = _getExportableOrders();

    if (orders.isEmpty) {
      _showSnackBar('Нет неоплаченных заказов для экспорта', Colors.orange);
      return;
    }

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showSnackBar('Нужно разрешение на запись файлов', Colors.orange);
          return;
        }
      }

      final csvContent = _generateCsvContent(orders);
      final cp1251Bytes = await CharsetConverter.encode('cp1251', csvContent);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/unpaid_orders_$timestamp.csv';

      final file = File(filePath);
      await file.writeAsBytes(cp1251Bytes);

      _showSnackBar('Экспорт сохранен: $filePath', Colors.green);
    } catch (e) {
      _showSnackBar('Ошибка экспорта: $e', Colors.red);
    }
  }

  String _generateCsvContent(List<OrderItem> orders) {
    final headers = [
      'Статус',
      'Название',
      'Количество',
      'Итоговая цена',
      'Дата',
      'Телефон',
      'Клиент'
    ];

    final csvLines = <String>[];
    csvLines.add(headers.join(';'));

    for (var order in orders) {
      final row = [
        _escapeCsvField(_getStatusText(order.status)),
        _escapeCsvField(order.productName),
        order.quantity.toString(),
        order.totalPrice.toStringAsFixed(2),
        _escapeCsvField(order.date),
        _escapeCsvField(order.clientPhone),
        _escapeCsvField(order.clientName),
      ];
      csvLines.add(row.join(';'));
    }

    return csvLines.join('\r\n');
  }

  String _escapeCsvField(String field) {
    if (field.contains(';') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // ПЕРЕХОД К ДЕТАЛЯМ ЗАКАЗОВ КЛИЕНТА
  void _navigateToClientOrders(String clientKey) {
    final parts = clientKey.split('-');
    if (parts.length >= 2) {
      final phone = parts[0];
      final name = parts[1];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminClientOrdersScreen(
            phone: phone,
            clientName: name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказы: Итого ${_totalAmount.toStringAsFixed(2)}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminOrdersCalendarScreen()),
              );
            },
          ),
          if (_canExport)
            IconButton(
              icon: Icon(Icons.file_download),
              onPressed: _exportOrdersToCsv,
              tooltip: 'Экспорт в CSV',
            ),
        ],
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Theme.of(context).cardColor,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusFilterButton('all', 'Все'),
                        _buildStatusFilterButton('оформлен', 'Оформлен'),
                        _buildStatusFilterButton('производство', 'В работе'),
                        _buildStatusFilterButton('готов', 'Готов'),
                        _buildStatusFilterButton('доставлен', 'Доставлен'),
                        _buildStatusFilterButton('оплачен', 'Оплачен'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _groupedOrders.isEmpty
                      ? const Center(child: Text('Нет заказов'))
                      : ListView.builder(
                          itemCount: _groupedOrders.keys.length,
                          itemBuilder: (context, index) {
                            final clientKey =
                                _groupedOrders.keys.elementAt(index);
                            final orders = _groupedOrders[clientKey]!;

                            double clientTotal = 0;
                            for (var order in orders) {
                              clientTotal += order.totalPrice;
                            }

                            final nextStatus =
                                _getNextStatusForFilter(_selectedStatus);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _navigateToClientOrders(clientKey),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              orders.first.clientName ?? '',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${clientTotal.toStringAsFixed(2)} ₽',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              '${orders.length} позиций',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (nextStatus != null)
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                              color: Colors.grey[300]!),
                                        ),
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          _updateClientStatus(
                                              clientKey, nextStatus);
                                        },
                                        child: Text(
                                          'изменить статус',
                                          style: TextStyle(
                                            color: _getStatusColor(nextStatus),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusFilterButton(String statusValue, String displayText) {
    final isSelected = _selectedStatus == statusValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? _getStatusColor(statusValue) : null,
          foregroundColor: isSelected ? Colors.white : null,
        ),
        onPressed: () {
          setState(() {
            _selectedStatus = statusValue;
          });
          _saveFilter(statusValue);
          _loadOrders();
        },
        child: Text(displayText),
      ),
    );
  }
}
