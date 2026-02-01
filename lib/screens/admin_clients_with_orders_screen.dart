// lib/screens/admin_clients_with_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../models/order_item.dart';
import '../screens/admin_client_orders_detail_screen.dart';
import '../screens/admin_orders_calendar_screen.dart';
import '../services/api_service.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminClientsWithOrdersScreen extends StatefulWidget {
  @override
  _AdminClientsWithOrdersScreenState createState() =>
      _AdminClientsWithOrdersScreenState();
}

class _AdminClientsWithOrdersScreenState
    extends State<AdminClientsWithOrdersScreen> {
  String _selectedStatus = 'all';
  List<OrderItem> _filteredOrders = [];
  Map<String, List<OrderItem>> _groupedOrders = {};
  double _totalAmount = 0.0;

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
    return _selectedStatus == 'доставлен'; // Только при фильтре "доставлен"
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
        return 'в производстве';
      case 'в производстве':
        return 'готов к отправке';
      case 'готов к отправке':
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
      case 'в производстве':
        return Colors.orange;
      case 'готов к отправке':
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
      case 'в производстве':
        return 'В работе';
      case 'готов к отправке':
        return 'Готов';
      case 'доставлен':
        return 'Доставлен';
      case 'оплачен':
        return 'Оплачен';
      default:
        return status;
    }
  }

  Future<void> _updateClientStatus(String clientKey, String newStatus) async {
    final orders = _groupedOrders[clientKey]!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final updatedOrders = orders.map((order) {
      return order.copyWith(status: newStatus);
    }).toList();

    final apiService = ApiService();
    final success = await apiService.updateOrders(updatedOrders);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Статус изменен на "${_getStatusText(newStatus)}"')),
      );
      _loadOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка изменения статуса')),
      );
    }
  }

  Future<void> _exportOrdersToCsv() async {
    final orders = _getExportableOrders();

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Нет неоплаченных заказов для экспорта')),
      );
      return;
    }

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Нужно разрешение на запись файлов')),
          );
          return;
        }
      }

      final csvContent = _generateCsvContent(orders);
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/unpaid_orders_$timestamp.csv';

      final file = File(filePath);
      await file.writeAsString(csvContent, encoding: utf8);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Экспорт неоплаченных заказов сохранен'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

  String _generateCsvContent(List<OrderItem> orders) {
    const bom = '\uFEFF';
    final headers = [
      'Статус',
      'Название',
      'Количество',
      'Итоговая цена',
      'Дата',
      'Телефон',
      'Клиент',
      'Оплата',
      'Платежный документ'
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
        order.paymentAmount.toStringAsFixed(2),
        _escapeCsvField(order.paymentDocument),
      ];
      csvLines.add(row.join(';'));
    }

    return bom + csvLines.join('\n');
  }

  String _escapeCsvField(String field) {
    if (field.contains(';') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
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
              onPressed: () => _exportOrdersToCsv(),
              tooltip: 'Экспорт в CSV',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            color: Theme.of(context).cardColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusFilterButton('all', 'Все'),
                  _buildStatusFilterButton('оформлен', 'Оформлен'),
                  _buildStatusFilterButton('в производстве', 'В работе'),
                  _buildStatusFilterButton('готов к отправке', 'Готов'),
                  _buildStatusFilterButton('доставлен', 'Доставлен'),
                  _buildStatusFilterButton('оплачен', 'Оплачен'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _groupedOrders.isEmpty
                ? Center(child: Text('Нет заказов'))
                : ListView.builder(
                    itemCount: _groupedOrders.keys.length,
                    itemBuilder: (context, index) {
                      final clientKey = _groupedOrders.keys.elementAt(index);
                      final orders = _groupedOrders[clientKey]!;

                      double clientTotal = 0;
                      for (var order in orders) {
                        clientTotal += order.totalPrice;
                      }

                      final nextStatus =
                          _getNextStatusForFilter(_selectedStatus);

                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminClientOrdersDetailScreen(
                                        clientPhone: orders.first.clientPhone,
                                        clientName: orders.first.clientName,
                                        orders: orders,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        orders.first.clientName ?? '',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${clientTotal.toStringAsFixed(2)} ₽',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
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
                                    left: BorderSide(color: Colors.grey[300]!),
                                  ),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    _updateClientStatus(clientKey, nextStatus);
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
      padding: EdgeInsets.only(right: 8),
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
