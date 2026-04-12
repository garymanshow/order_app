// lib/screens/admin/admin_order_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

// 🔥 РАЗРЕЗ: Как группируем данные
enum AnalyticsGroupBy {
  clients,
  products,
}

// 🔥 МЕТРИКА: В чем измеряем
enum AnalyticsMetric {
  money, // Деньги (₽)
  pieces, // Штуки
}

// Периоды
enum AnalyticsPeriod {
  week,
  month,
  quarter,
  year,
  allTime,
}

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final List<String> _statuses = const [
    'оформлен',
    'производство',
    'готов',
    'доставлен',
    'оплачен',
  ];

  Map<String, Map<String, double>> _matrix = {};

  String? _sortColumnStatus;
  bool _sortAsc = true;

  AnalyticsGroupBy _groupBy = AnalyticsGroupBy.clients; // По умолчанию клиенты
  AnalyticsMetric _metric = AnalyticsMetric.money; // По умолчанию деньги
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.month;

  @override
  void initState() {
    super.initState();
    _buildMatrix();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case AnalyticsPeriod.week:
        return now.subtract(const Duration(days: 7));
      case AnalyticsPeriod.month:
        return DateTime(now.year, now.month - 1, now.day);
      case AnalyticsPeriod.quarter:
        return DateTime(now.year, now.month - 3, now.day);
      case AnalyticsPeriod.year:
        return DateTime(now.year - 1, now.month, now.day);
      case AnalyticsPeriod.allTime:
        return DateTime(2000);
    }
  }

  String get _periodTitle {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.week:
        return 'Неделя';
      case AnalyticsPeriod.month:
        return 'Месяц';
      case AnalyticsPeriod.quarter:
        return 'Квартал';
      case AnalyticsPeriod.year:
        return 'Год';
      case AnalyticsPeriod.allTime:
        return 'Всё время';
    }
  }

  void _buildMatrix() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];
    final startDate = _getStartDate();

    final Map<String, Map<String, double>> tempMatrix = {};

    for (var order in allOrders) {
      if (!_statuses.contains(order.status)) continue;

      // Фильтрация по дате
      if (order.date.isNotEmpty) {
        try {
          final orderDate = DateTime.parse(order.date);
          if (orderDate.isBefore(startDate)) continue;
        } catch (e) {
          continue;
        }
      }

      // Определяем ключ группировки
      final String key = _groupBy == AnalyticsGroupBy.products
          ? order.displayName
          : '${order.clientPhone}-${order.clientName}';

      if (!tempMatrix.containsKey(key)) {
        tempMatrix[key] = {for (var s in _statuses) s: 0.0};
      }

      // Считаем метрику
      final double valueToAdd = _metric == AnalyticsMetric.money
          ? order.totalPrice
          : order.quantity.toDouble();

      tempMatrix[key]![order.status] =
          (tempMatrix[key]![order.status] ?? 0.0) + valueToAdd;
    }

    setState(() {
      _matrix = tempMatrix;
    });
  }

  String _formatValue(double value) {
    if (value == 0) return '-';
    if (_metric == AnalyticsMetric.money) {
      // Форматируем деньги: 1 250 000 ₽
      return '${value.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} ₽';
    } else {
      return '${value.round()} шт';
    }
  }

  String get _firstColumnTitle {
    return _groupBy == AnalyticsGroupBy.products ? 'Товар' : 'Клиент';
  }

  // 🔥 Адаптивная ширина первой колонки: товарам меньше, клиентам больше
  double get _firstColumnWidth {
    return _groupBy == AnalyticsGroupBy.products ? 110.0 : 130.0;
  }

  Color _getColor(String status) {
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

  String _getTitle(String status) {
    switch (status) {
      case 'оформлен':
        return 'Оформлен';
      case 'производство':
        return 'Произ-во';
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

  void _toggleSort(String status) {
    setState(() {
      if (_sortColumnStatus == status) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumnStatus = status;
        _sortAsc = true;
      }
    });
  }

  List<String> get _sortedKeys {
    var keys = _matrix.keys.toList();
    keys = keys.where((key) {
      final row = _matrix[key]!;
      return _statuses.any((status) => (row[status] ?? 0.0) > 0);
    }).toList();

    if (_sortColumnStatus != null) {
      keys.sort((a, b) {
        final valA = _matrix[a]![_sortColumnStatus] ?? 0.0;
        final valB = _matrix[b]![_sortColumnStatus] ?? 0.0;
        if (valA == valB) return a.compareTo(b);
        return _sortAsc ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    } else {
      keys.sort((a, b) => a.compareTo(b));
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final rowKeys = _sortedKeys;
    final bool isMoneyMode = _metric == AnalyticsMetric.money;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика (Воронка)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 🔥 ПЕРИОД
          PopupMenuButton<AnalyticsPeriod>(
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: 'Период',
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _buildMatrix();
            },
            itemBuilder: (context) => AnalyticsPeriod.values.map((period) {
              final isSelected = _selectedPeriod == period;
              return PopupMenuItem<AnalyticsPeriod>(
                value: period,
                child: Text(
                  _periodTitle, // Используем геттер
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),

          // 🔥 МЕТРИКА (₽ / шт)
          PopupMenuButton<AnalyticsMetric>(
            icon: Icon(
                isMoneyMode
                    ? Icons.monetization_on
                    : Icons.inventory_2_outlined,
                color: Colors.white),
            tooltip: 'Метрика',
            onSelected: (value) {
              setState(() => _metric = value);
              _buildMatrix();
            },
            itemBuilder: (context) => [
              PopupMenuItem<AnalyticsMetric>(
                value: AnalyticsMetric.money,
                child: Row(children: [
                  Icon(Icons.monetization_on,
                      color: _metric == AnalyticsMetric.money
                          ? Colors.green
                          : Colors.grey),
                  const SizedBox(width: 8),
                  Text('Деньги (₽)',
                      style: TextStyle(
                          fontWeight: _metric == AnalyticsMetric.money
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ]),
              ),
              PopupMenuItem<AnalyticsMetric>(
                value: AnalyticsMetric.pieces,
                child: Row(children: [
                  Icon(Icons.inventory_2_outlined,
                      color: _metric == AnalyticsMetric.pieces
                          ? Colors.blue
                          : Colors.grey),
                  const SizedBox(width: 8),
                  Text('Штуки',
                      style: TextStyle(
                          fontWeight: _metric == AnalyticsMetric.pieces
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ]),
              ),
            ],
          ),

          // 🔥 РАЗРЕЗ (Клиенты / Товары)
          PopupMenuButton<AnalyticsGroupBy>(
            icon: Icon(
                _groupBy == AnalyticsGroupBy.clients
                    ? Icons.people
                    : Icons.category,
                color: Colors.white),
            tooltip: 'Разрез',
            onSelected: (value) {
              setState(() {
                _groupBy = value;
                _sortColumnStatus =
                    null; // Сбрасываем сортировку при смене разреза
              });
              _buildMatrix();
            },
            itemBuilder: (context) => [
              PopupMenuItem<AnalyticsGroupBy>(
                value: AnalyticsGroupBy.clients,
                child: Row(children: [
                  Icon(Icons.people,
                      color: _groupBy == AnalyticsGroupBy.clients
                          ? Colors.deepPurple
                          : Colors.grey),
                  const SizedBox(width: 8),
                  Text('По клиентам',
                      style: TextStyle(
                          fontWeight: _groupBy == AnalyticsGroupBy.clients
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ]),
              ),
              PopupMenuItem<AnalyticsGroupBy>(
                value: AnalyticsGroupBy.products,
                child: Row(children: [
                  Icon(Icons.category,
                      color: _groupBy == AnalyticsGroupBy.products
                          ? Colors.deepPurple
                          : Colors.grey),
                  const SizedBox(width: 8),
                  Text('По продукции',
                      style: TextStyle(
                          fontWeight: _groupBy == AnalyticsGroupBy.products
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: rowKeys.isEmpty
          ? const Center(child: Text('Нет данных для аналитики за период'))
          : Column(
              children: [
                // Информационная плашка
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Expanded(
                          child: Wrap(spacing: 16, children: _buildLegend())),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!)),
                        child: Text('📅 $_periodTitle',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!)),
                        child: Text(
                            _groupBy == AnalyticsGroupBy.clients
                                ? '👥 Клиенты'
                                : '📦 Товары',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple)),
                      ),
                    ],
                  ),
                ),
                // Заголовки таблицы
                Container(
                  color: Colors.grey[200],
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    children: [
                      SizedBox(
                          width: _firstColumnWidth,
                          child: Text(_firstColumnTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      ..._buildHeaderColumns(),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Строки таблицы
                Expanded(
                  child: ListView.builder(
                    itemCount: rowKeys.length,
                    itemBuilder: (context, index) {
                      final key = rowKeys[index];
                      final row = _matrix[key]!;
                      final displayName = _groupBy == AnalyticsGroupBy.products
                          ? key
                          : key.split('-').last;

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: _firstColumnWidth,
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            ..._buildStatusCells(row),
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

  List<Widget> _buildLegend() {
    return _statuses
        .map((s) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: _getColor(s), size: 10),
                const SizedBox(width: 4),
                Text(_getTitle(s),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ))
        .toList();
  }

  List<Widget> _buildHeaderColumns() {
    return _statuses.map((status) {
      final isSorted = _sortColumnStatus == status;
      final icon = isSorted
          ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.unfold_more;
      final color = isSorted ? _getColor(status) : Colors.black54;

      return Expanded(
        child: GestureDetector(
          onTap: () => _toggleSort(status),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  _getTitle(status),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11, color: color),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildStatusCells(Map<String, double> row) {
    return _statuses.map((status) {
      final count = row[status] ?? 0.0;
      final bool isMoneyMode = _metric == AnalyticsMetric.money;

      return Expanded(
        child: Center(
          child: Text(
            _formatValue(count),
            style: TextStyle(
              fontSize: isMoneyMode ? 11 : 14, // Мельче для денег
              fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
              color: count > 0 ? _getColor(status) : Colors.grey[400],
            ),
          ),
        ),
      );
    }).toList();
  }
}
