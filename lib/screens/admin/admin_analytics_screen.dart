// lib/screens/admin/admin_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

// Enum для переключения критериев
enum AnalyticsCriteria {
  positions, // Позиций (количество строк)
  pieces, // Штук (сумма quantity)
  money, // Денег (сумма totalPrice)
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

  // Изменили тип Map на double, чтобы точно считать деньги без потери копеек при делении
  Map<String, Map<String, double>> _clientMatrix = {};

  String? _sortColumnStatus;
  bool _sortAsc = true;

  // Текущий выбранный критерий (по умолчанию - Деньги)
  AnalyticsCriteria _selectedCriteria = AnalyticsCriteria.money;

  @override
  void initState() {
    super.initState();
    _buildMatrix();
  }

  void _buildMatrix() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];
    final Map<String, Map<String, double>> tempMatrix = {};

    for (var order in allOrders) {
      if (!_statuses.contains(order.status)) continue;
      final key = '${order.clientPhone}-${order.clientName}';

      if (!tempMatrix.containsKey(key)) {
        tempMatrix[key] = {
          'оформлен': 0.0,
          'производство': 0.0,
          'готов': 0.0,
          'доставлен': 0.0,
          'оплачен': 0.0,
        };
      }

      // Выбираем, что именно складываем
      double valueToAdd = 0.0;
      switch (_selectedCriteria) {
        case AnalyticsCriteria.positions:
          valueToAdd = 1; // Считаем каждую строку за 1
          break;
        case AnalyticsCriteria.pieces:
          valueToAdd = order.quantity.toDouble(); // Считаем штуки
          break;
        case AnalyticsCriteria.money:
          valueToAdd = order.totalPrice; // Считаем рубли
          break;
      }

      tempMatrix[key]![order.status] =
          (tempMatrix[key]![order.status] ?? 0.0) + valueToAdd;
    }

    setState(() {
      _clientMatrix = tempMatrix;
    });
  }

  // Форматирование числа для вывода на экран
  String _formatValue(double value) {
    if (value == 0) return '-';

    switch (_selectedCriteria) {
      case AnalyticsCriteria.money:
        // Для денег показываем без копеек (округляем) и с пробелом между тысячами
        return '${value.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} ₽';
      case AnalyticsCriteria.pieces:
        return '${value.round()} шт';
      case AnalyticsCriteria.positions:
        return '${value.round()} поз';
    }
  }

  // Названия для переключателя
  String get _criteriaTitle {
    switch (_selectedCriteria) {
      case AnalyticsCriteria.money:
        return 'По деньгам';
      case AnalyticsCriteria.pieces:
        return 'По штукам';
      case AnalyticsCriteria.positions:
        return 'По позициям';
    }
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
        return 'Производ-во';
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

  List<String> get _sortedClientKeys {
    var keys = _clientMatrix.keys.toList();

    keys = keys.where((key) {
      final row = _clientMatrix[key]!;
      return _statuses.any((status) => (row[status] ?? 0.0) > 0);
    }).toList();

    if (_sortColumnStatus != null) {
      keys.sort((a, b) {
        final valA = _clientMatrix[a]![_sortColumnStatus] ?? 0.0;
        final valB = _clientMatrix[b]![_sortColumnStatus] ?? 0.0;
        if (valA == valB) return a.split('-').last.compareTo(b.split('-').last);
        return _sortAsc ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    } else {
      keys.sort((a, b) => a.split('-').last.compareTo(b.split('-').last));
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final clientKeys = _sortedClientKeys;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика (Воронка)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // КНОПКА ПЕРЕКЛЮЧЕНИЯ КРИТЕРИЕВ
          PopupMenuButton<AnalyticsCriteria>(
            icon: const Icon(Icons.tune, color: Colors.white),
            tooltip: 'Критерий подсчета',
            onSelected: (AnalyticsCriteria value) {
              setState(() {
                _selectedCriteria = value;
              });
              _buildMatrix(); // Пересчитываем таблицу
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<AnalyticsCriteria>>[
              PopupMenuItem<AnalyticsCriteria>(
                value: AnalyticsCriteria.money,
                child: Row(
                  children: [
                    Icon(Icons.monetization_on,
                        color: _selectedCriteria == AnalyticsCriteria.money
                            ? Colors.green
                            : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('По деньгам'),
                  ],
                ),
              ),
              PopupMenuItem<AnalyticsCriteria>(
                value: AnalyticsCriteria.pieces,
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        color: _selectedCriteria == AnalyticsCriteria.pieces
                            ? Colors.blue
                            : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('По штукам'),
                  ],
                ),
              ),
              PopupMenuItem<AnalyticsCriteria>(
                value: AnalyticsCriteria.positions,
                child: Row(
                  children: [
                    Icon(Icons.format_list_numbered,
                        color: _selectedCriteria == AnalyticsCriteria.positions
                            ? Colors.orange
                            : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('По позициям'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: clientKeys.isEmpty
          ? const Center(child: Text('Нет данных для аналитики'))
          : Column(
              children: [
                // Легенда + текущий критерий
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 16,
                          children: _buildLegend(),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _criteriaTitle,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      )
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
                      const SizedBox(
                          width: 120,
                          child: Text('Клиент',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      ..._buildHeaderColumns(),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Строки таблицы
                Expanded(
                  child: ListView.builder(
                    itemCount: clientKeys.length,
                    itemBuilder: (context, index) {
                      final key = clientKeys[index];
                      final row = _clientMatrix[key]!;
                      final clientName = key.split('-').last;

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
                              width: 120,
                              child: Text(
                                clientName,
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
    final List<Widget> widgets = [];
    for (final s in _statuses) {
      widgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: _getColor(s), size: 10),
            const SizedBox(width: 4),
            Text(_getTitle(s),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildHeaderColumns() {
    final List<Widget> columns = [];
    for (final status in _statuses) {
      final isSorted = _sortColumnStatus == status;
      final icon = isSorted
          ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.arrow_upward;
      final color = isSorted ? _getColor(status) : Colors.black54;

      columns.add(
        Expanded(
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
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return columns;
  }

  List<Widget> _buildStatusCells(Map<String, double> row) {
    final List<Widget> cells = [];
    for (final status in _statuses) {
      final count = row[status] ?? 0.0;

      // Если выбраны деньги, чуть уменьшаем шрифт, чтобы влезли суммы
      final isMoney = _selectedCriteria == AnalyticsCriteria.money;

      cells.add(
        Expanded(
          child: Center(
            child: Text(
              _formatValue(count),
              style: TextStyle(
                fontSize: isMoney ? 11 : 14,
                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                color: count > 0 ? _getColor(status) : Colors.grey[400],
              ),
            ),
          ),
        ),
      );
    }
    return cells;
  }
}
