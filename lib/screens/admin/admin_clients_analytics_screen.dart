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

// 🔥 МОДЕЛЬ ДАННЫХ ДЛЯ СТРОКИ ТАБЛИЦЫ (Только деньги!)
class ClientAnalyticsRow {
  final String phone;
  final String name;
  int oformlen = 0;       // ₽
  int proizvodstvo = 0;   // ₽
  int gotov = 0;          // ₽
  int dostavlen = 0;      // ₽
  int oplachen = 0;       // ₽
  int debt = 0;           // ₽ Задолженность

  ClientAnalyticsRow({required this.phone, required this.name});
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

  final Set<String> _debtStatuses = const {
    'готов',
    'доставлен',
    'оплачен',
  };

  List<ClientAnalyticsRow> _clientRows = [];

  String? _sortColumnKey;
  bool _sortAsc = true;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.month;

  @override
  void initState() {
    super.initState();
    _buildMatrix();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case AnalyticsPeriod.week: return now.subtract(const Duration(days: 7));
      case AnalyticsPeriod.month: return DateTime(now.year, now.month - 1, now.day);
      case AnalyticsPeriod.quarter: return DateTime(now.year, now.month - 3, now.day);
      case AnalyticsPeriod.year: return DateTime(now.year - 1, now.month, now.day);
      case AnalyticsPeriod.allTime: return DateTime(2000);
    }
  }

  int _parsePrice(dynamic value) {
    if (value == null) return 0;
    return (double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0).ceil();
  }

  void _buildMatrix() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];
    final startDate = _getStartDate();

    final Map<String, ClientAnalyticsRow> tempMatrix = {};

    for (var order in allOrders) {
      if (!_statuses.contains(order.status)) continue;

      if (order.date.isNotEmpty) {
        try {
          final orderDate = DateTime.parse(order.date);
          if (orderDate.isBefore(startDate)) continue;
        } catch (e) {
          continue;
        }
      }

      final key = order.clientName;

      if (!tempMatrix.containsKey(key)) {
        tempMatrix[key] = ClientAnalyticsRow(
          phone: order.clientPhone,
          name: order.clientName,
        );
      }

      final row = tempMatrix[key]!;
      
      // 🔥 ВСЕ СЧИТАЕМ ТОЛЬКО В РУБЛЯХ!
      final price = _parsePrice(order.totalPrice);
      final payment = _parsePrice(order.paymentAmount);

      // Добавляем сумму заказа в соответствующий статус
      switch (order.status) {
        case 'оформлен': row.oformlen += price; break;
        case 'производство': row.proizvodstvo += price; break;
        case 'готов': row.gotov += price; break;
        case 'доставлен': row.dostavlen += price; break;
        case 'оплачен': row.oplachen += price; break;
      }

      // Считаем долг
      if (_debtStatuses.contains(order.status) && price > payment) {
        row.debt += (price - payment);
      }
    }

    setState(() {
      _clientRows = tempMatrix.values.toList();
    });
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
      case 'оформлен': return 'Оформл.';
      case 'производство': return 'Произ-во';
      case 'готов': return 'Готов';
      case 'доставлен': return 'Доставл.';
      case 'оплачен': return 'Оплачен';
      default: return status;
    }
  }

  int _getStatusValue(ClientAnalyticsRow row, String status) {
    switch (status) {
      case 'оформлен': return row.oformlen;
      case 'производство': return row.proizvodstvo;
      case 'готов': return row.gotov;
      case 'доставлен': return row.dostavlen;
      case 'оплачен': return row.oplachen;
      default: return 0;
    }
  }

  void _toggleSort(String columnKey) {
    setState(() {
      if (_sortColumnKey == columnKey) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumnKey = columnKey;
        _sortAsc = true;
      }
    });
  }

  List<ClientAnalyticsRow> get _sortedClientRows {
    var rows = _clientRows.where((row) {
      final hasOrders = _statuses.any((status) => _getStatusValue(row, status) > 0);
      return hasOrders || row.debt > 0;
    }).toList();

    if (_sortColumnKey != null) {
      rows.sort((a, b) {
        int compareResult = 0;
        if (_sortColumnKey == 'client') {
          compareResult = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        } else if (_sortColumnKey == 'debt') {
          compareResult = a.debt.compareTo(b.debt);
        } else if (_statuses.contains(_sortColumnKey)) {
          compareResult = _getStatusValue(a, _sortColumnKey!).compareTo(_getStatusValue(b, _sortColumnKey!));
        }

        if (compareResult == 0) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        return _sortAsc ? compareResult : -compareResult;
      });
    } else {
      rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return rows;
  }

  // 🔥 ФОРМАТИРОВАНИЕ ДЕНЕГ (С пробелами между тысячами)
  String _formatRub(int value) {
    if (value == 0) return '-';
    return '${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} ₽';
  }

  @override
  Widget build(BuildContext context) {
    final clientRows = _sortedClientRows;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Аналитика клиентов (₽)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            PopupMenuButton<AnalyticsPeriod>(
              icon: const Icon(Icons.date_range, color: Colors.white),
              tooltip: 'Период',
              onSelected: (AnalyticsPeriod value) {
                setState(() {
                  _selectedPeriod = value;
                });
                _buildMatrix();
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<AnalyticsPeriod>>[
                _buildPeriodItem(AnalyticsPeriod.week, Icons.today),
                _buildPeriodItem(AnalyticsPeriod.month, Icons.calendar_view_month),
                _buildPeriodItem(AnalyticsPeriod.quarter, Icons.calendar_view_week),
                _buildPeriodItem(AnalyticsPeriod.year, Icons.calendar_today),
                const PopupMenuDivider(),
                _buildPeriodItem(AnalyticsPeriod.allTime, Icons.all_inclusive),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey[100],
              child: Text(
                'Период: $_periodTitle',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  _buildHeaderCell(key: 'client', label: 'Клиент', width: 100, defaultColor: Colors.black87),
                  ..._buildStatusHeaderColumns(),
                  _buildHeaderCell(key: 'debt', label: 'Долг', width: 80, defaultColor: Colors.red[700]!),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: clientRows.isEmpty
                  ? const Center(child: Text('Нет данных за выбранный период'))
                  : ListView.builder(
                      itemCount: clientRows.length,
                      itemBuilder: (context, index) {
                        final row = clientRows[index];
                        return InkWell(
                          onTap: () {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final clientModel = authProvider.clientData?.clients.firstWhere(
                              (c) => c.name == row.name,
                              orElse: () => throw Exception('Клиент не найден в справочнике'),
                            );
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AdminClientAnalyticsScreen(client: clientModel!)));
                          },
                          child: Container(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Text(row.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 2),
                                ),
                                ..._buildStatusCells(row),
                                SizedBox(
                                  width: 80,
                                  child: Center(
                                    child: Text(
                                      _formatRub(row.debt), // 🔥 Форматируем как деньги
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: row.debt > 0 ? FontWeight.bold : FontWeight.normal,
                                        color: row.debt > 0 ? Colors.red : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
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

  Widget _buildHeaderCell({required String key, required String label, required double width, required Color defaultColor}) {
    final isSorted = _sortColumnKey == key;
    final icon = isSorted ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more;
    final color = isSorted ? defaultColor : Colors.black54;

    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: () => _toggleSort(key),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 2),
            Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<AnalyticsPeriod> _buildPeriodItem(AnalyticsPeriod period, IconData icon) {
    final isSelected = _selectedPeriod == period;
    return PopupMenuItem<AnalyticsPeriod>(
      value: period,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey, size: 20),
          const SizedBox(width: 10),
          Text(
            _getPeriodName(period), // 🔥 ИСПРАВЛЕНО: берем название конкретного периода, а не текущего выбранного
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Вспомогательный метод для получения названия периода по его Enum
  String _getPeriodName(AnalyticsPeriod period) {
    switch (period) {
      case AnalyticsPeriod.week: return 'Неделя';
      case AnalyticsPeriod.month: return 'Месяц';
      case AnalyticsPeriod.quarter: return 'Квартал';
      case AnalyticsPeriod.year: return 'Год';
      case AnalyticsPeriod.allTime: return 'Вся деятельность';
    }
  }

  // Оставляем геттер для плашки вверху экрана
  String get _periodTitle {
    return _getPeriodName(_selectedPeriod);
  }

  List<Widget> _buildStatusHeaderColumns() {
    return _statuses.map((status) {
      return Expanded(
        child: GestureDetector(
          onTap: () => _toggleSort(status),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_sortColumnKey == status ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 14, color: _sortColumnKey == status ? _getStatusColor(status) : Colors.black54),
              const SizedBox(width: 2),
              Flexible(child: Text(_getStatusText(status), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _sortColumnKey == status ? _getStatusColor(status) : Colors.black54), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildStatusCells(ClientAnalyticsRow row) {
    return _statuses.map((status) {
      final value = _getStatusValue(row, status);
      return Expanded(
        child: Center(
          child: Text(
            _formatRub(value), // 🔥 Выводим рубли
            style: TextStyle(
              fontSize: 11, // Мельче, чтобы влезали тысячи
              fontWeight: value > 0 ? FontWeight.bold : FontWeight.normal,
              color: value > 0 ? _getStatusColor(status) : Colors.grey[400],
            ),
          ),
        ),
      );
    }).toList();
  }
}
