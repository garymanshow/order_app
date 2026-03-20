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
    Key? key,
    this.title = 'Управление прайс-листом',
  }) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _loadPriceList();
  }

  void _loadPriceList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.clientData == null) return;

    final products = authProvider.clientData!.products;

    final categories = products
        .map((p) => p.categoryName)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _filteredProducts = products;
      _categories = categories;
    });

    print('📊 Загружено товаров: ${products.length}');
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
    final allProducts = authProvider.clientData?.products ?? [];

    _filteredProducts = allProducts.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery) ||
          product.displayName.toLowerCase().contains(_searchQuery);

      final matchesCategory = _selectedCategory == null ||
          product.categoryName == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _getImagePath(Product product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return product.imageUrl!;
    }
    return 'assets/images/products/${product.id}.webp';
  }

  Widget _buildProductImage(Product product) {
    final imagePath = _getImagePath(product);

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(product);
        },
      );
    } else {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(product);
        },
      );
    }
  }

  Widget _buildPlaceholderImage(Product product) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Text(
          product.name.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление товара'),
        content: Text('Удалить "${product.displayName}"?'),
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

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        authProvider.clientData!.products
            .removeWhere((p) => p.id == product.id);
        authProvider.clientData!.compositions
            .removeWhere((c) => c.entityId == product.id);
        authProvider.clientData!.nutritionInfos
            .removeWhere((n) => n.priceListId == product.id);

        authProvider.clientData!.buildIndexes();

        await _apiService.deleteProduct(product.id);

        _loadPriceList();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар удален'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
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
                  // PDF option
                  InkWell(
                    onTap: () => setState(() => selectedFormat = 'pdf'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedFormat == 'pdf'
                              ? Colors.blue
                              : Colors.grey.shade300,
                        ),
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
                                  setState(() => selectedFormat = value!),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PDF — полная информация о продукции',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Для каталогов, презентаций, печати',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // CSV option
                  InkWell(
                    onTap: () => setState(() => selectedFormat = 'csv'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedFormat == 'csv'
                              ? Colors.blue
                              : Colors.grey.shade300,
                        ),
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
                                  setState(() => selectedFormat = value!),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CSV — для этикеток и систем учета',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Только структурированные данные',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                          onChanged: (value) {
                            setState(() {
                              _exportFields['basic'] = value ?? true;
                            });
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('Состав'),
                          value: _exportFields['composition'] ?? true,
                          onChanged: (value) {
                            setState(() {
                              _exportFields['composition'] = value ?? true;
                            });
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('КБЖУ'),
                          value: _exportFields['nutrition'] ?? true,
                          onChanged: (value) {
                            setState(() {
                              _exportFields['nutrition'] = value ?? true;
                            });
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('Условия хранения'),
                          value: _exportFields['storage'] ?? true,
                          onChanged: (value) {
                            setState(() {
                              _exportFields['storage'] = value ?? true;
                            });
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('Фотографии'),
                          value: _exportFields['photos'] ?? false,
                          onChanged: (value) {
                            setState(() {
                              _exportFields['photos'] = value ?? false;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _exportPriceList(selectedFormat);
                },
                child: const Text('Экспортировать'),
              ),
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
              .firstWhere((s) =>
                  s.sheetName == 'Прайс-лист' && s.entityId == product.id);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Генерация файла...'),
            ],
          ),
        ),
      );

      final file = await _exportService.generatePriceList(
        products: products,
        clientName: 'Администратор',
        clientPhone: '',
        compositionsByProduct: compositionsByProduct,
        nutritionByProduct: nutritionByProduct,
        storageByProduct: storageByProduct,
      );

      if (mounted) Navigator.of(context).pop();

      if (file != null && mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Прайс-лист',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл создан: ${file.path.split('/').last}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка экспорта: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // 🔥 ИСПРАВЛЕНО: убран const
                  builder: (_) => AdminPriceCategoriesScreen(),
                ),
              );
            },
            tooltip: 'Категории',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPriceList,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              // 🔥 ИСПРАВЛЕНО: создаем пустой priceItem
              final emptyPriceItem = PriceItem(
                id: '',
                name: '',
                price: 0,
                category: '',
                unit: 'шт',
                weight: 0,
                multiplicity: 1,
                photoUrl: null,
                description: null,
              );

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AdminPriceItemFormScreen(item: emptyPriceItem),
                ),
              );
              if (result == true) {
                _loadPriceList();
              }
            },
            tooltip: 'Добавить позицию',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showExportDialog,
            tooltip: 'Экспортировать',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Поиск товаров...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _filterProducts,
                ),
              ),
              if (_categories.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Все'),
                        selected: _selectedCategory == null,
                        onSelected: (_) => _filterByCategory(null),
                        backgroundColor: Colors.grey[100],
                        selectedColor: Colors.green.shade100,
                      ),
                      const SizedBox(width: 8),
                      ..._categories.map((category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              onSelected: (_) => _filterByCategory(category),
                              backgroundColor: Colors.grey[100],
                              selectedColor: Colors.green.shade100,
                            ),
                          )),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _selectedCategory != null
                            ? 'Ничего не найдено'
                            : 'Нет товаров',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return _buildProductCard(product);
                  },
                ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final priceItem = PriceItem(
            id: product.id,
            name: product.name,
            price: product.price,
            category: product.categoryName,
            unit: 'шт',
            weight: double.tryParse(product.weight) ?? 0.0,
            multiplicity: product.multiplicity,
            photoUrl: product.imageUrl,
            description: product.composition,
          );

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminPriceItemFormScreen(item: priceItem),
            ),
          );
          if (result == true) {
            _loadPriceList();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildProductImage(product),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            product.categoryName,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${product.price.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (product.multiplicity > 1)
                          Text(
                            ' ×${product.multiplicity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      final priceItem = PriceItem(
                        id: product.id,
                        name: product.name,
                        price: product.price,
                        category: product.categoryName,
                        unit: 'шт',
                        weight: double.tryParse(product.weight) ?? 0.0,
                        multiplicity: product.multiplicity,
                        photoUrl: product.imageUrl,
                        description: product.composition,
                      );

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminPriceItemFormScreen(item: priceItem),
                        ),
                      );
                      if (result == true) {
                        _loadPriceList();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteItem(product),
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
