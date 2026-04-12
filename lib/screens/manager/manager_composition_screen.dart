// lib/screens/manager/manager_composition_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/composition.dart';
import '../../services/api_service.dart';
import '../../widgets/unit_selector.dart';

class ManagerCompositionScreen extends StatefulWidget {
  final String sourceSheet;
  final String sourceId;
  final String sourceName;

  const ManagerCompositionScreen({
    super.key,
    required this.sourceSheet,
    required this.sourceId,
    required this.sourceName,
  });

  @override
  _ManagerCompositionScreenState createState() =>
      _ManagerCompositionScreenState();
}

class _ManagerCompositionScreenState extends State<ManagerCompositionScreen> {
  List<Composition> _composition = [];
  List<String> _allIngredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Загружаем состав для текущего источника
      final compositionData = await apiService.getCompositionForSource(
        widget.sourceSheet,
        widget.sourceId,
      );

      // Загружаем список всех ингредиентов
      final ingredients = await apiService.getAllIngredients();

      if (compositionData != null) {
        final compositions = compositionData.map((json) {
          return Composition(
            id: json['id']?.toString() ?? json['ID']?.toString() ?? '',
            sheetName: json['sheetName']?.toString() ??
                json['Лист']?.toString() ??
                widget.sourceSheet,
            entityId: json['entityId']?.toString() ??
                json['ID сущности']?.toString() ??
                widget.sourceId,
            ingredientName: json['ingredientName']?.toString() ??
                json['Ингредиент']?.toString() ??
                '',
            quantity: double.tryParse(json['quantity']?.toString() ??
                    json['Количество']?.toString() ??
                    '0') ??
                0.0,
            unitSymbol: json['unitSymbol']?.toString() ??
                json['Ед.изм.']?.toString() ??
                'г',
          );
        }).toList();

        setState(() {
          _composition = compositions;
          _allIngredients = ingredients ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _allIngredients = ingredients ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка загрузки состава: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addItem() async {
    final result = await showDialog<Composition>(
      context: context,
      builder: (_) => CompositionItemDialog(
        ingredients: _allIngredients,
        onSave: (composition) => composition,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        // Создаем новый элемент состава
        final newItem = result.toJson();
        newItem['sheetName'] = widget.sourceSheet;
        newItem['entityId'] = widget.sourceId;

        await apiService.addCompositionItem(newItem);
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ингредиент добавлен'),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка добавления: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editItem(Composition item) async {
    final result = await showDialog<Composition>(
      context: context,
      builder: (_) => CompositionItemDialog(
        item: item,
        ingredients: _allIngredients,
        onSave: (composition) => composition,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        // Обновляем элемент состава
        await apiService.updateCompositionItem(result.toJson());
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ингредиент обновлен'),
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

  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Удалить ингредиент из состава?'),
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
        await apiService.deleteCompositionItem(itemId);
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ингредиент удален'),
              backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Состав: ${widget.sourceName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _composition.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.food_bank, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Нет ингредиентов',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _addItem,
                        child: const Text('Добавить ингредиент'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _composition.length,
                  itemBuilder: (context, index) {
                    final item = _composition[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(item.ingredientName),
                        subtitle: Text('${item.quantity} ${item.unitSymbol}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editItem(item),
                              tooltip: 'Редактировать',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(item.id),
                              tooltip: 'Удалить',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Добавить ингредиент',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CompositionItemDialog extends StatefulWidget {
  final Composition? item;
  final List<String> ingredients;
  final Function(Composition) onSave;

  const CompositionItemDialog({
    super.key,
    this.item,
    required this.ingredients,
    required this.onSave,
  });

  @override
  _CompositionItemDialogState createState() => _CompositionItemDialogState();
}

class _CompositionItemDialogState extends State<CompositionItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _ingredient;
  late double _quantity;
  late String _unit;
  late TextEditingController _ingredientController;

  @override
  void initState() {
    super.initState();
    _ingredient = widget.item?.ingredientName ?? '';
    _quantity = widget.item?.quantity ?? 0;
    _unit = widget.item?.unitSymbol ?? 'г';
    _ingredientController = TextEditingController(text: _ingredient);
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.item == null ? 'Добавить ингредиент' : 'Редактировать'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Поле для выбора ингредиента с автодополнением
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return widget.ingredients.where((ingredient) => ingredient
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (option) {
                  setState(() {
                    _ingredient = option;
                    _ingredientController.text = option;
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  controller.text = _ingredient;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Ингредиент *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Обязательное поле';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Количество
              TextFormField(
                initialValue: _quantity.toString(),
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
                    return 'Введите число';
                  }
                  return null;
                },
                onSaved: (value) => _quantity = double.parse(value!),
              ),
              const SizedBox(height: 16),

              // 🔥 ВЫБОР ЕДИНИЦЫ ИЗМЕРЕНИЯ
              UnitSelector(
                mode: UnitSelectorMode.all,
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

              final composition = Composition(
                id: widget.item?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                sheetName: widget.item?.sheetName ?? '',
                entityId: widget.item?.entityId ?? '',
                ingredientName: _ingredient,
                quantity: _quantity,
                unitSymbol: _unit,
              );

              widget.onSave(composition);
              Navigator.pop(context, composition);
            }
          },
          child: Text(widget.item == null ? 'Добавить' : 'Сохранить'),
        ),
      ],
    );
  }
}
