// lib/screens/admin_price_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/price_item.dart';
import 'admin_price_item_form_screen.dart';

class AdminPriceListScreen extends StatefulWidget {
  @override
  _AdminPriceListScreenState createState() => _AdminPriceListScreenState();
}

class _AdminPriceListScreenState extends State<AdminPriceListScreen> {
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  String? _selectedCategory;
  List<String> _categories = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadPriceList();
  }

  // ЗАГРУЗКА ТОВАРОВ ИЗ ЛОКАЛЬНЫХ ДАННЫХ
  void _loadPriceList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final products = authProvider.clientData?.products ?? [];

    // Извлекаем уникальные категории
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

  // ПОИСК ТОВАРОВ
  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyFilters();
    });
  }

  // ФИЛЬТР ПО КАТЕГОРИИ
  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
  }

  // ПРИМЕНЕНИЕ ФИЛЬТРОВ
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

  // УДАЛЕНИЕ ТОВАРА
  Future<void> _deleteItem(Product product) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Удаляем из локального списка
      authProvider.clientData!.products.removeWhere((p) => p.id == product.id);

      // Удаляем связанные ингредиенты
      authProvider.clientData!.compositions.removeWhere(
          (c) => c.entityId == product.id && c.sheetName == 'Состав');

      // Удаляем связанные КБЖУ
      authProvider.clientData!.nutritionInfos
          .removeWhere((n) => n.priceListId == product.id);

      // Перестраиваем индексы
      authProvider.clientData!.buildIndexes();

      // Сохраняем в SharedPreferences
      await _saveToPrefs(authProvider);

      // Отправка на сервер
      await _apiService.deleteProduct(product.id);

      // Обновляем отображение
      _loadPriceList();

      _showSnackBar('Товар удален', Colors.green);
    } catch (e) {
      print('❌ Ошибка удаления товара: $e');
      _showSnackBar('Ошибка удаления: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // СОХРАНЕНИЕ В SHAREDPREFERENCES
  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }

  // ДИАЛОГ ПОДТВЕРЖДЕНИЯ УДАЛЕНИЯ
  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить позицию?'),
        content:
            Text('Вы уверены, что хотите удалить "${product.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(product);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ПОКАЗ SNACKBAR
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ПОЛУЧЕНИЕ ПУТИ К ИЗОБРАЖЕНИЮ
  String _getImagePath(Product product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return product.imageUrl!;
    }
    return 'assets/images/products/${product.id}.webp';
  }

  // ПОСТРОЕНИЕ ИЗОБРАЖЕНИЯ
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

  // ЗАГЛУШКА ДЛЯ ИЗОБРАЖЕНИЯ
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Прайс-лист'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPriceList,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminPriceItemFormScreen()),
              );
              if (result == true) {
                _loadPriceList();
              }
            },
            tooltip: 'Добавить позицию',
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
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return _buildProductCard(product);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminPriceItemFormScreen()),
          );
          if (result == true) {
            _loadPriceList();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // КАРТОЧКА ТОВАРА
  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          // Конвертируем Product в PriceItem для формы
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
                    onPressed: () => _showDeleteConfirmation(product),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ПУСТОЕ СОСТОЯНИЕ
  Widget _buildEmptyState() {
    return Center(
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
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? 'Попробуйте изменить параметры поиска'
                : 'Нажмите + чтобы добавить товар',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
