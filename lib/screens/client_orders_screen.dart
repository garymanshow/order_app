// lib/screens/client_orders_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/order_item.dart';
import '../models/client.dart'; // ← ИМПОРТ КЛИЕНТА

class ClientOrdersScreen extends StatefulWidget {
  final Client client;

  const ClientOrdersScreen({Key? key, required this.client}) : super(key: key);

  @override
  _ClientOrdersScreenState createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<OrderItem> _orders = [];
  DateTime? _minDate;
  DateTime? _maxDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = today;
    _selectedDay = today;

    _loadOrdersFromCache();
  }

  Future<void> _loadOrdersFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersJson = prefs.getString('client_orders_data');

    if (ordersJson != null) {
      final orders = _deserializeOrders(ordersJson);
      setState(() {
        _orders = orders;
        _calculateDateRange();
      });
    }
  }

  List<OrderItem> _deserializeOrders(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Ошибка десериализации заказов: $e');
      return [];
    }
  }

  void _calculateDateRange() {
    if (_orders.isEmpty) {
      _minDate = DateTime.now().subtract(Duration(days: 30));
      _maxDate = DateTime.now().add(Duration(days: 30));
      return;
    }

    DateTime? minDate;
    DateTime? maxDate;

    for (var order in _orders) {
      final date = _parseOrderDate(order.date);
      if (date != null) {
        if (minDate == null || date.isBefore(minDate)) {
          minDate = date;
        }
        if (maxDate == null || date.isAfter(maxDate)) {
          maxDate = date;
        }
      }
    }

    _minDate = minDate ?? DateTime.now().subtract(Duration(days: 30));
    _maxDate = maxDate ?? DateTime.now().add(Duration(days: 30));

    if (DateTime.now().isBefore(_minDate!)) {
      _focusedDay = DateTime(_minDate!.year, _minDate!.month, 1);
    } else if (DateTime.now().isAfter(_maxDate!)) {
      _focusedDay = DateTime(_maxDate!.year, _maxDate!.month, 1);
    }
  }

  DateTime? _parseOrderDate(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (e) {
      print('Ошибка парсинга даты: $e');
    }
    return null;
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД
  List<OrderItem> _getOrdersForDate(DateTime date) {
    final dateString = '${date.day}.${date.month}.${date.year}';
    return _orders
        .where((order) =>
                order.date == dateString &&
                order.clientPhone == widget.client.phone && // ← ИСПРАВЛЕНО
                order.clientName == widget.client.name // ← ИСПРАВЛЕНО
            )
        .toList();
  }

  Color? _getDayColor(DateTime day) {
    final orders = _getOrdersForDate(day);
    if (orders.isEmpty) return null;

    for (var order in orders) {
      final color = _getStatusColor(order.status);
      if (color != null) return color;
    }
    return null;
  }

  Color? _getStatusColor(String status) {
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
        return null;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'оформлен':
        return 'Оформлен';
      case 'в производстве':
        return 'В производстве';
      case 'готов к отправке':
        return 'Готов';
      case 'доставлен':
        return 'Получен';
      case 'оплачен':
        return 'Оплачен';
      default:
        return status;
    }
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД
  double _calculateDebt() {
    double totalDebt = 0;
    final clientOrders = _orders
        .where((order) =>
            order.clientPhone == widget.client.phone &&
            order.clientName == widget.client.name)
        .toList();

    for (var order in clientOrders) {
      if (order.status == 'доставлен' &&
          order.paymentAmount < order.totalPrice) {
        totalDebt += order.totalPrice - order.paymentAmount;
      }
    }
    return totalDebt;
  }

  @override
  Widget build(BuildContext context) {
    final debt = _calculateDebt();
    final hasDebt = debt > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Мои заказы'),
        backgroundColor: hasDebt ? Colors.red[50] : null,
      ),
      body: Column(
        children: [
          if (hasDebt)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.red[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Задолженность: ${debt.toStringAsFixed(2)} ₽',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                ],
              ),
            ),
          TableCalendar(
            firstDay: _minDate ?? DateTime.utc(2020, 1, 1),
            lastDay: _maxDate ?? DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: Colors.grey[400]),
              weekendTextStyle: TextStyle(color: Colors.grey[400]),
            ),
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                return Center(
                  child: Text(
                    DateFormat.E().format(day).substring(0, 1),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
              defaultBuilder: (context, day, events) {
                final hasOrders = _getOrdersForDate(day).isNotEmpty;
                final isSelected = isSameDay(_selectedDay, day);

                return GestureDetector(
                  onTap: () {
                    if (hasOrders) {
                      setState(() {
                        _selectedDay = day;
                        _focusedDay = day;
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[100] : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: hasOrders ? Colors.black : Colors.grey[400],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
              markerBuilder: (context, day, events) {
                final color = _getDayColor(day);
                if (color == null) return null;

                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            eventLoader: (day) => _getOrdersForDate(day),
          ),
          _buildDetailedDayInfo(),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildDetailedDayInfo() {
    final orders = _getOrdersForDate(_selectedDay);
    if (orders.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Нет заказов на ${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year}',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.productName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Количество: ${order.quantity} шт'),
                      Text('${order.totalPrice.toStringAsFixed(2)} ₽',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status)
                          ?.withAlpha((0.2 * 255).toInt()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: TextStyle(color: _getStatusColor(order.status)),
                    ),
                  ),
                  if (order.status == 'доставлен' || order.isPaid)
                    Column(
                      children: [
                        SizedBox(height: 8),
                        Divider(),
                        SizedBox(height: 8),
                        if (order.paymentAmount > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Оплачено:'),
                              Text(
                                  '${order.paymentAmount.toStringAsFixed(2)} ₽',
                                  style: TextStyle(color: Colors.green)),
                            ],
                          ),
                        if (order.status == 'доставлен' && !order.isPaid)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('К оплате:'),
                              Text(
                                  '${(order.totalPrice - order.paymentAmount).toStringAsFixed(2)} ₽',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        if (order.paymentDocument.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Платёжный документ:'),
                              Flexible(
                                child: Text(
                                  order.paymentDocument,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _buildLegendItem('Оформлен', Colors.blue),
          _buildLegendItem('В производстве', Colors.orange),
          _buildLegendItem('Готов', Colors.purple),
          _buildLegendItem('Получен', Colors.green),
          _buildLegendItem('Оплачен', Colors.yellow[700]!),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
