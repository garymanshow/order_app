// lib/screens/price_list_management_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/nutrition_info.dart';
import '../models/storage_condition.dart';
import '../models/product.dart';
import '../models/price_category.dart';
import '../models/price_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import 'admin/admin_price_item_form_screen.dart';
import 'admin/admin_price_categories_screen.dart';

class PriceListManagementScreen extends StatefulWidget {
  final String title;

  const PriceListManagementScreen({
    super.key,
    this.title = 'Управление прайс-листом',
  });

  @override
  State<PriceListManagementScreen> createState() =>
      _PriceListManagementScreenState();
}

class _PriceListManagementScreenState extends State<PriceListManagementScreen> {
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  String? _selectedCategory;
  List<String> _categories = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  final ExportService _exportService = ExportService();

  // 🔥 НАСТРОЙКИ ЭКСПОРТА
  bool _expBasic = true;
  bool _expComposition = true;
  bool _expNutrition = true;
  bool _expStorage = true;
  bool _expPhotos = false;

  // 🔥 ФОРМИРОВАНИЕ ЦЕНЫ
  double _expMarkupPercent = 0;
  double _expDiscountPercent = 0;
  int _expRoundToNearest = 0;

  final Set<String> _modifiedCategoryIds = {};
  final Set<String> _deletedCategoryIds = {};

  List<Product> _draftProducts = [];
  final Set<String> _modifiedProductIds = {};
  final Set<String> _deletedProductIds = {};
  final List<Product> _createdProducts = [];

  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  bool get _hasLocalChanges =>
      _modifiedProductIds.isNotEmpty ||
      _deletedProductIds.isNotEmpty ||
      _createdProducts.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadPriceList();
  }

  void _loadPriceList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.clientData == null) return;

    final serverProducts = authProvider.clientData!.products;
    final categories = authProvider.clientData!.priceCategories;

    final categoryNames = <String, String>{};
    for (var cat in categories) {
      categoryNames[cat.id.toString()] = cat.name;
    }

    final categoryTitles = serverProducts
        .map((p) => p.categoryName)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _categories = categoryTitles;

      _draftProducts = serverProducts.map((p) {
        String realCategoryName = p.categoryName;
        if (realCategoryName.isEmpty && p.categoryId.isNotEmpty) {
          realCategoryName = categoryNames[p.categoryId] ?? '';
        }
        return Product(
          id: p.id,
          name: p.name,
          price: p.price,
          multiplicity: p.multiplicity,
          categoryId: p.categoryId,
          imageUrl: p.imageUrl,
          imageBase64: p.imageBase64,
          composition: p.composition,
          weight: p.weight,
          nutrition: p.nutrition,
          storage: p.storage,
          packaging: p.packaging,
          categoryName: realCategoryName,
          wastePercentage: p.wastePercentage,
          displayName: p.displayName,
        );
      }).toList();

      _modifiedProductIds.clear();
      _deletedProductIds.clear();
      _createdProducts.clear();
      _modifiedCategoryIds.clear();
      _deletedCategoryIds.clear();
    });

    _applyFilters();
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyFilters();
    });
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allCategories = authProvider.clientData?.priceCategories ?? [];
    final categoryOrderMap = <String, int>{};
    for (var i = 0; i < allCategories.length; i++) {
      categoryOrderMap[allCategories[i].id.toString()] = i;
    }

    _filteredProducts = _draftProducts.where((product) {
      if (_deletedProductIds.contains(product.id)) return false;
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery) ||
          product.displayName.toLowerCase().contains(_searchQuery) ||
          product.categoryName.toLowerCase().contains(_searchQuery);
      final matchesCategory = _selectedCategory == null ||
          product.categoryName == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    _filteredProducts.sort((a, b) {
      final orderA = categoryOrderMap[a.categoryId] ?? 9999;
      final orderB = categoryOrderMap[b.categoryId] ?? 9999;
      final catCompare = orderA.compareTo(orderB);
      if (catCompare != 0) return catCompare;
      return a.displayName.compareTo(b.displayName);
    });
  }

  void _markAsModified(Product product) {
    if (product.id.isNotEmpty && !_modifiedProductIds.contains(product.id)) {
      setState(() {
        _modifiedProductIds.add(product.id);
      });
    }
  }

  void _localDeleteItem(Product product) {
    setState(() {
      if (product.id.isNotEmpty) {
        _deletedProductIds.add(product.id);
        _modifiedProductIds.remove(product.id);
      } else {
        _createdProducts.removeWhere((p) => p == product);
      }
      _applyFilters();
    });
  }

  void _localAddOrUpdateProduct(Product product) {
    setState(() {
      if (product.id.isEmpty) {
        _createdProducts.add(product);
        _draftProducts.add(product);
      } else {
        final index = _draftProducts.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          _draftProducts[index] = product;
          _markAsModified(product);
        }
      }
      _applyFilters();
    });
  }

  void _localApplyMassPriceChange(String mode, double value, bool roundUp) {
    for (var product in _filteredProducts) {
      double newPrice = product.price;
      if (mode == 'percent') {
        newPrice = product.price * (1 + value / 100);
      } else {
        newPrice = product.price + value;
      }
      if (roundUp) newPrice = newPrice.ceilToDouble();
      if (newPrice < 0) newPrice = 0;

      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        price: newPrice,
        multiplicity: product.multiplicity,
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

      final index = _draftProducts.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _draftProducts[index] = updatedProduct;
        _markAsModified(updatedProduct);
      }
    }
    _applyFilters();
  }

  Future<void> _publishChanges() async {
    if (!_hasLocalChanges) return;
    setState(() => _isLoading = true);
    try {
      bool success = true;
      final hasProductChanges = _modifiedProductIds.isNotEmpty ||
          _deletedProductIds.isNotEmpty ||
          _createdProducts.isNotEmpty;
      if (hasProductChanges) {
        final productSuccess = await _apiService.batchOperations(
          created: _createdProducts.isNotEmpty ? _createdProducts : null,
          updated: _modifiedProductIds.isNotEmpty
              ? _draftProducts
                  .where((p) => _modifiedProductIds.contains(p.id))
                  .toList()
              : null,
          deleted: _deletedProductIds.isNotEmpty
              ? _deletedProductIds.toList()
              : null,
        );
        if (!productSuccess) success = false;
      }

      if (success) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.clientData!.products.clear();
        authProvider.clientData!.products.addAll(_draftProducts);
        for (var id in _deletedProductIds) {
          authProvider.clientData!.compositions
              .removeWhere((c) => c.entityId == id);
          authProvider.clientData!.nutritionInfos
              .removeWhere((n) => n.priceListId == id);
          authProvider.clientData!.storageConditions
              .removeWhere((s) => s.entityId == id);
          authProvider.clientData!.transportConditions
              .removeWhere((t) => t.entityId == id);
        }
        authProvider.clientData!.buildIndexes();
        await authProvider.saveToCache();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Изменения сохранены'),
              backgroundColor: Colors.green));
        }
        setState(() {
          _deletedProductIds.clear();
          _modifiedProductIds.clear();
          _createdProducts.clear();
        });
        _applyFilters();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ошибка публикации на сервере'),
              backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getImagePath(Product product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
      return product.imageUrl!;
    return 'assets/images/products/${product.id}.webp';
  }

  Widget _buildProductImage(Product product) {
    final imagePath = _getImagePath(product);
    if (imagePath.startsWith('http')) {
      return Image.network(imagePath,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildPlaceholderImage(product));
    }
    return Image.asset(imagePath,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildPlaceholderImage(product));
  }

  Widget _buildPlaceholderImage(Product product) {
    return Container(
        color: Colors.grey[300],
        child: Center(
            child: Text(product.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey))));
  }

  void _showMassPriceChangeDialog() {
    if (_filteredProducts.isEmpty) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        String mode = 'percent';
        double value = 0;
        bool roundUp = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Массовое изменение цены'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Будет изменено позиций: ${_filteredProducts.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 16),
                  const Text('Тип изменения:'),
                  Row(
                    children: [
                      ChoiceChip(
                          label: const Text('На %'),
                          selected: mode == 'percent',
                          onSelected: (_) =>
                              setDialogState(() => mode = 'percent')),
                      const SizedBox(width: 8),
                      ChoiceChip(
                          label: const Text('На сумму ₽'),
                          selected: mode == 'amount',
                          onSelected: (_) =>
                              setDialogState(() => mode = 'amount')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: InputDecoration(
                          labelText: mode == 'percent' ? 'Процент' : 'Сумма',
                          border: const OutlineInputBorder()),
                      onChanged: (val) => value =
                          double.tryParse(val.replaceAll(',', '.')) ?? 0),
                  SwitchListTile(
                      title: const Text('Округлить в свою пользу'),
                      value: roundUp,
                      onChanged: (val) => setDialogState(() => roundUp = val),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _localApplyMassPriceChange(mode, value, roundUp);
                    },
                    child: const Text('Применить локально')),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ДИАЛОГ ЭКСПОРТА
  // ==========================================
  void _showExportDialog() {
    String selectedFormat = 'pdf';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('📄 Экспорт прайс-листа'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormatOption(
                        setDialogState,
                        selectedFormat,
                        'pdf',
                        'PDF — полная информация',
                        'Для каталогов, презентаций, печати',
                        (v) => setDialogState(() => selectedFormat = v)),
                    const SizedBox(height: 8),
                    _buildFormatOption(
                        setDialogState,
                        selectedFormat,
                        'csv',
                        'CSV — для этикеток и учёта',
                        'Только структурированные данные',
                        (v) => setDialogState(() => selectedFormat = v)),
                    if (selectedFormat == 'pdf') ...[
                      const SizedBox(height: 16), const Divider(),
                      const SizedBox(height: 8),
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Что включить в PDF',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(height: 8),
                      _buildCheckbox(setDialogState, 'Основные поля', _expBasic,
                          (v) {
                        _expBasic = v ?? true;
                        setDialogState(() {});
                      }),
                      _buildCheckbox(setDialogState, 'Состав', _expComposition,
                          (v) {
                        _expComposition = v ?? true;
                        setDialogState(() {});
                      }),
                      _buildCheckbox(setDialogState, 'КБЖУ', _expNutrition,
                          (v) {
                        _expNutrition = v ?? true;
                        setDialogState(() {});
                      }),
                      _buildCheckbox(
                          setDialogState, 'Условия хранения', _expStorage, (v) {
                        _expStorage = v ?? true;
                        setDialogState(() {});
                      }), // ИСПРАВЛЕНО ЗДЕСЬ
                      Column(
                        children: [
                          _buildCheckbox(setDialogState,
                              '📷 Фотографии товаров', _expPhotos, (v) {
                            _expPhotos = v ?? false;
                            if (_expPhotos && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          '⏱️ Фото увеличат время генерации'),
                                      duration: Duration(seconds: 3),
                                      backgroundColor: Color(0xFF5D4037)));
                            }
                            setDialogState(() {});
                          }),
                          if (_expPhotos)
                            Padding(
                                padding:
                                    const EdgeInsets.only(left: 48, bottom: 8),
                                child: Text('• Загрузка фото: +10-30 сек',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic))),
                        ],
                      ),

                      // 🔥 ФОРМИРОВАНИЕ ЦЕНЫ
                      const SizedBox(height: 16), const Divider(),
                      const SizedBox(height: 8),
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Формирование цены',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037)))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: TextField(
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Наценка %',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8)),
                                  onChanged: (val) => setDialogState(() =>
                                      _expMarkupPercent = double.tryParse(
                                              val.replaceAll(',', '.')) ??
                                          0))),
                          const SizedBox(width: 16),
                          Expanded(
                              child: TextField(
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Скидка %',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8)),
                                  onChanged: (val) => setDialogState(() =>
                                      _expDiscountPercent = double.tryParse(
                                              val.replaceAll(',', '.')) ??
                                          0))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _expRoundToNearest,
                        decoration: const InputDecoration(
                            labelText: 'Округлить до',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(
                              value: 0, child: Text('Без округления')),
                          DropdownMenuItem(
                              value: 5, child: Text('До 5 ₽ (115, 120...)')),
                          DropdownMenuItem(
                              value: 10, child: Text('До 10 ₽ (110, 120...)')),
                          DropdownMenuItem(
                              value: 50, child: Text('До 50 ₽ (150, 200...)')),
                          DropdownMenuItem(
                              value: 100,
                              child: Text('До 100 ₽ (200, 300...)')),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => _expRoundToNearest = val ?? 0),
                      ),
                      const SizedBox(height: 8),
                      if (_expMarkupPercent > 0 ||
                          _expDiscountPercent > 0 ||
                          _expRoundToNearest > 0)
                        Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                '💡 Формула: Базовая × ${1 + _expMarkupPercent / 100} × ${1 - _expDiscountPercent / 100}${_expRoundToNearest > 0 ? ', округлить вверх до $_expRoundToNearest ₽' : ''}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[900],
                                    fontStyle: FontStyle.italic))),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Отмена')),
              ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _exportPriceList(context, _filteredProducts,
                        format: selectedFormat);
                  },
                  icon: const Icon(Icons.file_download),
                  label: const Text('Экспортировать')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormatOption(
      StateSetter setState,
      String currentFormat,
      String value,
      String title,
      String subtitle,
      ValueChanged<String> onSelect) {
    final isSelected = currentFormat == value;
    return InkWell(
      onTap: () => onSelect(value), // Вызываем коллбэк
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF5D4037)
                    : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? const Color(0xFF5D4037).withValues(alpha: 0.1)
                : null),
        child: Row(children: [
          SizedBox(
              width: 20,
              height: 20,
              child: Radio<String>(
                  value: value,
                  groupValue: currentFormat,
                  onChanged: (v) {
                    if (v != null) onSelect(v);
                  }, // Вызываем коллбэк
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: const Color(0xFF5D4037))),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ])),
        ]),
      ),
    );
  }

  Widget _buildCheckbox(StateSetter setState, String title, bool value,
      ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF5D4037),
        contentPadding: EdgeInsets.zero);
  }

  // ==========================================
  // ЛОГИКА ЭКСПОРТА
  // ==========================================
  String _normalizeText(String input) {
    if (input.trim().isEmpty) return '';
    String text = input.trim();
    text = text[0].toUpperCase() + text.substring(1);
    while (text.endsWith('.')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return '$text.';
  }

  Future<void> _exportPriceList(BuildContext context, List<Product> products,
      {required String format}) async {
    _scaffoldKey.currentState?.showSnackBar(
      const SnackBar(
          content: Text('⏳ Файл формируется...'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.blueGrey),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final client = authProvider.currentUser;
      final clientData = authProvider.clientData;

      final nutritionByProduct = <String, NutritionInfo>{};
      final storageByProduct = <String, List<StorageCondition>>{};
      final compositionStringsByProduct = <String, String>{};

      if (clientData != null) {
        final categoriesMap = <String, PriceCategory>{};
        for (var cat in clientData.priceCategories) {
          categoriesMap[cat.id.toString()] = cat;
        }

        for (var product in products) {
          final String pId = product.id;
          final String cId = product.categoryId;

          // 1. КБЖУ — ИСПРАВЛЕНО: ищем по точному строковому совпадению ID
          try {
            final nut = clientData.nutritionInfos.firstWhere(
              (n) => (n.priceListId ?? '').toString() == pId,
            );
            nutritionByProduct[pId] = nut;
          } catch (_) {}

          // 2. Условия хранения
          final storages = clientData.storageConditions
              .where((s) => s.level == 'Категории прайса' && s.entityId == cId)
              .toList();
          if (storages.isNotEmpty) {
            storageByProduct[pId] = storages;
          }

          // 3. ФОРМИРОВАНИЕ СОСТАВА (ИСПРАВЛЕНО: Правильная связь ID сущностей)
          final compositionParts = <String>[];

          // Получаем все начинки для данной категории
          final fillings = clientData.compositions
              .where(
                  (c) => c.sheetName == 'Категории прайса' && c.entityId == cId)
              .toList();

          for (var filling in fillings) {
            // ИСПРАВЛЕНО: Ищем ингредиенты начинки по entityId, равному ID самой начинки
            final fillingIngredients = clientData.compositions
                .where((c) =>
                    c.sheetName == 'Начинки' &&
                    c.entityId == filling.id.toString())
                .map((i) => i.displayName.trim().toLowerCase())
                .toList();

            // Формируем красивый вывод: "Название начинки: ингр1, ингр2"
            if (fillingIngredients.isNotEmpty) {
              final fillingName =
                  _normalizeText(filling.displayName).replaceAll('.', '');
              compositionParts
                  .add('$fillingName: ${fillingIngredients.join(', ')}');
            } else {
              compositionParts
                  .add(_normalizeText(filling.displayName).replaceAll('.', ''));
            }
          }

          // Прямые ингредиенты из прайс-листа (джемы, глазурь и тд)
          final directIngredients = clientData.compositions
              .where((c) => c.sheetName == 'Прайс-лист' && c.entityId == pId)
              .map((i) => _normalizeText(i.displayName).replaceAll('.', ''))
              .toList();

          if (directIngredients.isNotEmpty) {
            compositionParts.addAll(directIngredients);
          }

          if (compositionParts.isNotEmpty) {
            String rawComp = compositionParts.join('. ');
            compositionStringsByProduct[pId] = _normalizeText(rawComp);
          }
        }
      }

      _exportService.format = format;
      _exportService.includeBasic = _expBasic;
      _exportService.includeComposition = _expComposition;
      _exportService.includeNutrition = _expNutrition;
      _exportService.includeStorage = _expStorage;
      _exportService.includePhotos = _expPhotos;

      _exportService.markupPercent = _expMarkupPercent;
      _exportService.discountPercent = _expDiscountPercent;
      _exportService.roundToNearest = _expRoundToNearest;

      final result = await _exportService.generatePriceList(
        products: products,
        clientName: client?.name ?? 'Менеджер',
        clientPhone: client?.phone ?? '',
        categories: clientData?.priceCategories ?? [],
        compositionsByProduct: compositionStringsByProduct,
        nutritionByProduct: nutritionByProduct,
        storageByProduct: storageByProduct,
      );

      if (result != null && mounted) {
        if (kIsWeb) {
          final fileName =
              'price_list_${DateTime.now().millisecondsSinceEpoch}.$format';
          html.Blob blob;

          if (result is html.Blob) {
            blob = result as html.Blob;
          } else if (result is Uint8List) {
            blob = html.Blob([result]);
          } else {
            try {
              blob = html.Blob([Uint8List.fromList(result as List<int>)]);
            } catch (e) {
              blob = html.Blob([result]);
            }
          }

          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..style.display = 'none';
          html.document.body?.children.add(anchor);
          anchor.click();

          Future.delayed(const Duration(seconds: 2), () {
            html.Url.revokeObjectUrl(url);
            anchor.remove();
          });

          _scaffoldKey.currentState?.hideCurrentSnackBar();
          _scaffoldKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('✅ Файл готов: $fileName'),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'Скачать вручную',
                textColor: Colors.white,
                onPressed: () => html.window.open(url, '_blank'),
              ),
            ),
          );
        } else {
          final file = result as File;
          await SharePlus.instance
              .share(ShareParams(files: [XFile(file.path)]));

          _scaffoldKey.currentState?.hideCurrentSnackBar();
          _scaffoldKey.currentState?.showSnackBar(const SnackBar(
              content: Text('✅ Файл создан'), backgroundColor: Colors.green));
        }
      } else if (mounted) {
        throw Exception('Ошибка генерации');
      }
    } catch (e) {
      if (mounted) {
        _scaffoldKey.currentState?.hideCurrentSnackBar();
        _scaffoldKey.currentState?.showSnackBar(SnackBar(
            content: Text('❌ Ошибка: $e'), backgroundColor: Colors.red[700]));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasLocalChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Несохраненные изменения'),
                    content: const Text(
                        'У вас есть несохраненные изменения. Выйти?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Выйти',
                              style: TextStyle(color: Colors.red))),
                    ]));
        if (shouldDiscard == true && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.title),
            if (_hasLocalChanges) ...[
              const SizedBox(width: 8),
              Tooltip(
                  message:
                      'Изменений: ${_modifiedProductIds.length + _createdProducts.length + _deletedProductIds.length}',
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          '${_modifiedProductIds.length + _createdProducts.length + _deletedProductIds.length}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)))),
            ],
          ]),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPriceList,
                tooltip: 'Сбросить изменения'),
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final emptyPriceItem = PriceItem(
                      id: '',
                      name: '',
                      price: 0,
                      category: '',
                      categoryId: '',
                      unit: 'шт',
                      weight: 0,
                      multiplicity: 1,
                      photoUrl: null,
                      description: null);
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              AdminPriceItemFormScreen(item: emptyPriceItem)));
                  if (result == true && result is PriceItem) {
                    _localAddOrUpdateProduct(Product(
                        id: '',
                        name: result.name,
                        price: result.price,
                        categoryName: result.category,
                        multiplicity: result.multiplicity,
                        composition: result.description ?? '',
                        imageUrl: result.photoUrl,
                        weight: '',
                        nutrition: '',
                        storage: '',
                        packaging: '',
                        wastePercentage: 10,
                        displayName: result.name,
                        categoryId: '',
                        imageBase64: null));
                  }
                },
                tooltip: 'Добавить позицию'),
            PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Дополнительно',
                onSelected: (choice) {
                  if (choice == 'price') _showMassPriceChangeDialog();
                  if (choice == 'export') _showExportDialog();
                },
                itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'price',
                          child: ListTile(
                              leading: Icon(Icons.price_change),
                              title: Text('Изменить цены'))),
                      const PopupMenuItem(
                          value: 'export',
                          child: ListTile(
                              leading: Icon(Icons.share),
                              title: Text('Экспорт'))),
                    ]),
          ],
          bottom: PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                        decoration: InputDecoration(
                            hintText: 'Поиск...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0)),
                        onChanged: _filterProducts)),
                if (_categories.isNotEmpty)
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(children: [
                        FilterChip(
                            label: const Text('Все'),
                            selected: _selectedCategory == null,
                            onSelected: (_) => _filterByCategory(null),
                            backgroundColor: Colors.grey[100],
                            selectedColor: Colors.green.shade100),
                        const SizedBox(width: 8),
                        ..._categories.map((category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                                label: Text(category),
                                selected: _selectedCategory == category,
                                onSelected: (_) => _filterByCategory(category),
                                backgroundColor: Colors.grey[100],
                                selectedColor: Colors.green.shade100))),
                      ])),
              ])),
        ),
        floatingActionButton: _hasLocalChanges
            ? FloatingActionButton.extended(
                onPressed: _isLoading ? null : _publishChanges,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white))
                    : const Icon(Icons.cloud_upload),
                label:
                    Text(_isLoading ? 'Отправка...' : 'Сохранить на сервере'),
                backgroundColor: Colors.green)
            : null,
        body: _isLoading && _draftProducts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Нет товаров',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600]))
                      ]))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final showCategoryHeader = index == 0 ||
                          _filteredProducts[index - 1].categoryName !=
                              product.categoryName;
                      final isModified =
                          _modifiedProductIds.contains(product.id);

                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showCategoryHeader &&
                                product.categoryName.isNotEmpty)
                              Container(
                                  color: Colors.blue.shade50,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0, vertical: 2.0),
                                  child: Row(children: [
                                    Expanded(
                                        child: InkWell(
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const AdminPriceCategoriesScreen())),
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                    product.categoryName
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                        color: Colors
                                                            .blue.shade800,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12))))),
                                    PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert,
                                            size: 18,
                                            color: Colors.blue.shade800),
                                        tooltip: 'Действия с категорией',
                                        onSelected: (choice) {
                                          if (choice == 'edit') {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const AdminPriceCategoriesScreen()));
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                  value: 'edit',
                                                  child: ListTile(
                                                      leading: Icon(Icons.edit),
                                                      title: Text(
                                                          'Редактировать категорию'),
                                                      contentPadding:
                                                          EdgeInsets.only(
                                                              left: 0,
                                                              right: 16)))
                                            ]),
                                  ])),
                            Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 4),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: isModified
                                        ? const BorderSide(
                                            color: Colors.orange, width: 1)
                                        : BorderSide.none),
                                child: InkWell(
                                    onTap: () => _navigateToEdit(product),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                  child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: _buildProductImage(
                                                          product))),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                    if (product.categoryName
                                                        .isNotEmpty)
                                                      Text(product.categoryName,
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey
                                                                  .shade600,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis),
                                                    Text(product.displayName,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 14,
                                                            height: 1.2),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                  ])),
                                              const SizedBox(width: 8),
                                              Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                        '${product.price.toStringAsFixed(0)} ₽',
                                                        style: const TextStyle(
                                                            fontFamily: 'Lora',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                            color: Colors
                                                                .black87)),
                                                    if (product.multiplicity >
                                                        1)
                                                      Text(
                                                          '×${product.multiplicity} шт',
                                                          style:
                                                              const TextStyle(
                                                                  fontFamily:
                                                                      'Lora',
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey)),
                                                  ]),
                                              const SizedBox(width: 4),
                                              Column(children: [
                                                IconButton(
                                                    icon: Icon(
                                                        Icons.edit_outlined,
                                                        size: 20,
                                                        color: Colors
                                                            .blue.shade700),
                                                    onPressed: () =>
                                                        _navigateToEdit(
                                                            product),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                            minWidth: 36,
                                                            minHeight: 36)),
                                                IconButton(
                                                    icon: Icon(
                                                        Icons.delete_outline,
                                                        size: 20,
                                                        color: Colors
                                                            .red.shade400),
                                                    onPressed: () =>
                                                        _localDeleteItem(
                                                            product),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                            minWidth: 36,
                                                            minHeight: 36)),
                                              ]),
                                            ])))),
                          ]);
                    }),
      ),
    );
  }

  void _navigateToEdit(Product product) async {
    final priceItem = PriceItem(
        id: product.id,
        name: product.name,
        price: product.price,
        category: product.categoryName,
        categoryId: product.categoryId,
        unit: 'шт',
        weight: double.tryParse(product.weight) ?? 0.0,
        multiplicity: product.multiplicity,
        photoUrl: product.imageUrl,
        description: product.composition);
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AdminPriceItemFormScreen(item: priceItem)));
    if (result == true && result is PriceItem) {
      _localAddOrUpdateProduct(Product(
          id: result.id,
          name: result.name,
          price: result.price,
          categoryName: result.category,
          multiplicity: result.multiplicity,
          composition: result.description ?? '',
          imageUrl: result.photoUrl,
          weight: result.weight.toString(),
          nutrition: '',
          storage: '',
          packaging: '',
          wastePercentage: 10,
          displayName: result.name,
          categoryId: '',
          imageBase64: null));
    }
  }
}
