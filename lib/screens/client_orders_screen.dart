// lib/screens/client_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/order_item.dart';
import '../utils/parsing_utils.dart';

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  _ClientOrdersScreenState createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = today;
    _selectedDay = today;
  }

  // 🔥 Получаем заказы из AuthProvider
  List<OrderItem> _getOrdersForDate(DateTime date) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final client = authProvider.currentUser;
    final clientData = authProvider.clientData;

    if (client == null || clientData == null) return [];

    final dateString = '${date.day}.${date.month}.${date.year}';
    return clientData.orders
        .where((order) =>
            order.date == dateString &&
            order.clientPhone == client.phone &&
            order.clientName == client.name)
        .toList();
  }

  // 🔥 Рассчитываем диапазон дат из актуальных данных
  void _calculateDateRange() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData;
    final client = authProvider.currentUser;

    if (clientData == null || client == null) {
      setState(() {
        _focusedDay = DateTime.now();
        _selectedDay = DateTime.now();
      });
      return;
    }

    final clientOrders = clientData.orders
        .where((order) =>
            order.clientPhone == client.phone &&
            order.clientName == client.name)
        .toList();

    if (clientOrders.isEmpty) {
      setState(() {
        _focusedDay = DateTime.now();
        _selectedDay = DateTime.now();
      });
      return;
    }

    DateTime? minDate;
    DateTime? maxDate;

    for (var order in clientOrders) {
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

    if (minDate != null && maxDate != null) {
      setState(() {
        _focusedDay = DateTime.now().isBefore(minDate!)
            ? DateTime(minDate.year, minDate.month, 1)
            : DateTime.now().isAfter(maxDate!)
                ? DateTime(maxDate.year, maxDate.month, 1)
                : DateTime.now();
        _selectedDay = DateTime.now();
      });
    }
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
        return 'В производстве';
      case 'готов':
        return 'Готов';
      case 'доставлен':
        return 'Получен';
      case 'оплачен':
        return 'Оплачен';
      default:
        return status;
    }
  }

  // 🔥 Расчёт долга из актуальных данных
  double _calculateDebt() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final client = authProvider.currentUser;
    final clientData = authProvider.clientData;

    if (client == null || clientData == null) return 0.0;

    final clientOrders = clientData.orders
        .where((order) =>
            order.clientPhone == client.phone &&
            order.clientName == client.name)
        .toList();

    double totalDebt = 0;
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
    // 🔥 Слушаем AuthProvider для обновления
    final authProvider = Provider.of<AuthProvider>(context);

    // Проверка состояния авторизации
    if (!authProvider.isAuthenticated || authProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мои заказы')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Проверка наличия данных
    final clientData = authProvider.clientData;
    if (clientData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Данные заказов не загружены'),
              ElevatedButton(
                onPressed: () async {
                  await authProvider.login(authProvider.currentUser!.phone!);
                },
                child: const Text('Повторить загрузку'),
              ),
            ],
          ),
        ),
      );
    }

    // Автоматически пересчитываем диапазон дат
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDateRange();
    });

    final hasDebt = _calculateDebt() > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заказы'),
        backgroundColor: hasDebt ? Colors.red[50] : null,
      ),
      body: Column(
        children: [
          if (hasDebt)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Задолженность: ${_calculateDebt().toStringAsFixed(2)} ₽',
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
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                final orders = _getOrdersForDate(day);
                if (orders.isEmpty) return null;

                // Берем цвет первого заказа в день
                final color = _getStatusColor(orders.first.status);
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
        padding: const EdgeInsets.all(16),
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.productName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Количество: ${order.quantity} шт'),
                      Text('${order.totalPrice.toStringAsFixed(2)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        if (order.paymentAmount > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Оплачено:'),
                              Text(
                                  '${order.paymentAmount.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                        if (order.status == 'доставлен' && !order.isPaid)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('К оплате:'),
                              Text(
                                  '${(order.totalPrice - order.paymentAmount).toStringAsFixed(2)} ₽',
                                  style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        if (order.paymentDocument.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Платёжный документ:'),
                              Flexible(
                                child: Text(
                                  order.paymentDocument,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(16),
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
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
