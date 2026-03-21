// lib/screens/admin/admin_warehouse_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../services/sync_service.dart';
import '../../models/warehouse_operation.dart';
import '../../models/employee.dart';
import '../../models/product.dart';

class AdminWarehouseScreen extends StatefulWidget {
  @override
  _AdminWarehouseScreenState createState() => _AdminWarehouseScreenState();
}

class _AdminWarehouseScreenState extends State<AdminWarehouseScreen> {
  final ApiService _apiService = ApiService();
  late CacheService _cacheService;
  late SyncService _syncService;

  List<WarehouseOperation> _operations = [];
  List<Product> _products = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'income', 'expense'
  String _searchQuery = '';

  // Для автодополнения
  List<String> _productNames = [];

  // Состояние для формы добавления
  bool _showAddForm = false;
  bool _isEditing = false;
  String? _editingId;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _priceController;
  late TextEditingController _supplierController;
  late TextEditingController _notesController;
  String _selectedOperation = 'приход';
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedExpiryDate;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initServices();
    _loadData();
  }

  Future<void> _initServices() async {
    _cacheService = await CacheService.getInstance();
    _syncService = SyncService();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _quantityController = TextEditingController();
    _unitController = TextEditingController(text: 'кг');
    _priceController = TextEditingController();
    _supplierController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Загружаем продукты для автодополнения
      _products = authProvider.clientData?.products ?? [];
      _productNames = _products.map((p) => p.name).toList();

      // 🔥 ЗАГРУЖАЕМ РЕАЛЬНЫЕ ОПЕРАЦИИ СКЛАДА ИЗ КЭША
      _operations = _cacheService.getWarehouseOperations();

      // Если кэш пуст, пробуем загрузить с сервера
      if (_operations.isEmpty) {
        await _loadFromServer();
      }
    } catch (e) {
      print('❌ Ошибка загрузки данных склада: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFromServer() async {
    try {
      final result = await _apiService.fetchWarehouseOperations();
      if (result != null && result['success'] == true) {
        final operationsData = result['operations'] as List?;
        if (operationsData != null) {
          _operations = operationsData
              .map((json) => WarehouseOperation.fromJson(json))
              .toList();

          // Сохраняем в кэш
          await _cacheService.saveWarehouseOperations(_operations);
        }
      }
    } catch (e) {
      print('⚠️ Ошибка загрузки с сервера: $e');
    }
  }

  // 👇 РАСЧЕТ ОСТАТКОВ
  Map<String, double> _calculateRemains() {
    final remains = <String, double>{};

    for (var op in _operations) {
      if (op.operation == 'приход') {
        remains[op.name] = (remains[op.name] ?? 0) + op.quantity;
      } else {
        remains[op.name] = (remains[op.name] ?? 0) - op.quantity;
      }
    }

    return remains;
  }

  List<WarehouseOperation> _getFilteredOperations() {
    var filtered = _operations;

    if (_selectedFilter == 'income') {
      filtered = filtered.where((op) => op.operation == 'приход').toList();
    } else if (_selectedFilter == 'expense') {
      filtered = filtered.where((op) => op.operation == 'списание').toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((op) {
        return op.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  double _getTotalIncome() {
    return _operations
        .where((op) => op.operation == 'приход')
        .fold(0.0, (sum, op) => sum + (op.price ?? 0) * op.quantity);
  }

  double _getTotalExpense() {
    return _operations
        .where((op) => op.operation == 'списание')
        .fold(0.0, (sum, op) => sum + op.quantity);
  }

  // 👇 РЕДАКТИРОВАНИЕ ОПЕРАЦИИ
  void _editOperation(WarehouseOperation operation) {
    _isEditing = true;
    _editingId = operation.id;
    _nameController.text = operation.name;
    _quantityController.text = operation.quantity.toString();
    _unitController.text = operation.unit;
    _selectedDate = operation.date;
    _selectedExpiryDate = operation.expiryDate;
    _selectedOperation = operation.operation;

    if (operation.operation == 'приход') {
      _priceController.text = operation.price?.toString() ?? '';
      _supplierController.text = operation.supplier ?? '';
    }
    _notesController.text = operation.notes ?? '';

    setState(() {
      _showAddForm = true;
    });
  }

  // 👇 УДАЛЕНИЕ ОПЕРАЦИИ
  Future<void> _deleteOperation(WarehouseOperation operation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить операцию?'),
        content: Text(
            'Вы уверены, что хотите удалить операцию "${operation.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _operations.removeWhere((op) => op.id == operation.id);
    });

    // 🔥 УДАЛЕНИЕ ЧЕРЕЗ API
    try {
      final result = await _apiService.deleteWarehouseOperation(operation.id);
      if (result) {
        // Обновляем кэш
        await _cacheService.saveWarehouseOperations(_operations);
        _showSnackBar('Операция удалена', Colors.green);
      } else {
        // Если API не отвечает, добавляем в очередь
        await _cacheService.addPendingOperation(
          type: 'delete',
          entity: 'warehouse_operation',
          data: {'id': operation.id},
        );
        _showSnackBar(
            'Операция добавлена в очередь на удаление', Colors.orange);
      }
    } catch (e) {
      // Офлайн-режим: добавляем в очередь
      await _cacheService.addPendingOperation(
        type: 'delete',
        entity: 'warehouse_operation',
        data: {'id': operation.id},
      );
      _showSnackBar(
          'Операция добавлена в очередь (офлайн-режим)', Colors.orange);
    }
  }

  Future<void> _saveOperation() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser as Employee?;

      if (user == null || user.phone == null) {
        _showSnackBar('Ошибка авторизации', Colors.red);
        return;
      }

      final operation = WarehouseOperation(
        id: _isEditing
            ? _editingId!
            : DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        operation: _selectedOperation,
        quantity: double.parse(_quantityController.text),
        unit: _unitController.text.trim(),
        date: _selectedDate,
        expiryDate: _selectedExpiryDate,
        price: _selectedOperation == 'приход'
            ? double.tryParse(_priceController.text)
            : null,
        supplier: _selectedOperation == 'приход'
            ? _supplierController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (_isEditing) {
        // 🔥 ОБНОВЛЕНИЕ ЧЕРЕЗ API
        final index = _operations.indexWhere((op) => op.id == _editingId);
        if (index != -1) {
          setState(() {
            _operations[index] = operation;
          });

          try {
            final result =
                await _apiService.updateWarehouseOperation(operation);
            if (result) {
              await _cacheService.saveWarehouseOperations(_operations);
              _showSnackBar('Операция обновлена', Colors.green);
            } else {
              await _cacheService.addPendingOperation(
                type: 'update',
                entity: 'warehouse_operation',
                data: operation.toJson(),
              );
              _showSnackBar('Операция добавлена в очередь', Colors.orange);
            }
          } catch (e) {
            await _cacheService.addPendingOperation(
              type: 'update',
              entity: 'warehouse_operation',
              data: operation.toJson(),
            );
            _showSnackBar(
                'Операция добавлена в очередь (офлайн-режим)', Colors.orange);
          }
        }
      } else {
        // 🔥 СОЗДАНИЕ НОВОЙ ОПЕРАЦИИ
        setState(() {
          _operations.insert(0, operation);
        });

        try {
          final result = await _apiService.addWarehouseOperation(
            phone: user.phone!,
            operationData: operation.toMap(),
          );

          if (result) {
            await _cacheService.saveWarehouseOperations(_operations);
            _showSnackBar('Операция сохранена', Colors.green);
          } else {
            await _cacheService.addPendingOperation(
              type: 'create',
              entity: 'warehouse_operation',
              data: operation.toJson(),
            );
            _showSnackBar('Операция добавлена в очередь', Colors.orange);
          }
        } catch (e) {
          // Офлайн-режим: сохраняем в очередь
          await _cacheService.addPendingOperation(
            type: 'create',
            entity: 'warehouse_operation',
            data: operation.toJson(),
          );
          _showSnackBar(
              'Операция добавлена в очередь (офлайн-режим)', Colors.orange);
        }
      }

      setState(() {
        _showAddForm = false;
        _isEditing = false;
        _editingId = null;
        _clearForm();
      });
    } catch (e) {
      print('❌ Ошибка сохранения: $e');
      _showSnackBar('Ошибка сохранения: $e', Colors.red);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _quantityController.clear();
    _unitController.text = 'кг';
    _priceController.clear();
    _supplierController.clear();
    _notesController.clear();
    _selectedDate = DateTime.now();
    _selectedExpiryDate = null;
    _isEditing = false;
    _editingId = null;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredOperations = _getFilteredOperations();
    final totalIncome = _getTotalIncome();
    final totalExpense = _getTotalExpense();
    final remains = _calculateRemains();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Склад'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await _syncService.sync();
              await _loadData();
            },
            tooltip: 'Синхронизировать',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Статистика
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    const Icon(Icons.trending_up,
                                        color: Colors.green),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${totalIncome.toStringAsFixed(0)} ₽',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const Text(
                                      'Приход',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    const Icon(Icons.trending_down,
                                        color: Colors.red),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${totalExpense.toStringAsFixed(1)} кг',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const Text(
                                      'Расход',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (remains.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: remains.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(
                                  label:
                                      Text('${entry.key}: ${entry.value} кг'),
                                  backgroundColor: Colors.blue.shade50,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Фильтры
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterChip('Все', 'all'),
                          ),
                          Expanded(
                            child: _buildFilterChip('Приход', 'income'),
                          ),
                          Expanded(
                            child: _buildFilterChip('Расход', 'expense'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Список операций
                Expanded(
                  child: filteredOperations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Нет операций',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showAddForm = true;
                                    _isEditing = false;
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Добавить операцию'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: filteredOperations.length,
                          itemBuilder: (context, index) {
                            final operation = filteredOperations[index];
                            return _buildOperationCard(operation);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _showAddForm = true;
            _isEditing = false;
            _clearForm();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Операция'),
      ),

      // Форма добавления/редактирования (остаётся без изменений)
      bottomSheet: _showAddForm
          ? Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing
                            ? 'Редактировать операцию'
                            : 'Новая операция',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _showAddForm = false;
                            _isEditing = false;
                            _clearForm();
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          // Тип операции
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'приход',
                                label: Text('Приход'),
                                icon: Icon(Icons.add_circle),
                              ),
                              ButtonSegment(
                                value: 'списание',
                                label: Text('Списание'),
                                icon: Icon(Icons.remove_circle),
                              ),
                            ],
                            selected: {_selectedOperation},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _selectedOperation = newSelection.first;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Наименование с автодополнением
                          Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return _productNames.where((name) => name
                                  .toLowerCase()
                                  .contains(
                                      textEditingValue.text.toLowerCase()));
                            },
                            fieldViewBuilder: (context, controller, focusNode,
                                onFieldSubmitted) {
                              return TextFormField(
                                controller: _nameController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Наименование *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Обязательное поле';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => onFieldSubmitted(),
                              );
                            },
                            onSelected: (selection) {
                              _nameController.text = selection;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Количество и единица
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _quantityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Количество *',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Обязательное поле';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Неверный формат';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _unitController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ед. изм.',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Дата
                          ListTile(
                            title: const Text('Дата операции'),
                            subtitle: Text(
                              DateFormat('dd.MM.yyyy').format(_selectedDate),
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => _selectDate(context),
                          ),
                          const SizedBox(height: 8),

                          // Для прихода
                          if (_selectedOperation == 'приход') ...[
                            // Срок годности
                            ListTile(
                              title: const Text('Срок годности (опционально)'),
                              subtitle: Text(
                                _selectedExpiryDate != null
                                    ? DateFormat('dd.MM.yyyy')
                                        .format(_selectedExpiryDate!)
                                    : 'Не указан',
                              ),
                              trailing: const Icon(Icons.date_range),
                              onTap: () => _selectExpiryDate(context),
                            ),
                            const SizedBox(height: 8),

                            // Цена
                            TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Цена (опционально)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),

                            // Поставщик
                            TextFormField(
                              controller: _supplierController,
                              decoration: const InputDecoration(
                                labelText: 'Поставщик (опционально)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Примечания
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Примечания',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 24),

                          // Кнопки
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAddForm = false;
                                      _isEditing = false;
                                      _clearForm();
                                    });
                                  },
                                  child: const Text('Отмена'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveOperation,
                                  child: Text(
                                      _isEditing ? 'Обновить' : 'Сохранить'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildOperationCard(WarehouseOperation operation) {
    final isIncome = operation.operation == 'приход';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isIncome
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isIncome ? Icons.add_circle : Icons.remove_circle,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        operation.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${operation.quantity} ${operation.unit}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isIncome && operation.price != null)
                  Text(
                    '${(operation.price! * operation.quantity).toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                // Кнопки действий
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editOperation(operation);
                    } else if (value == 'delete') {
                      _deleteOperation(operation);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, color: Colors.blue),
                        title: Text('Редактировать'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildInfoChip(
                  icon: Icons.calendar_today,
                  label: DateFormat('dd.MM.yyyy').format(operation.date),
                ),
                if (isIncome && operation.expiryDate != null)
                  _buildInfoChip(
                    icon: Icons.update,
                    label:
                        'до ${DateFormat('dd.MM.yyyy').format(operation.expiryDate!)}',
                    color: operation.expiryDate!.isBefore(DateTime.now())
                        ? Colors.red
                        : null,
                  ),
                if (isIncome && operation.supplier != null)
                  _buildInfoChip(
                    icon: Icons.business,
                    label: operation.supplier!,
                  ),
                if (!isIncome && operation.relatedOrderId != null)
                  _buildInfoChip(
                    icon: Icons.shopping_cart,
                    label: 'Заказ ${operation.relatedOrderId}',
                  ),
                if (operation.notes != null && operation.notes!.isNotEmpty)
                  _buildInfoChip(
                    icon: Icons.note,
                    label: operation.notes!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color ?? Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color ?? Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
