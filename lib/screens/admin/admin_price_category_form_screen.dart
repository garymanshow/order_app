// lib/screens/admin_price_category_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/price_category.dart';
import '../../models/product.dart';

class AdminPriceCategoryFormScreen extends StatefulWidget {
  final PriceCategory? category;

  const AdminPriceCategoryFormScreen({super.key, this.category});

  @override
  _AdminPriceCategoryFormScreenState createState() =>
      _AdminPriceCategoryFormScreenState();
}

class _AdminPriceCategoryFormScreenState
    extends State<AdminPriceCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _packagingQuantityController;
  late TextEditingController _packagingNameController;
  late TextEditingController _weightController;
  late TextEditingController _unitController;
  late TextEditingController _wastePercentageController;

  bool _isSaving = false;
  bool _updateExistingProducts = true; // Флаг для обновления товаров

  @override
  void initState() {
    super.initState();

    if (widget.category != null) {
      // Редактирование существующей категории
      _nameController = TextEditingController(text: widget.category!.name);
      _packagingQuantityController = TextEditingController(
          text: widget.category!.packagingQuantity.toString());
      _packagingNameController =
          TextEditingController(text: widget.category!.packagingName);
      _weightController =
          TextEditingController(text: widget.category!.weight.toString());
      _unitController = TextEditingController(text: widget.category!.unit);
      _wastePercentageController = TextEditingController(
          text: widget.category!.wastePercentage.toString());
    } else {
      // Новая категория
      _nameController = TextEditingController();
      _packagingQuantityController = TextEditingController(text: '5');
      _packagingNameController =
          TextEditingController(text: 'Транспортный контейнер');
      _weightController = TextEditingController(text: '120');
      _unitController = TextEditingController(text: 'г');
      _wastePercentageController = TextEditingController(text: '10');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packagingQuantityController.dispose();
    _packagingNameController.dispose();
    _weightController.dispose();
    _unitController.dispose();
    _wastePercentageController.dispose();
    super.dispose();
  }

  // 🔥 Генерация ID для новой категории
  String _generateCategoryId(List<PriceCategory> existingCategories) {
    if (existingCategories.isEmpty) return '1';

    final maxId = existingCategories
        .map((c) => int.tryParse(c.id) ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return (maxId + 1).toString();
  }

  // 🔥 Обновление всех товаров категории при изменении фасовки
  Future<void> _updateProductsInCategory(
    AuthProvider authProvider,
    String categoryId,
    int oldPackagingQuantity,
    int newPackagingQuantity,
  ) async {
    if (oldPackagingQuantity == newPackagingQuantity) return;

    print('🔄 Обновление товаров категории $categoryId: '
        'фасовка $oldPackagingQuantity → $newPackagingQuantity');

    int updatedCount = 0;
    final updatedProducts = <Product>[];

    for (int i = 0; i < authProvider.clientData!.products.length; i++) {
      final product = authProvider.clientData!.products[i];
      if (product.categoryId == categoryId) {
        // Создаем обновленный товар с новой кратностью
        final updatedProduct = Product(
          id: product.id,
          name: product.name,
          price: product.price,
          multiplicity: newPackagingQuantity, // 👈 ОБНОВЛЯЕМ КРАТНОСТЬ
          categoryId: product.categoryId,
          imageUrl: product.imageUrl,
          imageBase64: product.imageBase64,
          composition: product.composition,
          weight: product.weight,
          nutrition: product.nutrition,
          storage: product.storage,
          packaging: product.packaging,
          categoryName: product.categoryName,
          wastePercentage: product.wastePercentage,
          displayName: product.displayName,
        );

        authProvider.clientData!.products[i] = updatedProduct;
        updatedProducts.add(updatedProduct);
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      print('✅ Обновлено товаров: $updatedCount');

      // Отправляем обновления на сервер
      for (var product in updatedProducts) {
        await _apiService.updateProduct(product);
      }
    }
  }

  // 🔥 Сохранение категории
  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Получаем или генерируем ID
      final String categoryId;
      if (widget.category != null) {
        categoryId = widget.category!.id;
      } else {
        categoryId =
            _generateCategoryId(authProvider.clientData?.priceCategories ?? []);
      }

      // Парсим числовые значения
      final newPackagingQuantity = int.parse(_packagingQuantityController.text);
      final newWeight = double.parse(_weightController.text);
      final newWastePercentage = int.parse(_wastePercentageController.text);

      // Создаем объект категории
      final category = PriceCategory(
        id: categoryId,
        name: _nameController.text.trim(),
        packagingQuantity: newPackagingQuantity,
        packagingName: _packagingNameController.text.trim(),
        weight: newWeight,
        unit: _unitController.text.trim(),
        wastePercentage: newWastePercentage,
      );

      if (widget.category != null) {
        // РЕДАКТИРОВАНИЕ
        final oldPackagingQuantity = widget.category!.packagingQuantity;

        // Обновляем категорию в локальных данных
        final index = authProvider.clientData!.priceCategories
            .indexWhere((c) => c.id == categoryId);

        if (index != -1) {
          authProvider.clientData!.priceCategories[index] = category;

          // 🔥 ОБНОВЛЯЕМ ТОВАРЫ, ЕСЛИ НУЖНО
          if (_updateExistingProducts) {
            await _updateProductsInCategory(
              authProvider,
              categoryId,
              oldPackagingQuantity,
              newPackagingQuantity,
            );
          }

          // Отправляем обновление категории на сервер
          await _apiService.updatePriceCategory(category);
        }
      } else {
        // СОЗДАНИЕ
        authProvider.clientData!.priceCategories.add(category);

        // Отправляем новую категорию на сервер
        await _apiService.createPriceCategory(category);
      }

      // Перестраиваем индексы
      authProvider.clientData!.buildIndexes();

      // Сохраняем в SharedPreferences
      await _saveToPrefs(authProvider);

      if (mounted) {
        Navigator.pop(context, true);
        _showSnackBar(
          widget.category != null ? 'Категория обновлена' : 'Категория создана',
          Colors.green,
        );
      }
    } catch (e) {
      print('❌ Ошибка сохранения категории: $e');
      if (mounted) {
        _showSnackBar('Ошибка сохранения: $e', Colors.red);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
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

  @override
  Widget build(BuildContext context) {
    // Получаем количество товаров в категории (для предупреждения)
    int productsCount = 0;
    if (widget.category != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      productsCount = authProvider.clientData?.products
              .where((p) => p.categoryId == widget.category!.id)
              .length ??
          0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category != null
              ? 'Редактировать категорию'
              : 'Новая категория',
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
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Название категории *',
                                prefixIcon: const Icon(Icons.category),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Обязательное поле';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Параметры упаковки
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
                              'Параметры упаковки',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 24),
                            TextFormField(
                              controller: _packagingQuantityController,
                              decoration: InputDecoration(
                                labelText: 'Фасовка в таре (шт) *',
                                prefixIcon: const Icon(Icons.inventory),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Обязательное поле';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Введите целое число';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _packagingNameController,
                              decoration: InputDecoration(
                                labelText: 'Тара *',
                                prefixIcon: const Icon(Icons.inbox),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Обязательное поле';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Вес и единицы
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _weightController,
                                    decoration: InputDecoration(
                                      labelText: 'Вес *',
                                      prefixIcon:
                                          const Icon(Icons.monitor_weight),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Обязательное поле';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Неверный формат';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _unitController,
                                    decoration: InputDecoration(
                                      labelText: 'Ед. изм. *',
                                      prefixIcon: const Icon(Icons.straighten),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Обязательное поле';
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

                    // Издержки
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
                              controller: _wastePercentageController,
                              decoration: InputDecoration(
                                labelText: 'Издержки (%) *',
                                prefixIcon: const Icon(Icons.percent),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Обязательное поле';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Введите целое число';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Предупреждение при редактировании
                    if (widget.category != null && productsCount > 0) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange[800],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Внимание!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'В этой категории $productsCount товаров. '
                                'Изменение фасовки автоматически обновит '
                                'кратность всех товаров категории.',
                                style: TextStyle(color: Colors.orange[800]),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _updateExistingProducts,
                                    onChanged: (value) {
                                      setState(() {
                                        _updateExistingProducts = value ?? true;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Обновить кратность существующих товаров',
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Кнопки
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveCategory,
                            icon: const Icon(Icons.save),
                            label: Text(
                              widget.category != null ? 'Сохранить' : 'Создать',
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
