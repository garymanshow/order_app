// lib/screens/admin/admin_clients_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'admin_client_analytics_screen.dart';

// Enum для переключения периодов
enum AnalyticsPeriod {
  week,
  month,
  quarter,
  year,
  allTime,
}

class AdminClientsAnalyticsScreen extends StatefulWidget {
  const AdminClientsAnalyticsScreen({super.key});

  @override
  State<AdminClientsAnalyticsScreen> createState() =>
      _AdminClientsAnalyticsScreenState();
}

class _AdminClientsAnalyticsScreenState
    extends State<AdminClientsAnalyticsScreen> {
  final List<String> _statuses = const [
    'оформлен',
    'производство',
    'готов',
    'доставлен',
    'оплачен',
  ];

  // Данные для таблицы: { 'Телефон-Имя': { 'оформлен': 2, 'производство': 5 ... } }
  Map<String, Map<String, int>> _clientMatrix = {};

  String? _sortColumnStatus;
  bool _sortAsc = true;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.month;

  @override
  void initState() {
    super.initState();
    _buildMatrix();
  }

  // Вычисление начала периода в зависимости от выбора
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
        return DateTime(2000); // Давно :)
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
        return 'Вся деятельность';
    }
  }

  void _buildMatrix() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];
    final startDate = _getStartDate();

    final Map<String, Map<String, int>> tempMatrix = {};

    for (var order in allOrders) {
      if (!_statuses.contains(order.status)) continue;

      // ФИЛЬТРАЦИЯ ПО ДАТЕ
      if (order.date.isNotEmpty) {
        try {
          final orderDate = DateTime.parse(order.date);
          if (orderDate.isBefore(startDate)) continue;
        } catch (e) {
          continue; // Если дата битая — пропускаем
        }
      }

      final key = '${order.clientPhone}-${order.clientName}';

      if (!tempMatrix.containsKey(key)) {
        tempMatrix[key] = {
          'оформлен': 0,
          'производство': 0,
          'готов': 0,
          'доставлен': 0,
          'оплачен': 0,
        };
      }

      // Считаем количество заказов (позиций) клиента в этом статусе
      tempMatrix[key]![order.status] =
          (tempMatrix[key]![order.status] ?? 0) + 1;
    }

    setState(() {
      _clientMatrix = tempMatrix;
    });
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

    // Фильтруем пустых (у кого нули по всем статусам за период)
    keys = keys.where((key) {
      final row = _clientMatrix[key]!;
      return _statuses.any((status) => (row[status] ?? 0) > 0);
    }).toList();

    // Сортировка
    if (_sortColumnStatus != null) {
      keys.sort((a, b) {
        final valA = _clientMatrix[a]![_sortColumnStatus] ?? 0;
        final valB = _clientMatrix[b]![_sortColumnStatus] ?? 0;
        if (valA == valB) return a.split('-').last.compareTo(b.split('-').last);
        return _sortAsc ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    } else {
      // По умолчанию сортировка по имени
      keys.sort((a, b) => a.split('-').last.compareTo(b.split('-').last));
    }

    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final clientKeys = _sortedClientKeys;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Аналитика клиентов'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // КНОПКА ПЕРЕКЛЮЧЕНИЯ ПЕРИОДА
            PopupMenuButton<AnalyticsPeriod>(
              icon: const Icon(Icons.date_range, color: Colors.white),
              tooltip: 'Период',
              onSelected: (AnalyticsPeriod value) {
                setState(() {
                  _selectedPeriod = value;
                });
                _buildMatrix(); // Пересчитываем с новым периодом
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<AnalyticsPeriod>>[
                _buildPeriodItem(AnalyticsPeriod.week, Icons.today),
                _buildPeriodItem(
                    AnalyticsPeriod.month, Icons.calendar_view_month),
                _buildPeriodItem(
                    AnalyticsPeriod.quarter, Icons.calendar_view_week),
                _buildPeriodItem(AnalyticsPeriod.year, Icons.calendar_today),
                const PopupMenuDivider(),
                _buildPeriodItem(AnalyticsPeriod.allTime, Icons.all_inclusive),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Плашка с текущим периодом
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey[100],
              child: Text(
                'Период: $_periodTitle',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ),

            // Заголовки таблицы
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              child: clientKeys.isEmpty
                  ? const Center(child: Text('Нет данных за выбранный период'))
                  : ListView.builder(
                      itemCount: clientKeys.length,
                      itemBuilder: (context, index) {
                        final key = clientKeys[index];
                        final row = _clientMatrix[key]!;
                        final clientName = key.split('-').last;
                        final clientPhone = key.split('-').first;

                        return InkWell(
                          // КЛИК ПО СТРОКЕ -> ПЕРЕХОД В АНАЛИТИКУ КОНКРЕТНОГО КЛИЕНТА
                          onTap: () {
                            // Ищем модель клиента по телефону для передачи в экран
                            final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false);
                            final clientModel =
                                authProvider.clientData?.clients.firstWhere(
                              (c) => c.phone == clientPhone,
                              orElse: () => throw Exception(
                                  'Клиент не найден в справочнике'),
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminClientAnalyticsScreen(
                                    client: clientModel!),
                              ),
                            );
                          },
                          child: Container(
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                ..._buildStatusCells(row),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ));
  }

  // Вспомогательный метод для пунктов меню периода
  PopupMenuItem<AnalyticsPeriod> _buildPeriodItem(
      AnalyticsPeriod period, IconData icon) {
    final isSelected = _selectedPeriod == period;
    return PopupMenuItem<AnalyticsPeriod>(
      value: period,
      child: Row(
        children: [
          Icon(icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              size: 20),
          const SizedBox(width: 10),
          Text(
            _getPeriodTitle(period),
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color:
                  isSelected ? Theme.of(context).primaryColor : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodTitle(AnalyticsPeriod period) {
    switch (period) {
      case AnalyticsPeriod.week:
        return 'Неделя';
      case AnalyticsPeriod.month:
        return 'Месяц';
      case AnalyticsPeriod.quarter:
        return 'Квартал';
      case AnalyticsPeriod.year:
        return 'Год';
      case AnalyticsPeriod.allTime:
        return 'Вся деятельность';
    }
  }

  List<Widget> _buildHeaderColumns() {
    final List<Widget> columns = [];
    for (final status in _statuses) {
      final isSorted = _sortColumnStatus == status;
      final icon = isSorted
          ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.arrow_upward;
      final color = isSorted ? _getStatusColor(status) : Colors.black54;

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
                    _getStatusText(status),
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

  List<Widget> _buildStatusCells(Map<String, int> row) {
    final List<Widget> cells = [];
    for (final status in _statuses) {
      final count = row[status] ?? 0;

      cells.add(
        Expanded(
          child: Center(
            child: Text(
              count > 0 ? count.toString() : '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                color: count > 0 ? _getStatusColor(status) : Colors.grey[400],
              ),
            ),
          ),
        ),
      );
    }
    return cells;
  }
}
