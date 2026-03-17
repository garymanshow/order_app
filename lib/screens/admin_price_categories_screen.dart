// lib/screens/admin_price_categories_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/price_category.dart';
import '../models/product.dart';
import 'admin_price_category_form_screen.dart';
import 'admin_price_item_form_screen.dart';
import 'category_products_screen.dart';

class AdminPriceCategoriesScreen extends StatefulWidget {
  @override
  _AdminPriceCategoriesScreenState createState() =>
      _AdminPriceCategoriesScreenState();
}

class _AdminPriceCategoriesScreenState
    extends State<AdminPriceCategoriesScreen> {
  List<PriceCategory> _filteredCategories = [];
  String _searchQuery = '';
  bool _isLoading = false;
  // final ApiService _apiService = ApiService(); // 👈 УДАЛЕНО (не используется)

  // Расширенная статистика по категориям
  Map<String, Map<String, dynamic>> _categoryStats = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
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

  // 🔥 РАСШИРЕННЫЙ РАСЧЕТ СТАТИСТИКИ ПО КАТЕГОРИЯМ
  void _calculateStats(AuthProvider authProvider) {
    _categoryStats.clear();

    final products = authProvider.clientData?.products ?? [];
    final orders = authProvider.clientData?.orders ?? [];

    // Группируем товары по категориям
    final Map<String, List<Product>> productsByCategory = {};
    final Map<String, Map<String, dynamic>> productStats = {};

    // Сначала собираем статистику по каждому товару
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

    // Для каждой категории считаем статистику и находим топ-товар
    for (var category in authProvider.clientData?.priceCategories ?? []) {
      final categoryProducts = productsByCategory[category.id] ?? [];

      double totalSales = 0;
      int totalOrders = 0;
      int totalQuantity = 0;

      // Находим самый продаваемый товар
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

  // 🔥 УДАЛЕНИЕ КАТЕГОРИИ (сокращенная версия без вызовов)
  Future<void> _deleteCategory(PriceCategory category) async {
    // TODO: реализовать удаление
    print('Удаление категории ${category.id}');
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
                        _deleteCategory(category);
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
