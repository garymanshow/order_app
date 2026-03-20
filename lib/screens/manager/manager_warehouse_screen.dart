// lib/screens/manager/manager_warehouse_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/warehouse_operation.dart';
import '../../services/warehouse_service.dart';

class ManagerWarehouseScreen extends StatefulWidget {
  @override
  _ManagerWarehouseScreenState createState() => _ManagerWarehouseScreenState();
}

class _ManagerWarehouseScreenState extends State<ManagerWarehouseScreen> {
  List<WarehouseOperation> _operations = [];
  Map<String, double> _balances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final warehouseService =
          Provider.of<WarehouseService>(context, listen: false);
      final operations = await warehouseService.getOperations();

      // Рассчитываем остатки
      final balances = <String, double>{};
      for (var op in operations) {
        final key = '${op.name}_${op.unit}';
        if (op.operation.toLowerCase() == 'приход') {
          balances[key] = (balances[key] ?? 0) + op.quantity;
        } else if (op.operation.toLowerCase() == 'списание') {
          balances[key] = (balances[key] ?? 0) - op.quantity;
        }
      }

      setState(() {
        _operations = operations;
        _balances = balances;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки данных склада: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Склад'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory), text: 'Остатки'),
              Tab(icon: Icon(Icons.history), text: 'Операции'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBalancesTab(),
            _buildOperationsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final lowStock = _balances.entries.where((e) => e.value < 1.0).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (lowStock.isNotEmpty) ...[
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[800]),
                      const SizedBox(width: 8),
                      Text(
                        'Мало на складе',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...lowStock.map((e) {
                    final parts = e.key.split('_');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                          '• ${parts[0]}: ${e.value.toStringAsFixed(2)} ${parts[1]}'),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'Все остатки',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._balances.entries.map((e) {
          final parts = e.key.split('_');
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(parts[0]),
              trailing: Text('${e.value.toStringAsFixed(2)} ${parts[1]}'),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOperationsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _operations.length,
      itemBuilder: (context, index) {
        final op = _operations[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              op.operation.toLowerCase() == 'приход'
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: op.operation.toLowerCase() == 'приход'
                  ? Colors.green
                  : Colors.red,
            ),
            title: Text(op.name),
            subtitle: Text(
                '${op.quantity} ${op.unit} • ${op.date.day}.${op.date.month}.${op.date.year}'),
            trailing: Text(
              op.operation,
              style: TextStyle(
                color: op.operation.toLowerCase() == 'приход'
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
