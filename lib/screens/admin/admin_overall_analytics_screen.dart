// lib/screens/admin/admin_overall_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

class AdminOverallAnalyticsScreen extends StatefulWidget {
  const AdminOverallAnalyticsScreen({super.key});

  @override
  State<AdminOverallAnalyticsScreen> createState() =>
      _AdminOverallAnalyticsScreenState();
}

class _AdminOverallAnalyticsScreenState
    extends State<AdminOverallAnalyticsScreen> {
  final List<String> _statuses = const [
    'оформлен',
    'производство',
    'готов',
    'доставлен',
    'оплачен',
  ];

  final Set<String> _debtStatuses = const {
    'готов',
    'доставлен',
    'оплачен',
  };

  Map<String, int> _statusCounts = {};
  int _totalRevenue = 0;
  int _totalPaid = 0;
  int _totalDebt = 0;
  int _totalItems = 0;
  List<MapEntry<String, int>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _calculateAnalytics();
  }

  int _parsePrice(dynamic value) {
    if (value == null) return 0;
    return (double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0)
        .ceil();
  }

  void _calculateAnalytics() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orders = authProvider.clientData?.orders ?? [];

    Map<String, int> tempStatusCounts = {};
    Map<String, int> productCounts = {};

    for (var order in orders) {
      // 1. Считаем статусы (по всем заказам)
      if (_statuses.contains(order.status)) {
        tempStatusCounts[order.status] =
            (tempStatusCounts[order.status] ?? 0) + 1;
      }

      // 2. Считаем деньги и штуки (по всем заказам)
      final price = _parsePrice(order.totalPrice);
      final payment = _parsePrice(order.paymentAmount);
      final qty = order.quantity;

      _totalRevenue += price;
      _totalPaid += payment;
      _totalItems += qty;

      // 3. Считаем общий долг
      if (_debtStatuses.contains(order.status)) {
        if (price > payment) {
          _totalDebt += (price - payment);
        }
      }

      // 4. Собираем товары для топа
      if (order.displayName.isNotEmpty) {
        productCounts[order.displayName] =
            (productCounts[order.displayName] ?? 0) + qty;
      }
    }

    _statusCounts = tempStatusCounts;

    // Сортируем товары по убыванию популярности и берем топ-10
    var sortedProducts = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _topProducts = sortedProducts.take(10).toList(); // Топ-10 для общей картины

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
        title: const Text('Аналитика компании'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFinanceCard(),
          const SizedBox(height: 16),
          _buildFunnelCard(),
          const SizedBox(height: 16),
          if (_topProducts.isNotEmpty) _buildTopProductsCard(),
        ],
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
            const Text('Общие финансы',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildInfoRow('Всего позиций в работе:',
                '${_statusCounts.values.fold(0, (sum, count) => sum + count)} шт'),
            _buildInfoRow('Всего товаров (шт):', '$_totalItems шт'),
            const SizedBox(height: 8),
            _buildInfoRow('Общая выручка:', '$_totalRevenue ₽',
                valueColor: Colors.blue),
            _buildInfoRow('Получено оплат:', '$_totalPaid ₽',
                valueColor: Colors.green),
            _buildInfoRow(
              'Общая задолженность:',
              '$_totalDebt ₽',
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
            const Text('Воронка заказов',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: count > 0 ? 1.0 : 0.0,
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
            }),
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
            const Text('Топ-10 популярных товаров',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            ..._topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: index < 3
                            ? Colors.amber
                            : Colors.grey[300], // Топ-3 подсвечиваем золотым
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                              color: index < 3 ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(product.key,
                            style: const TextStyle(fontSize: 14))),
                    Text('${product.value} шт',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: valueColor ?? Colors.black87)),
          ),
        ],
      ),
    );
  }
}
