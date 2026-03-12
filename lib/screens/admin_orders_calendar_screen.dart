// lib/screens/admin_orders_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/auth_provider.dart';
import '../models/order_item.dart';
import '../utils/parsing_utils.dart';
import 'admin_client_orders_screen.dart';

class AdminOrdersCalendarScreen extends StatefulWidget {
  @override
  _AdminOrdersCalendarScreenState createState() =>
      _AdminOrdersCalendarScreenState();
}

class _AdminOrdersCalendarScreenState extends State<AdminOrdersCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<OrderItem>> _ordersByDate = {};
  bool _isLoading = true;

  final DateFormat _dateFormat = DateFormat('d MMMM yyyy', 'ru_RU');
  final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'ru_RU');
  final DateFormat _dayMonthFormat = DateFormat('d MMMM', 'ru_RU');

  final Map<String, Color> _statusColors = {
    'оформлен': Colors.grey,
    'производство': Colors.orange,
    'готов': Colors.blue,
    'доставлен': Colors.green,
    'отменен': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadOrders();
  }

  void _loadOrders() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];

    final Map<DateTime, List<OrderItem>> ordersByDate = {};

    for (var order in allOrders) {
      if (order.status == 'отменен') continue;

      try {
        final dateParts = order.date.split('.');
        if (dateParts.length == 3) {
          final day = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final year = int.parse(dateParts[2]);
          final date = DateTime(year, month, day);

          ordersByDate.putIfAbsent(date, () => []).add(order);
        }
      } catch (e) {
        print('⚠️ Ошибка парсинга даты: ${order.date}');
      }
    }

    setState(() {
      _ordersByDate = ordersByDate;
      _isLoading = false;
    });
  }

  List<OrderItem> _getOrdersForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _ordersByDate[normalized] ?? [];
  }

  Color _getMarkerColorForDate(DateTime date) {
    final orders = _getOrdersForDay(date);
    if (orders.isEmpty) return Colors.transparent;

    if (orders.any((o) => o.status == 'доставлен')) {
      return Colors.green;
    }
    if (orders.any((o) => o.status == 'готов')) {
      return Colors.blue;
    }
    if (orders.any((o) => o.status == 'производство')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  Map<String, List<OrderItem>> _groupOrdersByClient(List<OrderItem> orders) {
    final grouped = <String, List<OrderItem>>{};
    for (var order in orders) {
      final key = '${order.clientPhone}_${order.clientName}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(order);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь заказов'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2026, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Месяц',
                      },
                      locale: 'ru_RU',
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: HeaderStyle(
                        titleTextStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        titleTextFormatter: (date, locale) =>
                            _monthYearFormat.format(date),
                        formatButtonVisible: false,
                        leftChevronIcon: const Icon(Icons.chevron_left),
                        rightChevronIcon: const Icon(Icons.chevron_right),
                      ),
                      calendarStyle: CalendarStyle(
                        weekendTextStyle: const TextStyle(color: Colors.red),
                        selectedDecoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 1,
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle:
                            const TextStyle(fontWeight: FontWeight.bold),
                        weekendStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final markerColor = _getMarkerColorForDate(date);
                          if (markerColor == Colors.transparent) {
                            return const SizedBox();
                          }

                          return Positioned(
                            bottom: 1,
                            right: 1,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: markerColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildLegendItem('В производстве', Colors.orange),
                      _buildLegendItem('Готов', Colors.blue),
                      _buildLegendItem('Доставлен', Colors.green),
                      _buildLegendItem('Оформлен', Colors.grey),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _buildOrderList(_selectedDay),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
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
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildOrderList(DateTime? selectedDay) {
    if (selectedDay == null) {
      return const Center(
        child: Text('Выберите дату в календаре'),
      );
    }

    final orders = _getOrdersForDay(selectedDay);

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет заказов на ${_dayMonthFormat.format(selectedDay)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final groupedByClient = _groupOrdersByClient(orders);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedByClient.keys.length,
      itemBuilder: (context, index) {
        final clientKey = groupedByClient.keys.elementAt(index);
        final clientOrders = groupedByClient[clientKey]!;
        final clientName = clientOrders.first.clientName;
        final clientPhone = clientOrders.first.clientPhone;

        double total = 0;
        for (var order in clientOrders) {
          total += order.totalPrice;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminClientOrdersScreen(
                    phone: clientPhone,
                    clientName: clientName,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${clientOrders.length} позиций',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${total.toStringAsFixed(2)} ₽',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...clientOrders.take(3).map((order) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    _statusColors[order.status] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order.productName,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${order.quantity} шт',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      )),
                  if (clientOrders.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'и еще ${clientOrders.length - 3}...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
