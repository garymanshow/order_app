// lib/screens/admin/admin_price_categories_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/price_category.dart';
import '../../models/product.dart';
import '../../models/order_item.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import 'admin_price_category_form_screen.dart';
import 'admin_price_item_form_screen.dart';
import '../category_products_screen.dart';

class AdminPriceCategoriesScreen extends StatefulWidget {
  const AdminPriceCategoriesScreen({super.key});

  @override
  _AdminPriceCategoriesScreenState createState() =>
      _AdminPriceCategoriesScreenState();
}

class _AdminPriceCategoriesScreenState
    extends State<AdminPriceCategoriesScreen> {
  List<PriceCategory> _filteredCategories = [];
  String _searchQuery = '';
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  late CacheService _cacheService;

  // Расширенная статистика по категориям
  final Map<String, Map<String, dynamic>> _categoryStats = {};

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadCategories();
  }

  Future<void> _initServices() async {
    _cacheService = await CacheService.getInstance();
  }

  // 🔥 ЗАГРУЗКА КАТЕГОРИЙ И СТАТИСТИКИ
  void _loadCategories() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final categories = authProvider.clientData?.priceCategories ?? [];
    _calculateStats(authProvider);

    setState(() {
      _filteredCategories = categories;
    });

    print('📊 Загружено категорий: ${categories.length}');
  }

  // 🔥 РАСЧЕТ СТАТИСТИКИ ПО КАТЕГОРИЯМ
  void _calculateStats(AuthProvider authProvider) {
    _categoryStats.clear();

    final products = authProvider.clientData?.products ?? [];
    final orders = authProvider.clientData?.orders ?? [];

    // Группируем товары по категориям
    final Map<String, List<Product>> productsByCategory = {};
    final Map<String, Map<String, dynamic>> productStats = {};

    // Собираем статистику по каждому товару
    for (var order in orders) {
      if (!productStats.containsKey(order.priceListId)) {
        productStats[order.priceListId] = {
          'totalQuantity': 0,
          'totalSales': 0.0,
          'orderCount': 0,
        };
      }
      productStats[order.priceListId]!['totalQuantity'] =
          (productStats[order.priceListId]!['totalQuantity'] as int) +
              order.quantity;
      productStats[order.priceListId]!['totalSales'] =
          (productStats[order.priceListId]!['totalSales'] as double) +
              order.totalPrice;
      productStats[order.priceListId]!['orderCount'] =
          (productStats[order.priceListId]!['orderCount'] as int) + 1;
    }

    // Группируем товары по категориям
    for (var product in products) {
      if (!productsByCategory.containsKey(product.categoryId)) {
        productsByCategory[product.categoryId] = [];
      }
      productsByCategory[product.categoryId]!.add(product);
    }

    // Для каждой категории считаем статистику
    for (var category in authProvider.clientData?.priceCategories ?? []) {
      final categoryProducts = productsByCategory[category.id] ?? [];

      double totalSales = 0;
      int totalOrders = 0;
      int totalQuantity = 0;
      Product? topProduct;
      int maxQuantity = 0;

      for (var product in categoryProducts) {
        final stats = productStats[product.id] ??
            {'totalQuantity': 0, 'totalSales': 0.0, 'orderCount': 0};

        totalSales += stats['totalSales'] as double;
        totalOrders += stats['orderCount'] as int;
        totalQuantity += stats['totalQuantity'] as int;

        final quantity = stats['totalQuantity'] as int;
        if (quantity > maxQuantity) {
          maxQuantity = quantity;
          topProduct = product;
        }
      }

      _categoryStats[category.id] = {
        'productCount': categoryProducts.length,
        'totalSales': totalSales,
        'totalOrders': totalOrders,
        'totalQuantity': totalQuantity,
        'topProduct': topProduct,
        'topProductQuantity': maxQuantity,
        'products': categoryProducts,
      };
    }
  }

  // 🔥 ПРОВЕРКА СВЯЗАННЫХ ДАННЫХ ПЕРЕД УДАЛЕНИЕМ
  Future<Map<String, dynamic>> _checkRelatedData(PriceCategory category) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData!;

    final relatedData = <String, dynamic>{};

    // 1. Товары в этой категории (Прайс-лист)
    final products =
        clientData.products.where((p) => p.categoryId == category.id).toList();
    relatedData['products'] = products;

    // 2. Начинки, которые используют эту категорию
    final fillings = clientData.fillings
        .where((f) =>
            f.sheetName == 'Категории прайса' && f.entityId == category.id)
        .toList();
    relatedData['fillings'] = fillings;

    // 3. Состав (ингредиенты), которые ссылаются на эту категорию
    final compositions = clientData.compositions
        .where((c) =>
            c.sheetName == 'Категории прайса' && c.entityId == category.id)
        .toList();
    relatedData['compositions'] = compositions;

    // 4. Заказы, содержащие товары из этой категории
    final productIds = products.map((p) => p.id).toSet();
    final orders = clientData.orders
        .where((o) => productIds.contains(o.priceListId))
        .toList();
    relatedData['orders'] = orders;

    return relatedData;
  }

  // 🔥 ПОКАЗ ДИАЛОГА С ПРЕДУПРЕЖДЕНИЕМ ПЕРЕД УДАЛЕНИЕМ
  Future<void> _showDeleteWarning(PriceCategory category) async {
    setState(() => _isLoading = true);

    final relatedData = await _checkRelatedData(category);
    setState(() => _isLoading = false);

    final products = relatedData['products'] as List<Product>;
    final orders = relatedData['orders'] as List<OrderItem>;
    final fillings = relatedData['fillings'] as List;
    final compositions = relatedData['compositions'] as List;

    final hasProducts = products.isNotEmpty;
    final hasOrders = orders.isNotEmpty;
    final hasFillings = fillings.isNotEmpty;
    final hasCompositions = compositions.isNotEmpty;

    // Формируем сообщение о зависимостях
    final message = StringBuffer();
    message.writeln(
        '⚠️ ВНИМАНИЕ! Удаление категории "${category.name}" затронет следующие данные:\n');

    if (hasProducts) {
      message.writeln('📦 Товары в категории: ${products.length} шт');
      message.writeln('   ${products.take(5).map((p) => p.name).join(', ')}');
      if (products.length > 5) {
        message.writeln('   ...и еще ${products.length - 5}');
      }
      message.writeln();
    }

    if (hasOrders) {
      message.writeln('📋 Заказы с этими товарами: ${orders.length} шт');
      message.writeln();
    }

    if (hasFillings) {
      message
          .writeln('🥣 Начинки, использующие категорию: ${fillings.length} шт');
      message.writeln();
    }

    if (hasCompositions) {
      message.writeln('📝 Элементы состава: ${compositions.length} шт');
      message.writeln();
    }

    if (!hasProducts && !hasOrders && !hasFillings && !hasCompositions) {
      message.writeln(
          '✅ Нет связанных данных. Категорию можно безопасно удалить.');
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление категории',
            style: TextStyle(color: Colors.red)),
        content: SingleChildScrollView(
          child: Text(
            message.toString(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          if (!hasProducts)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Удалить'),
            )
          else
            OutlinedButton(
              onPressed: () => _showProductsInCategory(category, products),
              child: const Text('Посмотреть товары'),
            ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteCategory(category);
    }
  }

  // 🔥 ПОКАЗ ТОВАРОВ В КАТЕГОРИИ ПЕРЕД УДАЛЕНИЕМ
  void _showProductsInCategory(PriceCategory category, List<Product> products) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Товары в категории "${category.name}"'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.displayName),
                subtitle: Text('${product.price} ₽ • ID: ${product.id}'),
                trailing:
                    Text('Заказов: ${_getOrderCountForProduct(product.id)}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _reassignCategoryProducts(category);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Переназначить категорию'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCategoryWithProducts(category);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
  }

  int _getOrderCountForProduct(String productId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.clientData?.orders
            .where((o) => o.priceListId == productId)
            .length ??
        0;
  }

  // 🔥 ПЕРЕНАЗНАЧЕНИЕ ТОВАРОВ В ДРУГУЮ КАТЕГОРИЮ
  Future<void> _reassignCategoryProducts(PriceCategory oldCategory) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final otherCategories = authProvider.clientData?.priceCategories
            .where((c) => c.id != oldCategory.id)
            .toList() ??
        [];

    if (otherCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Нет других категорий для переназначения')),
      );
      return;
    }

    final selectedCategory = await showDialog<PriceCategory>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите новую категорию'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: otherCategories.length,
            itemBuilder: (context, index) {
              final category = otherCategories[index];
              return ListTile(
                title: Text(category.name),
                onTap: () => Navigator.pop(context, category),
              );
            },
          ),
        ),
      ),
    );

    if (selectedCategory != null) {
      setState(() => _isLoading = true);

      // Обновляем все товары
      final products = authProvider.clientData?.products
              .where((p) => p.categoryId == oldCategory.id)
              .toList() ??
          [];

      for (var product in products) {
        final updatedProduct = Product(
          id: product.id,
          name: product.name,
          price: product.price,
          multiplicity: product.multiplicity,
          categoryId: selectedCategory.id,
          imageUrl: product.imageUrl,
          imageBase64: product.imageBase64,
          composition: product.composition,
          weight: product.weight,
          nutrition: product.nutrition,
          storage: product.storage,
          packaging: product.packaging,
          categoryName: selectedCategory.name,
          wastePercentage: product.wastePercentage,
          displayName: product.displayName,
        );

        // Обновляем локально
        final index = authProvider.clientData!.products
            .indexWhere((p) => p.id == product.id);
        if (index != -1) {
          authProvider.clientData!.products[index] = updatedProduct;
        }

        // Отправляем на сервер
        await _apiService.updateProduct(updatedProduct);
      }

      await _cacheService.saveProducts(authProvider.clientData!.products);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${products.length} товаров переназначены в "${selectedCategory.name}"'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCategories();
    }
  }

  // 🔥 УДАЛЕНИЕ КАТЕГОРИИ ВМЕСТЕ СО ВСЕМИ ТОВАРАМИ
  Future<void> _deleteCategoryWithProducts(PriceCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить всё?', style: TextStyle(color: Colors.red)),
        content:
            Text('Вы уверены, что хотите удалить категорию "${category.name}" '
                'и ВСЕ товары в ней? Это действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteCategory(category, deleteProducts: true);
    }
  }

  // 🔥 УДАЛЕНИЕ КАТЕГОРИИ
  Future<void> _deleteCategory(PriceCategory category,
      {bool deleteProducts = false}) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (deleteProducts) {
        // Удаляем все товары категории
        final productsToDelete = authProvider.clientData?.products
                .where((p) => p.categoryId == category.id)
                .toList() ??
            [];

        for (var product in productsToDelete) {
          // Удаляем товар
          await _apiService.deleteProduct(product.id);

          // Удаляем связанные данные
          authProvider.clientData!.products
              .removeWhere((p) => p.id == product.id);
          authProvider.clientData!.compositions
              .removeWhere((c) => c.entityId == product.id);
          authProvider.clientData!.nutritionInfos
              .removeWhere((n) => n.priceListId == product.id);
        }
      }

      // Удаляем категорию
      final success = await _apiService.deletePriceCategory(category.id);

      if (success) {
        // Обновляем локальные данные
        authProvider.clientData!.priceCategories
            .removeWhere((c) => c.id == category.id);

        // Обновляем кэш
        await _cacheService
            .savePriceCategories(authProvider.clientData!.priceCategories);

        _loadCategories();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Категория "${category.name}" удалена'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Ошибка удаления категории');
      }
    } catch (e) {
      print('❌ Ошибка удаления категории: $e');
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

  // 🔥 ПОКАЗ ВСЕХ ТОВАРОВ КАТЕГОРИИ
  void _showCategoryProducts(
      PriceCategory category, Map<String, dynamic> stats) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          category: category,
          products: stats['products'] ?? [],
          stats: stats,
        ),
      ),
    );
  }

  // 🔥 ПОИСК КАТЕГОРИЙ
  void _filterCategories(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allCategories = authProvider.clientData?.priceCategories ?? [];

    if (_searchQuery.isEmpty) {
      _filteredCategories = allCategories;
    } else {
      _filteredCategories = allCategories.where((category) {
        return category.name.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории товаров'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск категорий...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterCategories,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AdminPriceCategoryFormScreen()),
              );
              if (result == true) {
                _loadCategories();
              }
            },
            tooltip: 'Добавить категорию',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredCategories.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredCategories.length,
                  itemBuilder: (context, index) {
                    final category = _filteredCategories[index];
                    final stats = _categoryStats[category.id] ??
                        {
                          'productCount': 0,
                          'totalSales': 0.0,
                          'totalOrders': 0,
                          'totalQuantity': 0
                        };
                    return _buildCategoryCard(category, stats);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminPriceCategoryFormScreen()),
          );
          if (result == true) {
            _loadCategories();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryCard(
      PriceCategory category, Map<String, dynamic> stats) {
    final topProduct = stats['topProduct'] as Product?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _showCategoryProducts(category, stats);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminPriceCategoryFormScreen(
                                category: category),
                          ),
                        );
                        if (result == true) {
                          _loadCategories();
                        }
                      } else if (value == 'delete') {
                        _showDeleteWarning(category);
                      } else if (value == 'add_product') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminPriceItemFormScreen(
                              initialCategoryId: category.id,
                              initialCategoryName: category.name,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add_product',
                        child: ListTile(
                          leading: Icon(Icons.add, color: Colors.green),
                          title: Text('Добавить товар'),
                        ),
                      ),
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

              // Статистика по категории
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildStatChip(
                      '📦 ${stats['productCount']} товаров', Colors.blue),
                  _buildStatChip(
                      '💰 ${(stats['totalSales'] as double).toStringAsFixed(0)} ₽',
                      Colors.green),
                  _buildStatChip(
                      '📊 ${stats['totalQuantity']} шт', Colors.orange),
                  _buildStatChip(
                      '🔄 ${stats['totalOrders']} заказов', Colors.purple),
                ],
              ),

              // Самая продаваемая позиция
              if (topProduct != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🏆 Самая продаваемая',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              topProduct.displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${stats['topProductQuantity']} шт',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Нет категорий',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Попробуйте изменить поисковый запрос'
                : 'Нажмите + чтобы добавить категорию',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
