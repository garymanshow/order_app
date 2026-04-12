// lib/screens/admin/admin_client_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/client.dart';

// Периоды
enum ClientAnalyticsPeriod {
  week,
  month,
  quarter,
  year,
  allTime,
}

class AdminClientAnalyticsScreen extends StatefulWidget {
  final Client client;

  const AdminClientAnalyticsScreen({super.key, required this.client});

  @override
  State<AdminClientAnalyticsScreen> createState() =>
      _AdminClientAnalyticsScreenState();
}

class _AdminClientAnalyticsScreenState
    extends State<AdminClientAnalyticsScreen> {
  
  final List<String> _statuses = const [
    'оформлен',
    'производство',
    'готов',
    'доставлен',
    'оплачен',
  ];

  // Статусы, где товар уже по факту отдан/готов, а денег нет — это чистый долг
  final Set<String> _debtStatuses = const {
    'готов',
    'доставлен',
    'оплачен', // Оплаченные тоже сверяем, вдруг частичная оплата
  };

  Map<String, int> _statusRub = {}; // Рубли в каждом статусе
  int _totalOrdered = 0;  // Общая сумма заказов (оформлено + в работе)
  int _totalDebt = 0;     // Реальная задолженность
  int _totalPaid = 0;     // Всего оплачено
  String _lastOrderDate = 'Нет данных';
  List<MapEntry<String, int>> _topProducts = [];

  ClientAnalyticsPeriod _selectedPeriod = ClientAnalyticsPeriod.month;

  @override
  void initState() {
    super.initState();
    _calculateAnalytics();
  }

  int _parsePrice(dynamic value) {
    if (value == null) return 0;
    return (double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0).ceil();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ClientAnalyticsPeriod.week: return now.subtract(const Duration(days: 7));
      case ClientAnalyticsPeriod.month: return DateTime(now.year, now.month - 1, now.day);
      case ClientAnalyticsPeriod.quarter: return DateTime(now.year, now.month - 3, now.day);
      case ClientAnalyticsPeriod.year: return DateTime(now.year - 1, now.month, now.day);
      case ClientAnalyticsPeriod.allTime: return DateTime(2000);
    }
  }

  String get _periodTitle {
    switch (_selectedPeriod) {
      case ClientAnalyticsPeriod.week: return 'Неделя';
      case ClientAnalyticsPeriod.month: return 'Месяц';
      case ClientAnalyticsPeriod.quarter: return 'Квартал';
      case ClientAnalyticsPeriod.year: return 'Год';
      case ClientAnalyticsPeriod.allTime: return 'Всё время';
    }
  }

  void _calculateAnalytics() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orders = authProvider.clientData?.orders ?? [];
    final startDate = _getStartDate();

    // Фильтруем заказы ТОЛЬКО этого клиента и за период
    final clientOrders = orders.where((o) {
      if (o.clientName != widget.client.name) return false;
      if (o.date.isNotEmpty) {
        try {
          final orderDate = DateTime.parse(o.date);
          if (orderDate.isBefore(startDate)) return false;
        } catch (e) {
          return false;
        }
      }
      return true;
    }).toList();

    Map<String, int> tempStatusRub = {};
    Map<String, int> productCounts = {};
    DateTime? latestDate;

    _totalOrdered = 0;
    _totalPaid = 0;
    _totalDebt = 0;

    for (var order in clientOrders) {
      final price = _parsePrice(order.totalPrice);
      final payment = _parsePrice(order.paymentAmount);

      // 1. Воронка в РУБЛЯХ
      if (_statuses.contains(order.status)) {
        tempStatusRub[order.status] = (tempStatusRub[order.status] ?? 0) + price;
      }

      // 2. Считаем общие финансы
      _totalOrdered += price;
      _totalPaid += payment;

      // 3. Считаем ДОЛГ (только по отгруженным/готовым статусам)
      if (_debtStatuses.contains(order.status) && price > payment) {
        _totalDebt += (price - payment);
      }

      // 4. Дата последнего заказа
      if (order.date.isNotEmpty) {
        try {
          final d = DateTime.parse(order.date);
          if (latestDate == null || d.isAfter(latestDate)) latestDate = d;
        } catch (e) {}
      }

      // 5. Топ товаров (считаем в штуках для понимания объема)
      if (order.displayName.isNotEmpty) {
        productCounts[order.displayName] = (productCounts[order.displayName] ?? 0) + order.quantity;
      }
    }

    _statusRub = tempStatusRub;

    if (latestDate != null) {
      _lastOrderDate = DateFormat('dd.MM.yyyy').format(latestDate);
    } else {
      _lastOrderDate = 'Нет данных';
    }

    var sortedProducts = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _topProducts = sortedProducts.take(5).toList();

    setState(() {});
  }

  String _formatRub(int value) {
    if (value == 0) return '0 ₽';
    return '${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} ₽';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'оформлен': return Colors.blue;
      case 'производство': return Colors.orange;
      case 'готов': return Colors.purple;
      case 'доставлен': return Colors.green;
      case 'оплачен': return Colors.yellow[700]!;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'оформлен': return 'Оформлен';
      case 'производство': return 'Производство';
      case 'готов': return 'Готов';
      case 'доставлен': return 'Доставлен';
      case 'оплачен': return 'Оплачен';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.name ?? 'Аналитика клиента'),
        actions: [
          // 🔥 КНОПКА ПЕРИОДА
          PopupMenuButton<ClientAnalyticsPeriod>(
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: 'Период',
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _calculateAnalytics();
            },
            itemBuilder: (context) => ClientAnalyticsPeriod.values.map((period) {
              final isSelected = _selectedPeriod == period;
              return PopupMenuItem<ClientAnalyticsPeriod>(
                value: period,
                child: Text(
                  _periodTitle,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDebtCard(),    // 🔥 САМОЕ ГЛАВНОЕ: ДОЛГ
          const SizedBox(height: 16),
          _buildFunnelCard(),  // Воронка в рублях
          const SizedBox(height: 16),
          if (_topProducts.isNotEmpty) _buildTopProductsCard(),
          const SizedBox(height: 16),
          _buildInfoCard(),    // Справочная информация
        ],
      ),
    );
  }

  // ================= ВИДЖЕТЫ =================

  // 🔥 ГЛАВНАЯ КАРТОЧКА: ЗАДОЛЖЕННОСТЬ
  Widget _buildDebtCard() {
    return Card(
      color: _totalDebt > 0 ? Colors.red.shade50 : Colors.green.shade50,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _totalDebt > 0 ? Colors.red.shade200 : Colors.green.shade200,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _totalDebt > 0 ? '⚠️ ЗАДОЛЖЕННОСТЬ' : '✅ НЕТ ЗАДОЛЖЕННОСТИ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _totalDebt > 0 ? Colors.red.shade900 : Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatRub(_totalDebt),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _totalDebt > 0 ? Colors.red : Colors.green,
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Отгружено/Готово на сумму:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      _formatRub((_statusRub['готов'] ?? 0) + (_statusRub['доставлен'] ?? 0)),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Всего оплачено:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      _formatRub(_totalPaid),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ВОРОНКА В РУБЛЯХ
  Widget _buildFunnelCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Воронка заказов (₽)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Всего: ${_formatRub(_totalOrdered)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),
            ..._statuses.map((status) {
              final amount = _statusRub[status] ?? 0;
              // Доля от общей суммы заказов
              final percent = _totalOrdered > 0 ? (amount / _totalOrdered) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: _getStatusColor(status), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_getStatusText(status), style: const TextStyle(fontSize: 13)),
                              Text(
                                _formatRub(amount),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: amount > 0 ? _getStatusColor(status) : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent > 0 ? percent : 0.0, // Динамический прогресс
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(status).withOpacity(0.7)),
                              minHeight: 6,
                            ),
                          ),
                        ],
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
  }

  // ТОП ТОВАРОВ
  Widget _buildTopProductsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏆 Топ товаров (шт)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            ..._topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: index < 3 ? Colors.amber : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${index + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: index < 3 ? Colors.white : Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(product.key, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    Text('${product.value} шт', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ИНФОРМАЦИЯ
  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Реквизиты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildInfoRow('Фирма:', widget.client.firm ?? 'Не указана'),
            _buildInfoRow('Телефон:', widget.client.phone ?? 'Нет данных'),
            _buildInfoRow('Город:', widget.client.city ?? 'Не указан'),
            _buildInfoRow('Последний заказ:', _lastOrderDate),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
