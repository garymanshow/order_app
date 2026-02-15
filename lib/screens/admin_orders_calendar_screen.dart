// lib/screens/admin_orders_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_item.dart';
import '../providers/auth_provider.dart';
import '../utils/parsing_utils.dart';

class AdminOrdersCalendarScreen extends StatefulWidget {
  @override
  _AdminOrdersCalendarScreenState createState() =>
      _AdminOrdersCalendarScreenState();
}

class _AdminOrdersCalendarScreenState extends State<AdminOrdersCalendarScreen> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<OrderItem> _orders = [];
  DateTime? _minDate;
  DateTime? _maxDate;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = today;
    _selectedDay = today;

    _loadSavedCalendarFilter();
  }

  Future<void> _loadSavedCalendarFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFilter = prefs.getString('admin_calendar_filter') ?? 'all';
    setState(() {
      _filterStatus = savedFilter;
    });
    _loadOrders();
  }

  Future<void> _saveCalendarFilter(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_calendar_filter', filter);
  }

  void _loadOrders() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    var allOrders = authProvider.clientData?.orders ?? [];

    // Применяем фильтр
    if (_filterStatus != 'all') {
      allOrders =
          allOrders.where((order) => order.status == _filterStatus).toList();
    }

    setState(() {
      _orders = allOrders;
      _calculateDateRange();
    });
  }

  void _calculateDateRange() {
    if (_orders.isEmpty) {
      _minDate = DateTime.now().subtract(const Duration(days: 30));
      _maxDate = DateTime.now().add(const Duration(days: 30));
      return;
    }

    DateTime? minDate;
    DateTime? maxDate;

    for (var order in _orders) {
      final date = ParsingUtils.parseDate(order.date);
      if (date != null) {
        if (minDate == null || date.isBefore(minDate)) {
          minDate = date;
        }
        if (maxDate == null || date.isAfter(maxDate)) {
          maxDate = date;
        }
      }
    }

    _minDate = minDate ?? DateTime.now().subtract(const Duration(days: 30));
    _maxDate = maxDate ?? DateTime.now().add(const Duration(days: 30));

    if (DateTime.now().isBefore(_minDate!)) {
      _focusedDay = DateTime(_minDate!.year, _minDate!.month, 1);
    } else if (DateTime.now().isAfter(_maxDate!)) {
      _focusedDay = DateTime(_maxDate!.year, _maxDate!.month, 1);
    }
  }

  List<OrderItem> _getOrdersForDate(DateTime date) {
    final dateString = '${date.day}.${date.month}.${date.year}';
    return _orders.where((order) => order.date == dateString).toList();
  }

  Color? _getDayColor(DateTime day) {
    final orders = _getOrdersForDate(day);
    if (orders.isEmpty) return null;

    // Возвращаем цвет первого заказа (или приоритетный статус)
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
      case 'производство':
        return Colors.orange;
      case 'готов':
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

  double _calculateTotalDebt() {
    if (_filterStatus != 'all' && _filterStatus != 'доставлен') {
      return 0.0; // Задолженность только для доставленных
    }

    double totalDeht = 0;
    for (var order in _orders) {
      if (order.status == 'доставлен' && !order.isPaid) {
        totalDeht += order.totalPrice - order.paymentAmount;
      }
    }
    return totalDeht;
  }

  @override
  Widget build(BuildContext context) {
    final debt = _calculateTotalDebt();
    final hasDebt = debt > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Календарь заказов'),
        backgroundColor: hasDebt ? Colors.red[50] : null,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 🔥 КНОПКА ФИЛЬТРАЦИИ В КАЛЕНДАРЕ
          PopupMenuButton<String>(
            onSelected: (String result) {
              _saveCalendarFilter(result);
              setState(() {
                _filterStatus = result;
              });
              _loadOrders();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('Все заказы'),
              ),
              const PopupMenuItem<String>(
                value: 'оформлен',
                child: Text('Оформлен'),
              ),
              const PopupMenuItem<String>(
                value: 'производство',
                child: Text('В работе'),
              ),
              const PopupMenuItem<String>(
                value: 'готов',
                child: Text('Готов'),
              ),
              const PopupMenuItem<String>(
                value: 'доставлен',
                child: Text('Доставлен'),
              ),
              const PopupMenuItem<String>(
                value: 'оплачен',
                child: Text('Оплачен'),
              ),
            ],
          ),
        ],
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
                    'Общая задолженность: ${debt.toStringAsFixed(2)} ₽',
                    style: TextStyle(
                      fontSize: 16,
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

    // Группируем заказы по клиентам
    final Map<String, List<OrderItem>> groupedOrders = {};
    for (var order in orders) {
      final key = '${order.clientPhone}-${order.clientName}';
      if (!groupedOrders.containsKey(key)) {
        groupedOrders[key] = [];
      }
      groupedOrders[key]!.add(order);
    }

    return Expanded(
      child: ListView.builder(
        itemCount: groupedOrders.keys.length,
        itemBuilder: (context, index) {
          final clientKey = groupedOrders.keys.elementAt(index);
          final clientOrders = groupedOrders[clientKey]!;
          final firstOrder = clientOrders.first;

          // Считаем сумму для клиента
          double clientTotal = 0;
          for (var order in clientOrders) {
            clientTotal += order.totalPrice;
          }

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstOrder.clientName ?? '',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Телефон: ${firstOrder.clientPhone}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text('Сумма: ${clientTotal.toStringAsFixed(2)} ₽'),
                  SizedBox(height: 8),
                  // Показываем все заказы клиента
                  ...clientOrders.map((order) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${order.productName} (${order.quantity} шт)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status)
                                  ?.withAlpha((0.2 * 255).toInt()),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getStatusText(order.status),
                              style: TextStyle(
                                  color: _getStatusColor(order.status)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
          _buildLegendItem('В работе', Colors.orange),
          _buildLegendItem('Готов', Colors.purple),
          _buildLegendItem('Доставлен', Colors.green),
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
