// lib/screens/price_list_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/composition.dart';
import '../models/nutrition_info.dart';
import '../models/storage_condition.dart';
import '../models/product.dart';
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
  _PriceListManagementScreenState createState() =>
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

  final Map<String, bool> _exportFields = {
    'basic': true,
    'composition': true,
    'nutrition': true,
    'storage': true,
    'photos': false,
  };

  // 🔥 ЛОКАЛЬНОЕ СОСТОЯНИЕ (ЧЕРНОВИК)
  List<Product> _draftProducts = []; // Локальная копия для редактирования
  final Set<String> _modifiedProductIds = {}; // ID измененных товаров
  final Set<String> _deletedProductIds = {}; // ID удаленных товаров
  List<Product> _createdProducts = []; // Новые товары (без серверного ID)

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

    final categories = serverProducts
        .map((p) => p.categoryName)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _categories = categories;
      // 🔥 Инициализируем черновик глубокой копией серверных данных
      _draftProducts = serverProducts
          .map((p) => Product(
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
                categoryName: p.categoryName,
                wastePercentage: p.wastePercentage,
                displayName: p.displayName,
              ))
          .toList();

      _modifiedProductIds.clear();
      _deletedProductIds.clear();
      _createdProducts.clear();
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
    // Фильтруем ЧЕРНОВИК, исключая удаленные локально товары
    _filteredProducts = _draftProducts.where((product) {
      if (_deletedProductIds.contains(product.id))
        return false; // 🔥 Скрываем удаленные

      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery) ||
          product.displayName.toLowerCase().contains(_searchQuery) ||
          product.categoryName.toLowerCase().contains(_searchQuery);

      final matchesCategory = _selectedCategory == null ||
          product.categoryName == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    _filteredProducts.sort((a, b) {
      final catCompare = a.categoryName.compareTo(b.categoryName);
      if (catCompare != 0) return catCompare;
      return a.displayName.compareTo(b.displayName);
    });
  }

  // ==========================================
  // 🔥 ЛОКАЛЬНЫЕ ОПЕРАЦИИ (БЕЗ ОБРАЩЕНИЯ К СЕРВЕРУ)
  // ==========================================

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
        _modifiedProductIds
            .remove(product.id); // Если удалили, не нужно обновлять
      } else {
        // Это новый товар, удаляем из списка созданных
        _createdProducts.removeWhere((p) => p == product);
      }
      _applyFilters(); // Обновляем список, чтобы товар исчез с экрана
    });
  }

  void _localAddOrUpdateProduct(Product product) {
    setState(() {
      if (product.id.isEmpty) {
        // Это новый товар
        _createdProducts.add(product);
        _draftProducts.add(product);
      } else {
        // Обновление существующего в черновике
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

  // ==========================================
  // 🔥 ОТПРАВКА ИЗМЕНЕНИЙ НА СЕРВЕР
  // ==========================================

  Future<void> _publishChanges() async {
    if (!_hasLocalChanges) return;

    setState(() => _isLoading = true);

    try {
      final success = await _apiService.batchOperations(
        created: _createdProducts.isNotEmpty ? _createdProducts : null,
        updated: _modifiedProductIds.isNotEmpty
            ? _draftProducts
                .where((p) => _modifiedProductIds.contains(p.id))
                .toList()
            : null,
        deleted:
            _deletedProductIds.isNotEmpty ? _deletedProductIds.toList() : null,
      );

      if (success) {
        // Синхронизируем локальный стейт с сервером
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.clientData!.products.clear();
        authProvider.clientData!.products.addAll(_draftProducts);
        // Удаляем удаленные товары из связанных таблиц
        for (var id in _deletedProductIds) {
          authProvider.clientData!.compositions
              .removeWhere((c) => c.entityId == id);
          authProvider.clientData!.nutritionInfos
              .removeWhere((n) => n.priceListId == id);
        }
        authProvider.clientData!.buildIndexes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Изменения опубликованы: +${_createdProducts.length} ~${_modifiedProductIds.length} 🗑${_deletedProductIds.length}'),
            backgroundColor: Colors.green,
          ));
        }
        _loadPriceList(); // Сбрасываем счетчики изменений
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

  // ==========================================
  // Вспомогательные методы (UI)
  // ==========================================

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
          return StatefulBuilder(builder: (context, setDialogState) {
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
                    Row(children: [
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
                    ]),
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
                  ]),
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
          });
        });
  }

  void _showExportDialog() {
    String selectedFormat = 'pdf';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Экспорт прайс-листа'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => selectedFormat = 'pdf'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: selectedFormat == 'pdf'
                                ? Colors.blue
                                : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedFormat == 'pdf'
                            ? Colors.blue.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: Radio<String>(
                                  value: 'pdf',
                                  groupValue: selectedFormat,
                                  onChanged: (value) =>
                                      setState(() => selectedFormat = value!))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text(
                                    'PDF — полная информация о продукции',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Для каталогов, презентаций, печати',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                              ])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => selectedFormat = 'csv'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: selectedFormat == 'csv'
                                ? Colors.blue
                                : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedFormat == 'csv'
                            ? Colors.blue.withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: Radio<String>(
                                  value: 'csv',
                                  groupValue: selectedFormat,
                                  onChanged: (value) =>
                                      setState(() => selectedFormat = value!))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('CSV — для этикеток и систем учета',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Только структурированные данные',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                              ])),
                        ],
                      ),
                    ),
                  ),
                  if (selectedFormat == 'pdf') ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      title: const Text('Что включить в PDF'),
                      initiallyExpanded: true,
                      children: [
                        CheckboxListTile(
                            title: const Text('Основные поля'),
                            value: _exportFields['basic'] ?? true,
                            onChanged: (value) => setState(
                                () => _exportFields['basic'] = value ?? true)),
                        CheckboxListTile(
                            title: const Text('Состав'),
                            value: _exportFields['composition'] ?? true,
                            onChanged: (value) => setState(() =>
                                _exportFields['composition'] = value ?? true)),
                        CheckboxListTile(
                            title: const Text('КБЖУ'),
                            value: _exportFields['nutrition'] ?? true,
                            onChanged: (value) => setState(() =>
                                _exportFields['nutrition'] = value ?? true)),
                        CheckboxListTile(
                            title: const Text('Условия хранения'),
                            value: _exportFields['storage'] ?? true,
                            onChanged: (value) => setState(() =>
                                _exportFields['storage'] = value ?? true)),
                        CheckboxListTile(
                            title: const Text('Фотографии'),
                            value: _exportFields['photos'] ?? false,
                            onChanged: (value) => setState(() =>
                                _exportFields['photos'] = value ?? false)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Отмена')),
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _exportPriceList(selectedFormat);
                  },
                  child: const Text('Экспортировать')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportPriceList(String format) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final products = _filteredProducts;
      final clientData = authProvider.clientData!;

      final compositionsByProduct = <String, List<Composition>>{};
      final nutritionByProduct = <String, NutritionInfo>{};
      final storageByProduct = <String, StorageCondition>{};

      for (var product in products) {
        compositionsByProduct[product.id] = clientData.compositions
            .where((c) => c.sheetName == 'Состав' && c.entityId == product.id)
            .toList();
        try {
          nutritionByProduct[product.id] = clientData.nutritionInfos
              .firstWhere((n) => n.priceListId == product.id);
        } catch (e) {}
        try {
          storageByProduct[product.id] = clientData.storageConditions
              .firstWhere(
                  (s) => s.level == 'Прайс-лист' && s.entityId == product.id);
        } catch (e) {}
      }

      _exportService.format = format;
      _exportService.includeBasic = _exportFields['basic'] ?? true;
      _exportService.includeComposition = _exportFields['composition'] ?? true;
      _exportService.includeNutrition = _exportFields['nutrition'] ?? true;
      _exportService.includeStorage = _exportFields['storage'] ?? true;
      _exportService.includePhotos = _exportFields['photos'] ?? false;

      if (!mounted) return;

      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Генерация файла...')
              ])));

      final file = await _exportService.generatePriceList(
          products: products,
          clientName: 'Администратор',
          clientPhone: '',
          compositionsByProduct: compositionsByProduct,
          nutritionByProduct: nutritionByProduct,
          storageByProduct: storageByProduct);

      if (mounted) Navigator.of(context).pop();

      if (file != null && mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'Прайс-лист');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Файл создан: ${file.path.split('/').last}'),
            duration: const Duration(seconds: 3)));
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка экспорта: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          !_hasLocalChanges, // 🔥 Блокировка системной кнопки "Назад" при изменениях
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Показываем диалог предупреждения
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Несохраненные изменения'),
            content: const Text(
                'У вас есть несохраненные изменения. Вы уверены, что хотите выйти? Изменения будут потеряны.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child:
                      const Text('Выйти', style: TextStyle(color: Colors.red))),
            ],
          ),
        );

        if (shouldDiscard == true && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title),
              if (_hasLocalChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      '${_modifiedProductIds.length + _createdProducts.length + _deletedProductIds.length}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.category),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminPriceCategoriesScreen())),
                tooltip: 'Категории'),
            IconButton(
                icon: const Icon(Icons.price_change_outlined),
                onPressed: _showMassPriceChangeDialog,
                tooltip: 'Изменить цены'),
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPriceList,
                tooltip: 'Сбросить/Обновить'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final emptyPriceItem = PriceItem(
                    id: '',
                    name: '',
                    price: 0,
                    category: '',
                    categoryId: '', // 👈 Добавлено
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
                    id: '', name: result.name, price: result.price,
                    categoryName: result.category,
                    multiplicity: result.multiplicity,
                    composition: result.description ?? '',
                    imageUrl: result.photoUrl,
                    // Остальные поля дефолтные
                    weight: '', nutrition: '', storage: '', packaging: '',
                    wastePercentage: 10, displayName: result.name,
                    categoryId: '', imageBase64: null,
                  ));
                }
              },
              tooltip: 'Добавить позицию',
            ),
            IconButton(
                icon: const Icon(Icons.share),
                onPressed: _showExportDialog,
                tooltip: 'Экспортировать'),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                      decoration: InputDecoration(
                          hintText: 'Поиск товаров или категории...',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ]),
          ),
        ),
        // 🔥 ПЛАВАЮЩАЯ КНОПКА ОТПРАВКИ
        floatingActionButton: _hasLocalChanges
            ? FloatingActionButton.extended(
                onPressed: _isLoading ? null : _publishChanges,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white))
                    : const Icon(Icons.cloud_upload),
                label: Text(_isLoading ? 'Публикация...' : 'Опубликовать'),
                backgroundColor: Colors.green,
              )
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
                        Text(
                            _searchQuery.isNotEmpty || _selectedCategory != null
                                ? 'Ничего не найдено'
                                : 'Нет товаров',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600]))
                      ]))
                : ListView.builder(
                    padding:
                        const EdgeInsets.only(bottom: 80), // Отступ под FAB
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
                            if (showCategoryHeader)
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8, top: 16, bottom: 8),
                                  child: Text(product.categoryName,
                                      style: TextStyle(
                                          color: Colors.blue.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14))),
                            _buildProductCard(product, isModified),
                          ]);
                    },
                  ),
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isModified) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isModified
            ? const BorderSide(color: Colors.orange, width: 1)
            : BorderSide.none, // 🔥 Подсветка измененных
      ),
      child: InkWell(
        onTap: () => _navigateToEdit(product),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: [
            Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8)),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildProductImage(product))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(product.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(product.categoryName ?? 'Без категории',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${product.price.toStringAsFixed(0)} ₽',
                  style: const TextStyle(
                      fontFamily: 'Lora',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87)),
              if (product.multiplicity > 1)
                Text('×${product.multiplicity} шт',
                    style: const TextStyle(
                        fontFamily: 'Lora', fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(width: 4),
            Column(children: [
              IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 20, color: Colors.blue.shade700),
                  onPressed: () => _navigateToEdit(product),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36)),
              IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: Colors.red.shade400),
                  onPressed: () => _localDeleteItem(product),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36)),
            ]),
          ]),
        ),
      ),
    );
  }

  void _navigateToEdit(Product product) async {
    final priceItem = PriceItem(
      id: product.id,
      name: product.name,
      price: product.price,
      category: product.categoryName,
      categoryId: product.categoryId, // 👈 Добавлено
      unit: 'шт',
      weight: double.tryParse(product.weight) ?? 0.0,
      multiplicity: product.multiplicity,
      photoUrl: product.imageUrl,
      description: product.composition,
    );

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
        imageBase64: null,
      ));
    }
  }
}
