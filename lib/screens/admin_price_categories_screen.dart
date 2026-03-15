// lib/screens/admin_price_categories_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/price_category.dart';
import 'admin_price_category_form_screen.dart';

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
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Получаем категории из clientData (нужно добавить в ClientData)
    // Пока заглушка - позже заменим на реальные данные
    final categories = authProvider.clientData?.priceCategories ?? [];

    setState(() {
      _filteredCategories = categories;
    });

    print('📊 Загружено категорий: ${categories.length}');
  }

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

  // Метод удаления категории
  Future<void> _deleteCategory(PriceCategory category) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Проверяем, есть ли товары с этой категорией
    final productsInCategory = authProvider.clientData?.products
            .where((p) => p.categoryId == category.id)
            .toList() ??
        [];

    // 🔥 СОБИРАЕМ СТАТИСТИКУ ДЛЯ ПРЕДУПРЕЖДЕНИЯ
    int compositionsCount = 0;
    int nutritionCount = 0;
    int storageCount = 0;
    int fillingsCount = 0;
    int categoryCompositionsCount = 0; // 👈 ДОБАВЛЕНО: составы категории
    int categoryFillingsCount = 0; // 👈 ДОБАВЛЕНО: начинки категории

    for (var product in productsInCategory) {
      // Составы товаров
      compositionsCount += authProvider.clientData!.compositions
          .where((c) => c.entityId == product.id && c.sheetName == 'Состав')
          .length;

      // КБЖУ товаров
      nutritionCount += authProvider.clientData!.nutritionInfos
          .where((n) => n.priceListId == product.id)
          .length;

      // Условия хранения товаров
      storageCount += authProvider.clientData!.storageConditions
          .where((s) => s.entityId == product.id && s.sheetName == 'Прайс-лист')
          .length;

      // Начинки товаров (уникальные начинки для конкретных товаров)
      fillingsCount += authProvider.clientData!.fillings
          .where((f) => f.entityId == product.id)
          .length;
    }

    // 🔥 ДОБАВЛЕНО: составы категории (базовый состав для всех товаров категории)
    categoryCompositionsCount = authProvider.clientData!.compositions
        .where((c) =>
            c.entityId == category.id && c.sheetName == 'Категория прайса')
        .length;

    // 🔥 ДОБАВЛЕНО: начинки категории (общие начинки для категории)
    categoryFillingsCount = authProvider.clientData!.fillings
        .where((f) =>
            f.entityId == category.id && f.sheetName == 'Категория прайса')
        .length;

    // Условия хранения категории
    final categoryStorageCount = authProvider.clientData!.storageConditions
        .where((s) =>
            s.entityId == category.id && s.sheetName == 'Категория прайса')
        .length;

    final totalRelatedRecords = compositionsCount +
        nutritionCount +
        storageCount +
        fillingsCount +
        categoryCompositionsCount +
        categoryFillingsCount +
        categoryStorageCount;

    if (productsInCategory.isNotEmpty || totalRelatedRecords > 0) {
      // 🔥 ПОКАЗЫВАЕМ ДИАЛОГ С ПОЛНОЙ ИНФОРМАЦИЕЙ
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Внимание! Каскадное удаление'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Категория "${category.name}" будет удалена вместе с:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Товары
                if (productsInCategory.isNotEmpty) ...[
                  _buildDeleteInfo(
                    icon: Icons.shopping_bag,
                    title: 'Товары',
                    count: productsInCategory.length,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 8),
                ],

                // Составы товаров
                if (compositionsCount > 0) ...[
                  _buildDeleteInfo(
                    icon: Icons.menu_book,
                    title: 'Составы товаров',
                    count: compositionsCount,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                ],

                // 🔥 НОВОЕ: составы категории
                if (categoryCompositionsCount > 0) ...[
                  _buildDeleteInfo(
                    icon: Icons.folder_copy,
                    title: 'Базовые составы категории',
                    count: categoryCompositionsCount,
                    color: Colors.deepOrange,
                  ),
                  const SizedBox(height: 8),
                ],

                // КБЖУ
                if (nutritionCount > 0) ...[
                  _buildDeleteInfo(
                    icon: Icons.fitness_center,
                    title: 'Записи в "КБЖУ"',
                    count: nutritionCount,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                ],

                // Условия хранения товаров
                if (storageCount > 0) ...[
                  _buildDeleteInfo(
                    icon: Icons.ac_unit,
                    title: 'Условия хранения товаров',
                    count: storageCount,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 8),
                ],

                // Начинки товаров
                if (fillingsCount > 0) ...[
                  _buildDeleteInfo(
                    icon: Icons.icecream,
                    title: 'Начинки товаров',
                    count: fillingsCount,
                    color: Colors.pink,
                  ),
                  const SizedBox(height: 8),
                ],

                // 🔥 НОВОЕ: начинки категории
                if (categoryFillingsCount > 0) ...[
                  _buildDeleteInfo(
                    icon: Icons.folder_special,
                    title: 'Базовые начинки категории',
                    count: categoryFillingsCount,
                    color: Colors.pink.shade800,
                  ),
                  const SizedBox(height: 8),
                ],

                // Условия хранения категории
                if (categoryStorageCount > 0) ...[
                  _buildDeleteInfo(
                    icon: Icons.storage,
                    title: 'Условия хранения категории',
                    count: categoryStorageCount,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 8),
                ],

                const Divider(height: 24),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Всего будет удалено: $totalRelatedRecords записей',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Это действие нельзя отменить!',
                        style: TextStyle(
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

      if (confirm != true) return;
    } else {
      // Если ничего нет, просто подтверждение удаления категории
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить категорию?'),
          content: Text(
              'Вы уверены, что хотите удалить категорию "${category.name}"?'),
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

      if (confirm != true) return;
    }

    // 🔥 ПРОЦЕСС ПОЛНОГО КАСКАДНОГО УДАЛЕНИЯ
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Получаем все товары категории
      final productsToDelete = authProvider.clientData!.products
          .where((p) => p.categoryId == category.id)
          .toList();

      // 1️⃣ УДАЛЯЕМ ВСЕ СВЯЗАННЫЕ ДАННЫЕ ДЛЯ КАЖДОГО ТОВАРА
      for (var product in productsToDelete) {
        // Удаляем состав товара
        authProvider.clientData!.compositions.removeWhere(
            (c) => c.entityId == product.id && c.sheetName == 'Состав');

        // Удаляем КБЖУ товара
        authProvider.clientData!.nutritionInfos
            .removeWhere((n) => n.priceListId == product.id);

        // Удаляем условия хранения товара
        authProvider.clientData!.storageConditions.removeWhere(
            (s) => s.entityId == product.id && s.sheetName == 'Прайс-лист');

        // Удаляем начинки товара
        authProvider.clientData!.fillings
            .removeWhere((f) => f.entityId == product.id);

        // Отправляем запрос на удаление товара на сервер
        await _apiService.deleteProduct(product.id);
      }

      // 2️⃣ УДАЛЯЕМ ВСЕ ДАННЫЕ КАТЕГОРИИ

      // 🔥 Удаляем составы категории (базовый состав)
      authProvider.clientData!.compositions.removeWhere((c) =>
          c.entityId == category.id && c.sheetName == 'Категория прайса');

      // 🔥 Удаляем начинки категории (общие начинки)
      authProvider.clientData!.fillings.removeWhere((f) =>
          f.entityId == category.id && f.sheetName == 'Категория прайса');

      // Удаляем условия хранения категории
      authProvider.clientData!.storageConditions.removeWhere((s) =>
          s.entityId == category.id && s.sheetName == 'Категория прайса');

      // 3️⃣ УДАЛЯЕМ САМИ ТОВАРЫ ИЗ СПИСКА
      authProvider.clientData!.products
          .removeWhere((p) => p.categoryId == category.id);

      // 4️⃣ УДАЛЯЕМ КАТЕГОРИЮ
      authProvider.clientData!.priceCategories
          .removeWhere((c) => c.id == category.id);

      // Отправляем запрос на удаление категории на сервер
      await _apiService.deletePriceCategory(category.id);

      // Перестраиваем индексы
      authProvider.clientData!.buildIndexes();

      // Сохраняем в SharedPreferences
      await _saveToPrefs(authProvider);

      // Обновляем отображение
      _loadCategories();

      _showSnackBar(
        'Категория и все связанные данные удалены',
        Colors.green,
      );
    } catch (e) {
      print('❌ Ошибка каскадного удаления: $e');
      _showSnackBar('Ошибка удаления: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
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

  void _showDeleteConfirmation(PriceCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
            'Вы уверены, что хотите удалить категорию "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(category);
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 🔥 ВСПОМОГАТЕЛЬНЫЙ МЕТОД ДЛЯ ПОСТРОЕНИЯ ИНФОРМАЦИИ В ДИАЛОГЕ
  Widget _buildDeleteInfo({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории товаров'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
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
                    return _buildCategoryCard(category);
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

  Widget _buildCategoryCard(PriceCategory category) {
    // Считаем количество товаров в категории
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productsCount = authProvider.clientData?.products
            .where((p) => p.categoryId == category.id)
            .length ??
        0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminPriceCategoryFormScreen(category: category),
            ),
          );
          if (result == true) {
            _loadCategories();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    category.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildInfoChip(
                          '📦 ${category.packagingQuantity} шт',
                          Colors.blue,
                        ),
                        _buildInfoChip(
                          '📥 ${category.packagingName}',
                          Colors.purple,
                        ),
                        _buildInfoChip(
                          '⚖️ ${category.weight} ${category.unit}',
                          Colors.orange,
                        ),
                        _buildInfoChip(
                          '📊 издержки ${category.wastePercentage}%',
                          Colors.green,
                        ),
                        _buildInfoChip(
                          '📋 товаров: $productsCount',
                          Colors.grey,
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
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminPriceCategoryFormScreen(category: category),
                        ),
                      );
                      if (result == true) {
                        _loadCategories();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteConfirmation(category),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
