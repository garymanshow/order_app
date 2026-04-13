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
import '../../widgets/unit_selector.dart';

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

  List<String> _allProductNames = [];
  bool _isLoadingNames = false;

  @override
  void initState() {
    super.initState();

    // Инициализация контроллеров
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController =
        TextEditingController(text: widget.item?.price.toString() ?? '');
    _multiplicityController = TextEditingController(
        text: widget.item?.multiplicity.toString() ?? '1');
    _photoUrlController =
        TextEditingController(text: widget.item?.photoUrl ?? '');
    _descriptionController =
        TextEditingController(text: widget.item?.description ?? '');

    // Категория и её ID
    _categoryController =
        TextEditingController(text: widget.item?.category ?? '');
    _categoryIdController =
        TextEditingController(text: widget.item?.categoryId ?? '');

    _unitController = TextEditingController(text: widget.item?.unit ?? 'шт');
    _weightController =
        TextEditingController(text: widget.item?.weight.toString() ?? '0');

    _compositionController = TextEditingController();
    _nutritionController = TextEditingController();
    _storageController = TextEditingController();
    _packagingController = TextEditingController();
    _wastePercentageController = TextEditingController(text: '10');

    // Если передали начальную категорию при создании
    if (widget.item == null) {
      if (widget.initialCategoryName != null) {
        _categoryController.text = widget.initialCategoryName!;
      }
      if (widget.initialCategoryId != null) {
        _categoryIdController.text = widget.initialCategoryId!;
      }
      _loadAllProductNames();
    } else {
      // Если редактируем — загружаем связанные данные
      _loadRelatedData();
    }
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

  Future<void> _loadAllProductNames() async {
    setState(() => _isLoadingNames = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final products = authProvider.clientData?.products ?? [];
      _allProductNames = products.map((p) => p.name).toList();
      _allProductNames.sort();
    } catch (e) {
      debugPrint('❌ Ошибка загрузки названий: $e');
    } finally {
      if (mounted) setState(() => _isLoadingNames = false);
    }
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД ЗАГРУЗКИ СВЯЗАННЫХ ДАННЫХ
  Future<void> _loadRelatedData() async {
    if (widget.item == null) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final clientData = authProvider.clientData;
      if (clientData == null) return;

      // 1. Загрузка ингредиентов
      final allCompositions = clientData.compositions;
      final ingredients = allCompositions
          .where((comp) =>
              comp.sheetName == 'Состав' && comp.entityId == widget.item!.id)
          .map((comp) => IngredientInfo(
                name: comp.ingredientName,
                quantity: comp.quantity,
                unit: comp.unitSymbol,
              ))
          .toList();

      // 2. Загрузка КБЖУ
      final allNutrition = clientData.nutritionInfos;
      final nutrition =
          allNutrition.where((n) => n.priceListId == widget.item!.id).toList();

      // 3. 🔥 ПОИСК КАТЕГОРИИ (Сначала по ID, потом по Имени)
      PriceCategory? productCategory;

      // Попытка 1: Поиск по ID
      final categoryId = widget.item!.categoryId;
      if (categoryId.isNotEmpty) {
        try {
          // 👇 ПРИВОДИМ К СТРОКЕ И УБИРАЕМ ПРОБЕЛЫ
          final normalizedId = categoryId.toString().trim();
          productCategory = clientData.priceCategories.firstWhere(
            (c) => c.id.toString().trim() == normalizedId,
          );
          debugPrint('✅ Категория найдена по ID: $normalizedId');
        } catch (e) {
          debugPrint(
              '⚠️ Категория по ID "$categoryId" не найдена в списке (${clientData.priceCategories.length} шт)');
        }
      }

      // Попытка 2: Поиск по Имени (если ID пуст или не найден)
      if (productCategory == null && widget.item!.category.isNotEmpty) {
        try {
          productCategory = clientData.priceCategories.firstWhere(
            (c) => c.name == widget.item!.category,
          );
        } catch (e) {
          debugPrint('⚠️ Категория по Имени не найдена');
        }
      }

      if (mounted) {
        setState(() {
          _ingredients = ingredients;
          _nutritionItems = nutrition;

          // 🔥 ЗАПОЛНЯЕМ ПОЛЯ ИЗ НАЙДЕННОЙ КАТЕГОРИИ
          if (productCategory != null) {
            // Обновляем контроллеры, если в товаре были пустые данные

            // Если ID категории в товаре был пуст - заполняем
            if (_categoryIdController.text.isEmpty) {
              _categoryIdController.text = productCategory.id.toString();
            }

            // Если название категории в товаре было пусто - заполняем
            if (_categoryController.text.isEmpty) {
              _categoryController.text = productCategory.name;
            }

            // Вес (подтягиваем из категории, если в товаре 0)
            if (productCategory.weight > 0 &&
                (double.tryParse(_weightController.text) ?? 0) == 0) {
              _weightController.text = productCategory.weight.toString();
            }

            // Ед. измерения (подтягиваем из категории, если в товаре дефолт)
            if (productCategory.unit.isNotEmpty &&
                _unitController.text == 'шт') {
              _unitController.text = productCategory.unit;
            }

            // Издержки
            _wastePercentageController.text =
                productCategory.wastePercentage.toString();

            debugPrint(
                '✅ Данные подтянуты из категории: ${productCategory.name}');
            debugPrint('   ID: ${_categoryIdController.text}');
            debugPrint(
                '   Вес: ${_weightController.text}, Ед: ${_unitController.text}');
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки связанных данных: $e');
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(IngredientInfo(name: '', quantity: 0.0, unit: 'г'));
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _updateIngredient(int index, IngredientInfo updated) {
    setState(() {
      _ingredients[index] = updated;
    });
  }

  void _addNutrition() {
    setState(() {
      _nutritionItems.add(NutritionInfo(
        priceListId: widget.item?.id,
        calories: '',
        proteins: '',
        fats: '',
        carbohydrates: '',
      ));
    });
  }

  void _removeNutrition(int index) {
    setState(() {
      _nutritionItems.removeAt(index);
    });
  }

  void _updateNutrition(int index, NutritionInfo updated) {
    setState(() {
      _nutritionItems[index] = updated;
    });
  }

  String _getImagePath(String? id) {
    if (id == null || id.isEmpty) return '';
    return 'assets/images/products/$id.webp';
  }

  Product _convertToProduct(PriceItem priceItem) {
    return Product(
      id: priceItem.id,
      name: priceItem.name,
      price: priceItem.price,
      multiplicity: priceItem.multiplicity,
      categoryId: _categoryIdController.text.isNotEmpty
          ? _categoryIdController.text
          : 'default',
      imageUrl: priceItem.photoUrl,
      imageBase64: null,
      composition: _compositionController.text,
      weight: _weightController.text,
      nutrition: _nutritionController.text,
      storage: _storageController.text,
      packaging: _packagingController.text,
      categoryName: _categoryController.text,
      wastePercentage: int.tryParse(_wastePercentageController.text) ?? 10,
      displayName: priceItem.name,
    );
  }

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
        categoryId: _categoryIdController.text, // Сохраняем ID категории
      );

      final product = _convertToProduct(priceItem);

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
      if (mounted) {
        _showSnackBar('Ошибка сохранения: $e', Colors.red);
      }
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
      debugPrint('✅ Товар обновлен: ${product.name}');
    }
  }

  Future<void> _createPriceItem(
      AuthProvider authProvider, Product product, String itemId) async {
    authProvider.clientData!.products.add(product);
    await _addIngredients(authProvider, itemId);
    await _addNutritionItems(authProvider, itemId);
    authProvider.clientData!.buildIndexes();
    await _apiService.createProduct(product);
    debugPrint('✅ Новый товар создан: ${product.name}');
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
      if (nutrition.calories?.isNotEmpty == true ||
          nutrition.proteins?.isNotEmpty == true ||
          nutrition.fats?.isNotEmpty == true ||
          nutrition.carbohydrates?.isNotEmpty == true) {
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
      if (nutrition.calories?.isNotEmpty == true ||
          nutrition.proteins?.isNotEmpty == true ||
          nutrition.fats?.isNotEmpty == true ||
          nutrition.carbohydrates?.isNotEmpty == true) {
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
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      debugPrint('❌ Ошибка сохранения ClientData: $e');
    }
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

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД ОБРАБОТКИ ВЫБОРА КАТЕГОРИИ
  void _onCategoryChanged(String? newValue) {
    if (newValue == null) return;

    setState(() {
      _categoryController.text = newValue;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final categories = authProvider.clientData?.priceCategories ?? [];

      final category = categories.firstWhere(
        (c) => c.name == newValue,
        orElse: () => null as dynamic,
      );

      if (category != null) {
        setState(() {
          _categoryIdController.text = category.id.toString();

          // Подставляем данные из категории
          if (category.weight > 0) {
            _weightController.text = category.weight.toString();
          }

          if (category.unit.isNotEmpty) {
            _unitController.text = category.unit;
          }

          _wastePercentageController.text = category.wastePercentage.toString();
        });

        debugPrint('✅ Категория выбрана: $newValue');
        debugPrint('   Подставлен ID: ${_categoryIdController.text}');
        debugPrint('   Подставлен вес: ${_weightController.text}');
        debugPrint('   Подставлена ед: ${_unitController.text}');
      }
    } catch (e) {
      debugPrint('❌ Ошибка при выборе категории: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item != null ? 'Редактировать товар' : 'Новый товар',
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Основная информация
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (widget.item == null && !_isLoadingNames)
                              Autocomplete<String>(
                                optionsBuilder: (textEditingValue) {
                                  if (textEditingValue.text == '') {
                                    return _allProductNames;
                                  }
                                  return _allProductNames.where((name) {
                                    return name.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase());
                                  }).toList();
                                },
                                onSelected: (selection) {
                                  _nameController.text = selection;
                                },
                                fieldViewBuilder: (context, controller,
                                    focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Название *',
                                      prefixIcon: const Icon(Icons.label),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) => value!.trim().isEmpty
                                        ? 'Обязательное поле'
                                        : null,
                                    onFieldSubmitted: (_) => onFieldSubmitted(),
                                  );
                                },
                              ),
                            if (widget.item != null)
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Название *',
                                  prefixIcon: const Icon(Icons.label),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (value) => value!.trim().isEmpty
                                    ? 'Обязательное поле'
                                    : null,
                              ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _priceController,
                              decoration: InputDecoration(
                                labelText: 'Цена *',
                                prefixIcon: const Icon(Icons.attach_money),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value!.trim().isEmpty) {
                                  return 'Обязательное поле';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Неверный формат';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Категория и характеристики
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 🔥 Consumer категорий
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                final categories =
                                    authProvider.clientData?.priceCategories ??
                                        [];

                                final validCategories = categories
                                    .where((c) => c.name.isNotEmpty)
                                    .toList();
                                validCategories
                                    .sort((a, b) => a.name.compareTo(b.name));

                                return DropdownButtonFormField<String>(
                                  // 👈 Используем текущее значение контроллера
                                  value: _categoryController.text.isNotEmpty
                                      ? _categoryController.text
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: 'Категория *',
                                    prefixIcon: const Icon(Icons.category),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: validCategories.map((cat) {
                                    return DropdownMenuItem(
                                      value: cat.name,
                                      child: Text(cat.name),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) _onCategoryChanged(val);
                                  },
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? 'Обязательное поле'
                                          : null,
                                  hint: Text(validCategories.isEmpty
                                      ? 'Нет данных'
                                      : 'Выберите...'),
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // Unit Selector
                            UnitSelector(
                              mode: UnitSelectorMode.warehouse,
                              selectedUnit: _unitController.text,
                              onUnitSelected: (unit) {
                                if (unit != null) {
                                  setState(() {
                                    _unitController.text = unit;
                                  });
                                }
                              },
                              labelText: 'Единица измерения *',
                              isRequired: true,
                            ),

                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _weightController,
                                    decoration: InputDecoration(
                                      labelText: 'Вес',
                                      prefixIcon:
                                          const Icon(Icons.monitor_weight),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _multiplicityController,
                                    decoration: InputDecoration(
                                      labelText: 'Кратность *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value!.trim().isEmpty) {
                                        return 'Обязательное поле';
                                      }
                                      if (int.tryParse(value) == null) {
                                        return 'Неверный формат';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Изображение
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Изображение',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (widget.item != null)
                              Container(
                                height: 100,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: widget.item!.id.isNotEmpty
                                    ? Image.asset(
                                        _getImagePath(widget.item!.id),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image,
                                                  color: Colors.grey),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Нет фото',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          );
                                        },
                                      )
                                    : const Icon(Icons.image,
                                        size: 50, color: Colors.grey),
                              ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _photoUrlController,
                              decoration: InputDecoration(
                                labelText: 'URL фото (опционально)',
                                hintText: 'assets/images/products/id.webp',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Для PWA изображения хранятся в assets/images/products/id.webp',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Описание
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Описание',
                            prefixIcon: const Icon(Icons.description),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Ингредиенты
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Состав',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.green),
                                  onPressed: _addIngredient,
                                  tooltip: 'Добавить ингредиент',
                                ),
                              ],
                            ),
                            const Divider(),
                            if (_ingredients.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Нет ингредиентов'),
                                ),
                              )
                            else
                              ..._ingredients.asMap().entries.map((entry) {
                                final index = entry.key;
                                final ingredient = entry.value;
                                return _buildIngredientRow(index, ingredient);
                              }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // КБЖУ
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'КБЖУ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.blue),
                                  onPressed: _addNutrition,
                                  tooltip: 'Добавить КБЖУ',
                                ),
                              ],
                            ),
                            const Divider(),
                            if (_nutritionItems.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Нет данных КБЖУ'),
                                ),
                              )
                            else
                              ..._nutritionItems.asMap().entries.map((entry) {
                                final index = entry.key;
                                final nutrition = entry.value;
                                return _buildNutritionRow(index, nutrition);
                              }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Дополнительная информация
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _compositionController,
                              decoration: InputDecoration(
                                labelText: 'Состав (текстом)',
                                prefixIcon: const Icon(Icons.food_bank),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nutritionController,
                              decoration: InputDecoration(
                                labelText: 'Пищевая ценность',
                                prefixIcon: const Icon(Icons.fitness_center),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _storageController,
                              decoration: InputDecoration(
                                labelText: 'Условия хранения',
                                prefixIcon: const Icon(Icons.ac_unit),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _packagingController,
                              decoration: InputDecoration(
                                labelText: 'Упаковка',
                                prefixIcon: const Icon(Icons.inventory),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _wastePercentageController,
                              decoration: InputDecoration(
                                labelText: 'Издержки (%)',
                                prefixIcon: const Icon(Icons.percent),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Кнопка сохранения
                    ElevatedButton.icon(
                      onPressed: _saveItem,
                      icon: const Icon(Icons.save),
                      label: Text(
                        widget.item != null ? 'Сохранить' : 'Добавить товар',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildIngredientRow(int index, IngredientInfo ingredient) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Ингредиент',
                  border: InputBorder.none,
                ),
                controller: TextEditingController(text: ingredient.name),
                onChanged: (value) {
                  _updateIngredient(
                    index,
                    IngredientInfo(
                      name: value,
                      quantity: ingredient.quantity,
                      unit: ingredient.unit,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Кол-во',
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.number,
                controller:
                    TextEditingController(text: ingredient.quantity.toString()),
                onChanged: (value) {
                  _updateIngredient(
                    index,
                    IngredientInfo(
                      name: ingredient.name,
                      quantity: double.tryParse(value) ?? 0.0,
                      unit: ingredient.unit,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Ед.',
                  border: InputBorder.none,
                ),
                value: ingredient.unit,
                items: const [
                  DropdownMenuItem(value: 'г', child: Text('г')),
                  DropdownMenuItem(value: 'кг', child: Text('кг')),
                  DropdownMenuItem(value: 'мл', child: Text('мл')),
                  DropdownMenuItem(value: 'л', child: Text('л')),
                  DropdownMenuItem(value: 'tbsp', child: Text('tbsp')),
                  DropdownMenuItem(value: 'tsp', child: Text('tsp')),
                  DropdownMenuItem(value: 'cup', child: Text('cup')),
                ],
                onChanged: (value) {
                  _updateIngredient(
                    index,
                    IngredientInfo(
                      name: ingredient.name,
                      quantity: ingredient.quantity,
                      unit: value!,
                    ),
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeIngredient(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(int index, NutritionInfo nutrition) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Ккал',
                  border: InputBorder.none,
                ),
                controller:
                    TextEditingController(text: nutrition.calories ?? ''),
                onChanged: (value) {
                  _updateNutrition(
                    index,
                    NutritionInfo(
                      priceListId: widget.item?.id,
                      calories: value,
                      proteins: nutrition.proteins,
                      fats: nutrition.fats,
                      carbohydrates: nutrition.carbohydrates,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Белки',
                  border: InputBorder.none,
                ),
                controller:
                    TextEditingController(text: nutrition.proteins ?? ''),
                onChanged: (value) {
                  _updateNutrition(
                    index,
                    NutritionInfo(
                      priceListId: widget.item?.id,
                      calories: nutrition.calories,
                      proteins: value,
                      fats: nutrition.fats,
                      carbohydrates: nutrition.carbohydrates,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Жиры',
                  border: InputBorder.none,
                ),
                controller: TextEditingController(text: nutrition.fats ?? ''),
                onChanged: (value) {
                  _updateNutrition(
                    index,
                    NutritionInfo(
                      priceListId: widget.item?.id,
                      calories: nutrition.calories,
                      proteins: nutrition.proteins,
                      fats: value,
                      carbohydrates: nutrition.carbohydrates,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Угл.',
                  border: InputBorder.none,
                ),
                controller:
                    TextEditingController(text: nutrition.carbohydrates ?? ''),
                onChanged: (value) {
                  _updateNutrition(
                    index,
                    NutritionInfo(
                      priceListId: widget.item?.id,
                      calories: nutrition.calories,
                      proteins: nutrition.proteins,
                      fats: nutrition.fats,
                      carbohydrates: value,
                    ),
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeNutrition(index),
            ),
          ],
        ),
      ),
    );
  }
}
