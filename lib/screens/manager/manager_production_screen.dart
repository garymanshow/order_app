// lib/screens/manager/manager_production_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/production_service.dart';
import '../../models/production_operation.dart';
import '../../widgets/unit_selector.dart';

class ManagerProductionScreen extends StatefulWidget {
  @override
  _ManagerProductionScreenState createState() =>
      _ManagerProductionScreenState();
}

class _ManagerProductionScreenState extends State<ManagerProductionScreen> {
  List<ProductionOperation> _operations = [];
  Map<String, double> _fillingBalances = {};
  Map<String, double> _productBalances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final productionService =
          Provider.of<ProductionService>(context, listen: false);

      final operations = await productionService.getProductionOperations();
      final balances = await productionService.getProductionBalances();

      setState(() {
        _operations = operations;
        _fillingBalances = balances['fillings'] ?? {};
        _productBalances = balances['products'] ?? {};
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки данных производства: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddOperationDialog() async {
    String operationType = 'filling'; // 'filling' или 'product'
    int? selectedFillingId;
    int? selectedProductId;
    double quantity = 0;
    String selectedUnit = 'кг';
    DateTime selectedDate = DateTime.now();

    final fillings = await _getFillings();
    final products = await _getProducts();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Новая операция'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Выбор типа операции
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'filling',
                          label: Text('Начинка'),
                          icon: Icon(Icons.category)),
                      ButtonSegment(
                          value: 'product',
                          label: Text('Продукт'),
                          icon: Icon(Icons.inventory)),
                    ],
                    selected: {operationType},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() => operationType = selection.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  if (operationType == 'filling') ...[
                    // 🔥 ИСПРАВЛЕНО: явное приведение типов
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                          labelText: 'Выберите начинку *'),
                      initialValue: selectedFillingId,
                      items: fillings.map<DropdownMenuItem<int>>((f) {
                        final id = f['id'] ?? f['ID'];
                        return DropdownMenuItem<int>(
                          value: id is int ? id : int.tryParse(id.toString()),
                          child: Text(f['name'] ?? f['Наименование'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => selectedFillingId = value),
                      validator: (value) =>
                          value == null ? 'Обязательное поле' : null,
                    ),
                  ] else ...[
                    // 🔥 ИСПРАВЛЕНО: явное приведение типов
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                          labelText: 'Выберите продукт *'),
                      initialValue: selectedProductId,
                      items: products.map<DropdownMenuItem<int>>((p) {
                        final id = p['id'] ?? p['ID'];
                        return DropdownMenuItem<int>(
                          value: id is int ? id : int.tryParse(id.toString()),
                          child: Text(p['name'] ?? p['Название'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => selectedProductId = value),
                      validator: (value) =>
                          value == null ? 'Обязательное поле' : null,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 🔥 ИСПРАВЛЕНО: убрано value, используется controller
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Количество *'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        quantity = double.tryParse(value) ?? 0,
                  ),

                  const SizedBox(height: 16),

                  // Единица измерения (только для начинок)
                  if (operationType == 'filling')
                    UnitSelector(
                      mode: UnitSelectorMode.weight,
                      selectedUnit: selectedUnit,
                      onUnitSelected: (unit) =>
                          setState(() => selectedUnit = unit!),
                      labelText: 'Единица измерения',
                      isRequired: true,
                    ),

                  const SizedBox(height: 16),

                  // Дата
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2026),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Дата'),
                      child: Text(
                          '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _createOperation(
                    type: operationType,
                    fillingId: selectedFillingId,
                    productId: selectedProductId,
                    quantity: quantity,
                    unit: selectedUnit,
                    date: selectedDate,
                  );
                },
                child: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getFillings() async {
    try {
      final productionService =
          Provider.of<ProductionService>(context, listen: false);
      return await productionService.getFillings();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getProducts() async {
    try {
      final productionService =
          Provider.of<ProductionService>(context, listen: false);
      return await productionService.getProducts();
    } catch (e) {
      return [];
    }
  }

  Future<void> _createOperation({
    required String type,
    int? fillingId,
    int? productId,
    required double quantity,
    required String unit,
    required DateTime date,
  }) async {
    final productionService =
        Provider.of<ProductionService>(context, listen: false);

    bool success = false;

    if (type == 'filling' && fillingId != null) {
      final filling = await _getFillingName(fillingId);
      success = await productionService.produceFilling(
        fillingId: fillingId,
        fillingName: filling,
        quantityKg: quantity,
        date: date,
      );
    } else if (type == 'product' && productId != null) {
      final product = await _getProductName(productId);
      success = await productionService.releaseProduct(
        productId: productId,
        productName: product,
        quantity: quantity.toInt(),
        date: date,
      );
    }

    if (success) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Операция успешно создана'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<String> _getFillingName(int id) async {
    final fillings = await _getFillings();
    final filling = fillings.firstWhere(
      (f) {
        final fid = f['id'] ?? f['ID'];
        return (fid is int ? fid : int.tryParse(fid.toString())) == id;
      },
      orElse: () => {'name': 'Начинка $id', 'Наименование': 'Начинка $id'},
    );
    return filling['name']?.toString() ??
        filling['Наименование']?.toString() ??
        'Начинка $id';
  }

  Future<String> _getProductName(int id) async {
    final products = await _getProducts();
    final product = products.firstWhere(
      (p) {
        final pid = p['id'] ?? p['ID'];
        return (pid is int ? pid : int.tryParse(pid.toString())) == id;
      },
      orElse: () => {'name': 'Продукт $id', 'Название': 'Продукт $id'},
    );
    return product['name']?.toString() ??
        product['Название']?.toString() ??
        'Продукт $id';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Производство'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Остатки'),
              Tab(icon: Icon(Icons.list), text: 'Операции'),
              Tab(icon: Icon(Icons.analytics), text: 'Статистика'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBalancesTab(),
            _buildOperationsTab(),
            _buildStatsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddOperationDialog,
          child: const Icon(Icons.add),
          tooltip: 'Добавить операцию',
        ),
      ),
    );
  }

  Widget _buildBalancesTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Остатки начинок',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._fillingBalances.entries.map((e) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(e.key),
                trailing: Text('${e.value.toStringAsFixed(2)} кг'),
              ),
            )),
        const SizedBox(height: 24),
        const Text(
          'Остатки готовой продукции',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._productBalances.entries.map((e) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(e.key),
                trailing: Text('${e.value.toInt()} шт'),
              ),
            )),
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
              op.isFilling ? Icons.category : Icons.inventory,
              color: op.isFilling ? Colors.blue : Colors.green,
            ),
            title: Text(op.name),
            subtitle: Text(
                '${op.quantity} ${op.unit ?? 'шт'} • ${op.date.day}.${op.date.month}.${op.date.year}'),
            trailing: Text(
              op.isFilling ? 'Начинка' : 'Продукт',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return const Center(
      child: Text('Статистика в разработке'),
    );
  }
}
