// lib/screens/admin/admin_client_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/client.dart';
import '../../models/order_item.dart';

class AdminClientAnalyticsScreen extends StatefulWidget {
  final Client client;

  const AdminClientAnalyticsScreen({super.key, required this.client});

  @override
  State<AdminClientAnalyticsScreen> createState() =>
      _AdminClientAnalyticsScreenState();
}

class _AdminClientAnalyticsScreenState
    extends State<AdminClientAnalyticsScreen> {
  // Воронка продаж
  final List<String> _statuses = const [
    'оформлен',
    'производство',
    'готов',
    'доставлен',
    'оплачен',
  ];

  Map<String, int> _statusCounts = {};
  double _totalSpent = 0.0;
  double _totalPaid = 0.0;
  double _totalDebt = 0.0;
  int _totalItems = 0;
  String _lastOrderDate = 'Нет данных';

  // Популярные товары
  List<MapEntry<String, int>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _calculateAnalytics();
  }

  void _calculateAnalytics() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orders = authProvider.clientData?.orders ?? [];

    // Фильтруем заказы ТОЛЬКО этого клиента
    final clientOrders =
        orders.where((o) => o.clientPhone == widget.client.phone).toList();

    Map<String, int> tempStatusCounts = {};
    Map<String, int> productCounts = {};
    DateTime? latestDate;

    for (var order in clientOrders) {
      // 1. Считаем статусы (только по воронке продаж, без "запас" и т.д.)
      if (_statuses.contains(order.status)) {
        tempStatusCounts[order.status] =
            (tempStatusCounts[order.status] ?? 0) + 1;
      }

      // 2. Считаем деньги и штуки
      _totalSpent += order.totalPrice;
      _totalPaid += order.paymentAmount;
      _totalItems += order.quantity;

      // 3. Ищем последний заказ
      if (order.date.isNotEmpty) {
        try {
          final d = DateTime.parse(order.date);
          if (latestDate == null || d.isAfter(latestDate)) {
            latestDate = d;
          }
        } catch (e) {
          // Игнорируем ошибки парсинга дат
        }
      }

      // 4. Собираем товары для топа
      productCounts[order.displayName] =
          (productCounts[order.displayName] ?? 0) + order.quantity;
    }

    _totalDebt = _totalSpent - _totalPaid;
    _statusCounts = tempStatusCounts;

    if (latestDate != null) {
      _lastOrderDate = DateFormat('dd.MM.yyyy').format(latestDate);
    }

    // Сортируем товары по убыванию популярности и берем топ-5
    var sortedProducts = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _topProducts = sortedProducts.take(5).toList();

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
        return 'Производство';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.name ?? 'Аналитика клиента'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // БЛОК 1: Инфо о клиенте
          _buildInfoCard(),
          const SizedBox(height: 16),

          // БЛОК 2: Финансы
          _buildFinanceCard(),
          const SizedBox(height: 16),

          // БЛОК 3: Воронка заказов
          _buildFunnelCard(),
          const SizedBox(height: 16),

          // БЛОК 4: Топ товаров
          if (_topProducts.isNotEmpty) _buildTopProductsCard(),
        ],
      ),
    );
  }

  // --- ВИДЖЕТЫ ---

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Информация',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildFinanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Финансы',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildInfoRow('Всего заказов (позиций):',
                '${_statusCounts.values.fold(0, (sum, count) => sum + count)} шт'),
            _buildInfoRow('Всего товаров (шт):', '$_totalItems шт'),
            const SizedBox(height: 8),
            _buildInfoRow('Общая сумма:', '${_totalSpent.toStringAsFixed(2)} ₽',
                valueColor: Colors.blue),
            _buildInfoRow('Оплачено:', '${_totalPaid.toStringAsFixed(2)} ₽',
                valueColor: Colors.green),
            _buildInfoRow(
              'Задолженность:',
              '${_totalDebt.toStringAsFixed(2)} ₽',
              valueColor: _totalDebt > 0 ? Colors.red : Colors.green,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunnelCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Текущая воронка заказов',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 24),

            // Рисуем статусы
            ..._statuses.map((status) {
              final count = _statusCounts[status] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getStatusText(status),
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          // Прогресс бар
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: count > 0
                                  ? 1.0
                                  : 0.0, // Просто закрашиваем, если есть заказы
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _getStatusColor(status).withOpacity(0.7)),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      count.toString(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: count > 0
                              ? _getStatusColor(status)
                              : Colors.grey),
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

  Widget _buildTopProductsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Топ популярных товаров',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            ..._topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Место в рейтинге
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: index == 0 ? Colors.amber : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index == 0 ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Название
                    Expanded(
                        child: Text(product.key,
                            style: const TextStyle(fontSize: 14))),
                    // Количество
                    Text(
                      '${product.value} шт',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple),
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

  // Вспомогательный метод для строк
  Widget _buildInfoRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
