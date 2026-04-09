// lib/screens/client_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/order_item.dart';
import '../models/client.dart';
import '../providers/auth_provider.dart';
import '../utils/parsing_utils.dart';

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<OrderItem>> _ordersByDate = {};
  double _totalDebt = 0;
  bool _isInitialized = false;

  // Локализация
  final DateFormat _dateFormat = DateFormat('d MMMM yyyy', 'ru_RU');
  final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'ru_RU');

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrders();
      });
    }
  }

  void _loadOrders() {
    if (_isInitialized) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentClient = authProvider.currentUser as Client?;

    if (currentClient == null) return;

    final allOrders = authProvider.clientData?.orders ?? [];

    final clientOrders = allOrders
        .where((order) =>
            order.clientPhone == currentClient.phone &&
            order.clientName == currentClient.name)
        .toList();

    double debt = 0;
    for (var order in clientOrders) {
      if (order.status == 'доставлен') {
        debt += order.totalPrice;
      }
    }

    final Map<DateTime, List<OrderItem>> ordersByDate = {};

    for (var order in clientOrders) {
      if (order.status == 'оформлен') continue;

      final date = ParsingUtils.parseDate(order.date);
      if (date != null) {
        final normalizedDate = DateTime(date.year, date.month, date.day);
        ordersByDate.putIfAbsent(normalizedDate, () => []).add(order);
      } else {
        print('❌ Не удалось распарсить дату: "${order.date}"');
      }
    }

    setState(() {
      _ordersByDate = ordersByDate;
      _totalDebt = debt;
      _isInitialized = true;
    });

    print('📅 Загружено заказов для календаря: ${clientOrders.length}');
    print('📅 Долг: $_totalDebt');
  }

  List<OrderItem> _getOrdersForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _ordersByDate[normalized] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentClient = authProvider.currentUser as Client?;

        if (currentClient == null) {
          return const Scaffold(
            body: Center(child: Text('Клиент не выбран')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Мои заказы - ${currentClient.name}'),
                if (_totalDebt > 0)
                  Text(
                    'Долг: ${_totalDebt.toStringAsFixed(2)} ₽',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[300],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Месяц',
                },
                locale: 'ru_RU',
                // 🔥 Устанавливаем понедельник как первый день недели
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
                  weekdayStyle: const TextStyle(fontWeight: FontWeight.bold),
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
                    final orders = _getOrdersForDay(date);
                    if (orders.isEmpty) return const SizedBox();

                    Color markerColor = Colors.grey;
                    for (var order in orders) {
                      final color = _getStatusColor(order.status);
                      if (color != Colors.grey) {
                        markerColor = color;
                        break;
                      }
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
              const SizedBox(height: 8),

              // Легенда
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildLegendItem('Производство', Colors.blue),
                    _buildLegendItem('Готов', Colors.purple),
                    _buildLegendItem('Доставлен', Colors.green),
                    _buildLegendItem('Оплачен', Colors.grey),
                  ],
                ),
              ),

              const Divider(),

              // Список заказов на выбранную дату
              Expanded(
                child: _buildOrderList(_selectedDay),
              ),
            ],
          ),
        );
      },
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
      return const Center(child: Text('Выберите дату'));
    }

    final orders = _getOrdersForDay(selectedDay);

    if (orders.isEmpty) {
      return Center(
        child: Text(
          'Нет заказов на ${_dateFormat.format(selectedDay)}',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(order.status),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              order.productName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${order.quantity} шт × ${(order.totalPrice / order.quantity).toStringAsFixed(2)} ₽',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${order.totalPrice.toStringAsFixed(2)} ₽',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  _getStatusText(order.status),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(order.status).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'производство':
        return Colors.blue;
      case 'готов':
        return Colors.purple;
      case 'доставлен':
        return Colors.green;
      case 'оплачен':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'производство':
        return 'В производстве';
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
}
