// lib/screens/manager/manager_fillings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/filling.dart';
import '../../models/composition.dart';
import '../../services/api_service.dart';
import '../../widgets/unit_selector.dart';
import 'manager_composition_screen.dart';

class ManagerFillingsScreen extends StatefulWidget {
  const ManagerFillingsScreen({Key? key}) : super(key: key);

  @override
  _ManagerFillingsScreenState createState() => _ManagerFillingsScreenState();
}

class _ManagerFillingsScreenState extends State<ManagerFillingsScreen> {
  List<Filling> _fillings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFillings();
  }

  Future<void> _loadFillings() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final fillingsData = await apiService.fetchFillings();

      if (fillingsData != null) {
        final fillings = fillingsData.map((json) {
          // Преобразуем данные из API в модель Filling
          // API может возвращать данные в разных форматах
          return Filling(
            sheetName: json['sheetName'] ?? json['Лист'] ?? 'Начинки',
            entityId: json['entityId']?.toString() ??
                json['ID']?.toString() ??
                json['ID сущности']?.toString() ??
                '',
            name: json['name']?.toString() ??
                json['Наименование']?.toString() ??
                '',
            quantity: double.tryParse(json['quantity']?.toString() ??
                    json['Количество']?.toString() ??
                    '0') ??
                0.0,
            unitSymbol: json['unitSymbol']?.toString() ??
                json['Ед.изм']?.toString() ??
                'г',
            ingredients: [], // будут загружаться отдельно при необходимости
          );
        }).toList();

        setState(() {
          _fillings = fillings;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Ошибка загрузки начинок: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addFilling() async {
    final result = await showDialog<Filling>(
      context: context,
      builder: (_) => FillingFormDialog(
        onSave: (filling) => filling,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        // Генерируем ID для новой начинки если его нет
        final newFilling = Filling(
          sheetName: result.sheetName,
          entityId: result.entityId.isEmpty
              ? DateTime.now().millisecondsSinceEpoch.toString()
              : result.entityId,
          name: result.name,
          quantity: result.quantity,
          unitSymbol: result.unitSymbol,
          ingredients: result.ingredients,
        );

        // Отправляем в API
        await apiService.createFilling(newFilling.toJson());
        await _loadFillings();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Начинка создана'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка создания: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editFilling(Filling filling) async {
    final result = await showDialog<Filling>(
      context: context,
      builder: (_) => FillingFormDialog(
        filling: filling,
        onSave: (filling) => filling,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        // Обновляем начинку
        await apiService.updateFilling(result.toJson());
        await _loadFillings();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Начинка обновлена'),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка обновления: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteFilling(Filling filling) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление начинки'),
        content: Text('Удалить начинку "${filling.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        // Удаляем начинку по entityId
        await apiService.deleteFilling(filling.entityId);
        await _loadFillings();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Начинка удалена'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка удаления: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showComposition(Filling filling) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManagerCompositionScreen(
          sourceSheet: filling.sheetName,
          sourceId: filling.entityId,
          sourceName: filling.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Начинки'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fillings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Нет начинок',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _addFilling,
                        child: const Text('Добавить начинку'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _fillings.length,
                  itemBuilder: (context, index) {
                    final filling = _fillings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(filling.name),
                        subtitle: Text(
                            'Вес порции: ${filling.quantity} ${filling.unitSymbol}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu_book,
                                  color: Colors.green),
                              onPressed: () => _showComposition(filling),
                              tooltip: 'Состав',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editFilling(filling),
                              tooltip: 'Редактировать',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteFilling(filling),
                              tooltip: 'Удалить',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFilling,
        child: const Icon(Icons.add),
        tooltip: 'Добавить начинку',
      ),
    );
  }
}

class FillingFormDialog extends StatefulWidget {
  final Filling? filling;
  final Function(Filling) onSave;

  const FillingFormDialog({
    Key? key,
    this.filling,
    required this.onSave,
  }) : super(key: key);

  @override
  _FillingFormDialogState createState() => _FillingFormDialogState();
}

class _FillingFormDialogState extends State<FillingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _quantity;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _name = widget.filling?.name ?? '';
    _quantity = widget.filling?.quantity ?? 35.0;
    _unit = widget.filling?.unitSymbol ?? 'г';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.filling == null ? 'Новая начинка' : 'Редактировать'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(
                labelText: 'Название *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Обязательное поле';
                }
                return null;
              },
              onSaved: (value) => _name = value!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _quantity.toString(),
              decoration: const InputDecoration(
                labelText: 'Вес порции *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Обязательное поле';
                }
                if (double.tryParse(value) == null) {
                  return 'Введите число';
                }
                return null;
              },
              onSaved: (value) => _quantity = double.parse(value!),
            ),
            const SizedBox(height: 16),

            // 🔥 ВЫБОР ЕДИНИЦЫ ИЗМЕРЕНИЯ
            UnitSelector(
              mode: UnitSelectorMode.weight,
              selectedUnit: _unit,
              onUnitSelected: (unit) {
                setState(() => _unit = unit!);
              },
              labelText: 'Единица измерения *',
              isRequired: true,
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();

              final filling = Filling(
                sheetName: widget.filling?.sheetName ?? 'Начинки',
                entityId: widget.filling?.entityId ??
                    '', // ID будет сгенерирован при сохранении
                name: _name,
                quantity: _quantity,
                unitSymbol: _unit,
                ingredients: widget.filling?.ingredients ?? [],
              );

              widget.onSave(filling);
              Navigator.pop(context, filling);
            }
          },
          child: Text(widget.filling == null ? 'Создать' : 'Сохранить'),
        ),
      ],
    );
  }
}
