import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import '../../models/composition.dart';
import '../../models/nutrition_info.dart';
import '../../models/ingredient_info.dart';
import '../../models/price_item.dart';
import '../../models/price_category.dart';
import '../../models/unit_of_measure.dart';

class AdminPriceItemFormScreen extends StatefulWidget {
  final PriceItem? item;
  final String? initialCategoryId;
  final String? initialCategoryName;

  const AdminPriceItemFormScreen({
    super.key,
    this.item,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  @override
  _AdminPriceItemFormScreenState createState() =>
      _AdminPriceItemFormScreenState();
}

class _AdminPriceItemFormScreenState extends State<AdminPriceItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _multiplicityController;
  late TextEditingController _photoUrlController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _categoryIdController;
  late TextEditingController _unitController;
  late TextEditingController _weightController;
  late TextEditingController _compositionController;
  late TextEditingController _nutritionController;
  late TextEditingController _storageController;
  late TextEditingController _packagingController;
  late TextEditingController _wastePercentageController;

  List<IngredientInfo> _ingredients = [];
  List<NutritionInfo> _nutritionItems = [];
  bool _isSaving = false;

  // Списки для выпадающих меню
  List<PriceCategory> _categories = [];
  List<UnitOfMeasure> _units = [];

  // Словарь для перевода категорий единиц измерения
  final Map<String, String> _unitCategoryLabels = {
    'weight': '⚖️ Весовые единицы',
    'volume': '🧪 Объемные единицы',
    'piece': '📦 Штучные единицы',
  };

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController =
        TextEditingController(text: widget.item?.price.toString() ?? '');
    _multiplicityController = TextEditingController(
        text: widget.item?.multiplicity.toString() ?? '1');
    _photoUrlController =
        TextEditingController(text: widget.item?.photoUrl ?? '');
    _descriptionController =
        TextEditingController(text: widget.item?.description ?? '');

    _categoryController =
        TextEditingController(text: widget.item?.category ?? '');
    _categoryIdController =
        TextEditingController(text: widget.item?.categoryId ?? '');

    _unitController = TextEditingController(text: widget.item?.unit ?? 'г');
    _weightController =
        TextEditingController(text: widget.item?.weight.toString() ?? '0');

    _compositionController = TextEditingController();
    _nutritionController = TextEditingController();
    _storageController = TextEditingController();
    _packagingController = TextEditingController();
    _wastePercentageController = TextEditingController(text: '10');

    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _multiplicityController.dispose();
    _photoUrlController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _categoryIdController.dispose();
    _unitController.dispose();
    _weightController.dispose();
    _compositionController.dispose();
    _nutritionController.dispose();
    _storageController.dispose();
    _packagingController.dispose();
    _wastePercentageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData;
    if (clientData == null) return;

    // 1. Загружаем списки
    setState(() {
      _categories = clientData.priceCategories;
      _units = clientData.unitsOfMeasure;
    });

    // 2. Если редактируем существующий товар, грузим связанные данные
    if (widget.item != null) {
      await _loadRelatedData();
    } else {
      // Если новый товар, применяем начальную категорию если есть
      if (widget.initialCategoryName != null)
        _categoryController.text = widget.initialCategoryName!;
      if (widget.initialCategoryId != null)
        _categoryIdController.text = widget.initialCategoryId!;
    }
  }

  Future<void> _loadUnits() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Загружаем список единиц измерения из ClientData
    final units = authProvider.clientData?.unitsOfMeasure ?? [];

    if (mounted) {
      setState(() {
        _units = units;
      });
    }
  }

  // 🔥 ДИАГНОСТИКА И ЗАГРУЗКА СВЯЗАННЫХ ДАННЫХ
  Future<void> _loadRelatedData() async {
    if (widget.item == null) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final clientData = authProvider.clientData;
      if (clientData == null) return;

      // Ингредиенты
      final allCompositions = clientData.compositions;
      final ingredients = allCompositions
          .where((comp) =>
              comp.sheetName == 'Состав' && comp.entityId == widget.item!.id)
          .map((comp) => IngredientInfo(
              name: comp.ingredientName,
              quantity: comp.quantity,
              unit: comp.unitSymbol))
          .toList();

      // КБЖУ
      final allNutrition = clientData.nutritionInfos;
      final nutrition =
          allNutrition.where((n) => n.priceListId == widget.item!.id).toList();

      // ==========================================
      // 🔥 ДИАГНОСТИКА ПОИСКА КАТЕГОРИИ
      // ==========================================

      PriceCategory? productCategory;

      final rawCategoryId = widget.item!.categoryId;
      debugPrint('------------------------------------------');
      debugPrint('🔍 ДИАГНОСТИКА:');
      debugPrint('   ID товара: ${widget.item!.id}');
      debugPrint(
          '   Категория из Прайс-листа (rawCategoryId): "$rawCategoryId" (Type: ${rawCategoryId.runtimeType})');
      debugPrint('   Всего категорий в Hive: ${_categories.length}');

      if (_categories.isNotEmpty) {
        debugPrint(
            '   Пример первой категории в Hive: ID=${_categories[0].id}, Name=${_categories[0].name}');
      }

      if (rawCategoryId.isNotEmpty) {
        try {
          productCategory = _categories.firstWhere(
            (c) => c.id.toString().trim() == rawCategoryId.trim(),
          );
          debugPrint('   ✅ УСПЕХ! Найдена категория: ${productCategory.name}');
        } catch (e) {
          debugPrint('   ❌ НЕ НАЙДЕНО совпадения по ID "$rawCategoryId"');
        }
      }

      if (productCategory == null && widget.item!.category.isNotEmpty) {
        debugPrint('   Пытаюсь найти по имени: "${widget.item!.category}"');
        try {
          productCategory = _categories.firstWhere(
            (c) => c.name.trim() == widget.item!.category.trim(),
          );
          debugPrint('   ✅ Найдено по имени!');
        } catch (e) {
          debugPrint('   ❌ Не найдено и по имени');
        }
      }

      debugPrint('------------------------------------------');

      // ==========================================
      // КОНЕЦ ДИАГНОСТИКИ
      // ==========================================

      if (mounted) {
        setState(() {
          _ingredients = ingredients;
          _nutritionItems = nutrition;

          if (productCategory != null) {
            if (_categoryIdController.text.isEmpty)
              _categoryIdController.text = productCategory.id.toString();
            if (_categoryController.text.isEmpty)
              _categoryController.text = productCategory.name;

            if (productCategory.weight > 0)
              _weightController.text = productCategory.weight.toString();
            if (productCategory.unit.isNotEmpty)
              _unitController.text = productCategory.unit;

            _wastePercentageController.text =
                productCategory.wastePercentage.toString();

            debugPrint(
                '✅ Форма заполнена данными из категории: ${productCategory.name}');
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки связанных данных: $e');
    }
  }

  void _addIngredient() => setState(() =>
      _ingredients.add(IngredientInfo(name: '', quantity: 0.0, unit: 'г')));
  void _removeIngredient(int index) =>
      setState(() => _ingredients.removeAt(index));
  void _updateIngredient(int index, IngredientInfo updated) =>
      setState(() => _ingredients[index] = updated);

  void _addNutrition() => setState(() => _nutritionItems.add(NutritionInfo(
      priceListId: widget.item?.id,
      calories: '',
      proteins: '',
      fats: '',
      carbohydrates: '')));
  void _removeNutrition(int index) =>
      setState(() => _nutritionItems.removeAt(index));
  void _updateNutrition(int index, NutritionInfo updated) =>
      setState(() => _nutritionItems[index] = updated);

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final String itemId;
      if (widget.item != null) {
        itemId = widget.item!.id;
      } else {
        final existingIds = authProvider.clientData!.products
            .map((p) => int.tryParse(p.id) ?? 0)
            .toList();
        final maxId = existingIds.isEmpty
            ? 0
            : existingIds.reduce((a, b) => a > b ? a : b);
        itemId = (maxId + 1).toString();
      }

      final priceItem = PriceItem(
        id: itemId,
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text),
        category: _categoryController.text.trim(),
        unit: _unitController.text.trim(),
        weight: double.tryParse(_weightController.text) ?? 0.0,
        multiplicity: int.parse(_multiplicityController.text),
        photoUrl: _photoUrlController.text.trim().isNotEmpty
            ? _photoUrlController.text.trim()
            : null,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        categoryId: _categoryIdController.text,
      );

      final product = Product(
        id: priceItem.id,
        name: priceItem.name,
        price: priceItem.price,
        multiplicity: priceItem.multiplicity,
        categoryId:
            priceItem.categoryId.isNotEmpty ? priceItem.categoryId : 'default',
        imageUrl: priceItem.photoUrl,
        imageBase64: null,
        composition: _compositionController.text,
        weight: _weightController.text,
        nutrition: _nutritionController.text,
        storage: _storageController.text,
        packaging: _packagingController.text,
        categoryName: priceItem.category,
        wastePercentage: int.tryParse(_wastePercentageController.text) ?? 10,
        displayName: priceItem.name,
      );

      if (widget.item != null) {
        await _updatePriceItem(authProvider, product, priceItem.id);
      } else {
        await _createPriceItem(authProvider, product, priceItem.id);
      }

      await _saveProductsToPrefs(authProvider);

      if (mounted) {
        Navigator.pop(context, true);
        _showSnackBar('Товар успешно сохранен', Colors.green);
      }
    } catch (e) {
      debugPrint('❌ Ошибка сохранения товара: $e');
      if (mounted) _showSnackBar('Ошибка сохранения: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updatePriceItem(
      AuthProvider authProvider, Product product, String itemId) async {
    final index = authProvider.clientData!.products
        .indexWhere((p) => p.id == widget.item!.id);
    if (index != -1) {
      authProvider.clientData!.products[index] = product;
      await _updateIngredients(authProvider, itemId);
      await _updateNutritionItems(authProvider, itemId);
      authProvider.clientData!.buildIndexes();
      await _apiService.updateProduct(product);
    }
  }

  Future<void> _createPriceItem(
      AuthProvider authProvider, Product product, String itemId) async {
    authProvider.clientData!.products.add(product);
    await _addIngredients(authProvider, itemId);
    await _addNutritionItems(authProvider, itemId);
    authProvider.clientData!.buildIndexes();
    await _apiService.createProduct(product);
  }

  Future<void> _updateIngredients(
      AuthProvider authProvider, String itemId) async {
    authProvider.clientData!.compositions
        .removeWhere((c) => c.sheetName == 'Состав' && c.entityId == itemId);
    for (var ingredient in _ingredients) {
      if (ingredient.name.isNotEmpty) {
        final newId =
            '${DateTime.now().millisecondsSinceEpoch}_${_ingredients.indexOf(ingredient)}';
        authProvider.clientData!.compositions.add(Composition(
          id: newId,
          sheetName: 'Состав',
          entityId: itemId,
          ingredientName: ingredient.name,
          quantity: ingredient.quantity,
          unitSymbol: ingredient.unit,
        ));
      }
    }
  }

  Future<void> _addIngredients(AuthProvider authProvider, String itemId) async {
    for (var ingredient in _ingredients) {
      if (ingredient.name.isNotEmpty) {
        final newId =
            '${DateTime.now().millisecondsSinceEpoch}_${_ingredients.indexOf(ingredient)}';
        authProvider.clientData!.compositions.add(Composition(
          id: newId,
          sheetName: 'Состав',
          entityId: itemId,
          ingredientName: ingredient.name,
          quantity: ingredient.quantity,
          unitSymbol: ingredient.unit,
        ));
      }
    }
  }

  Future<void> _updateNutritionItems(
      AuthProvider authProvider, String itemId) async {
    authProvider.clientData!.nutritionInfos
        .removeWhere((n) => n.priceListId == itemId);
    for (var nutrition in _nutritionItems) {
      if ([
        nutrition.calories,
        nutrition.proteins,
        nutrition.fats,
        nutrition.carbohydrates
      ].any((e) => e != null && e.isNotEmpty)) {
        authProvider.clientData!.nutritionInfos.add(NutritionInfo(
          priceListId: itemId,
          calories: nutrition.calories,
          proteins: nutrition.proteins,
          fats: nutrition.fats,
          carbohydrates: nutrition.carbohydrates,
        ));
      }
    }
  }

  Future<void> _addNutritionItems(
      AuthProvider authProvider, String itemId) async {
    for (var nutrition in _nutritionItems) {
      if ([
        nutrition.calories,
        nutrition.proteins,
        nutrition.fats,
        nutrition.carbohydrates
      ].any((e) => e != null && e.isNotEmpty)) {
        authProvider.clientData!.nutritionInfos.add(NutritionInfo(
          priceListId: itemId,
          calories: nutrition.calories,
          proteins: nutrition.proteins,
          fats: nutrition.fats,
          carbohydrates: nutrition.carbohydrates,
        ));
      }
    }
  }

  Future<void> _saveProductsToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'client_data', jsonEncode(authProvider.clientData!.toJson()));
    } catch (e) {
      debugPrint('❌ Ошибка сохранения ClientData: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2)));
  }

  // Обработчик выбора категории
  void _onCategoryChanged(String? newValue) {
    if (newValue == null) return;
    setState(() => _categoryController.text = newValue);

    try {
      final category = _categories.firstWhere((c) => c.name == newValue);
      setState(() {
        _categoryIdController.text = category.id.toString();
        if (category.weight > 0)
          _weightController.text = category.weight.toString();
        if (category.unit.isNotEmpty) _unitController.text = category.unit;
        _wastePercentageController.text = category.wastePercentage.toString();
      });
    } catch (e) {
      debugPrint('❌ Ошибка при выборе категории: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.item != null ? 'Редактировать товар' : 'Новый товар'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildMainInfoCard(),
                    const SizedBox(height: 16),
                    _buildCategoryCard(),
                    const SizedBox(height: 16),
                    _buildImageCard(),
                    const SizedBox(height: 16),
                    _buildDescriptionCard(),
                    const SizedBox(height: 16),
                    // _buildIngredientsCard(), // Если есть билдеры, раскомментировать
                    // const SizedBox(height: 16),
                    // _buildNutritionCard(),
                    // const SizedBox(height: 16),
                    // _buildExtraInfoCard(),
                    // const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saveItem,
                      icon: const Icon(Icons.save),
                      label: Text(
                          widget.item != null ? 'Сохранить' : 'Добавить товар',
                          style: const TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================
  // БИЛДЕРЫ КАРТОЧЕК
  // ==========================================

  Widget _buildMainInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Основная информация',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название *'),
              validator: (v) => v!.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Цена *'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Введите цену' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _multiplicityController,
              decoration: const InputDecoration(labelText: 'Кратность'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Категория и параметры',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            // ==========================================
            // 1. ВЫПАДАЮЩИЙ СПИСОК КАТЕГОРИЙ
            // ==========================================
            DropdownButtonFormField<String>(
              value: _categoryController.text.isNotEmpty
                  ? _categoryController.text
                  : null,
              decoration: const InputDecoration(
                labelText: 'Категория *',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              items: _categories.map((category) {
                final isSelected = category.name == _categoryController.text;

                // ВАЖНО: Убрали Container.
                // Для обычных элементов делаем текст Белым (чтобы было видно на темно-коричневом фоне).
                // Для выбранного - тоже Белым и Жирным.
                return DropdownMenuItem<String>(
                  value: category.name,
                  child: Text(
                    category.name,
                    style: TextStyle(
                      // Белый текст для всех пунктов, чтобы было видно на темном фоне меню
                      color: Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                _onCategoryChanged(newValue);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Выберите категорию';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Вес
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Вес'),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 12),

            // ==========================================
            // 2. ВЫПАДАЮЩИЙ СПИСОК ЕДИНИЦ ИЗМЕРЕНИЯ
            // ==========================================
            DropdownButtonFormField<String>(
              value:
                  _unitController.text.isNotEmpty ? _unitController.text : null,
              decoration: const InputDecoration(
                labelText: 'Ед. изм. *',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              items: [
                ...['weight', 'volume', 'piece'].map((categoryKey) {
                  final categoryUnits =
                      _units.where((u) => u.category == categoryKey).toList();

                  if (categoryUnits.isEmpty)
                    return <DropdownMenuItem<String>>[];

                  return [
                    // Заголовок категории (светло-коричневый/бежевый для контраста)
                    DropdownMenuItem<String>(
                      enabled: false,
                      child: Text(
                        _unitCategoryLabels[categoryKey] ?? categoryKey,
                        style: TextStyle(
                          color: Colors
                              .brown[200], // Светлый цвет для заголовка группы
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    // Элементы списка (Белый текст)
                    ...categoryUnits.map((unit) {
                      final isSelected = unit.symbol == _unitController.text;
                      return DropdownMenuItem<String>(
                        value: unit.symbol,
                        child: Text(
                          '${unit.symbol} (${unit.name})',
                          style: TextStyle(
                            color: Colors.white, // Белый текст для видимости
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ];
                }).expand((x) => x),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _unitController.text = newValue ?? '';
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Выберите единицу';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _wastePercentageController,
              decoration:
                  const InputDecoration(labelText: 'Процент издержек (%)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Изображение',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            TextFormField(
              controller: _photoUrlController,
              decoration: const InputDecoration(labelText: 'URL фото'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Описание',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Описание товара'),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  // Если нужно, добавьте сюда остальные билдеры (_buildIngredientsCard, _buildNutritionCard и т.д.)
}
