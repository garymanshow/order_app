// lib/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/extended_product.dart';
import '../models/product.dart';
import '../models/nutrition_info.dart';
import '../models/storage_condition.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/product_card_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final String initialProductId;
  final List<Product> allProducts;

  const ProductDetailScreen({
    Key? key,
    required this.initialProductId,
    required this.allProducts,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late int _currentIndex;
  late List<ExtendedProduct> _extendedProducts;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.allProducts.indexWhere((p) => p.id == widget.initialProductId);
    if (_currentIndex == -1) _currentIndex = 0;

    _pageController = PageController(initialPage: _currentIndex);
    _extendedProducts = [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_extendedProducts.isEmpty) {
      _loadExtendedProducts();
    }
  }

  void _loadExtendedProducts() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData;

    if (clientData == null) return;

    _extendedProducts = widget.allProducts.map((product) {
      return ProductCardService.buildProductCard(
        product,
        clientData,
        packagingQuantity: 5,
        packagingName: 'Транспортный контейнер',
        declaredWeight: 120,
      );
    }).toList();

    setState(() {});
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < _extendedProducts.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_extendedProducts.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1} из ${_extendedProducts.length}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Основной контент
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _extendedProducts.length,
            itemBuilder: (context, index) {
              return ProductDetailCard(
                product: _extendedProducts[index],
              );
            },
          ),

          // Десктопные стрелки навигации
          if (isDesktop) ...[
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, size: 40),
                      onPressed: _goToPrevious,
                      tooltip: 'Предыдущий товар',
                    ),
                  ),
                ),
              ),
            if (_currentIndex < _extendedProducts.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, size: 40),
                      onPressed: _goToNext,
                      tooltip: 'Следующий товар',
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// Виджет самой карточки
class ProductDetailCard extends StatelessWidget {
  final ExtendedProduct product;

  const ProductDetailCard({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final quantity = cartProvider.getQuantity(product.id);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Фото
              Center(
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: product.hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            product.imageUrl ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildNoImage(),
                          ),
                        )
                      : _buildNoImage(),
                ),
              ),

              const SizedBox(height: 16),

              // Название и цена
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${product.price.toStringAsFixed(2)} ₽',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 8),

              // Фасовка и вес
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Фасовка',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(product.formattedPackaging),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Вес',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(product.formattedWeight),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Состав (если есть)
              if (product.hasComposition) ...[
                _buildSection(
                  icon: Icons.menu_book,
                  title: 'Состав',
                  child: Text(product.composition!),
                ),
              ],

              // КБЖУ (если есть)
              if (product.hasNutrition && product.nutritionInfo != null) ...[
                _buildSection(
                  icon: Icons.fitness_center,
                  title: 'Пищевая ценность',
                  child: _buildNutrition(product.nutritionInfo!),
                ),
              ],

              // Условия хранения (если есть)
              if (product.hasStorage && product.storageConditions != null) ...[
                _buildSection(
                  icon: Icons.ac_unit,
                  title: 'Хранение',
                  child: _buildStorage(product.storageConditions!),
                ),
              ],

              const SizedBox(height: 24),

              // Выбор количества
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Количество',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'кратно ${product.packagingQuantity}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: quantity > 0
                              ? () => cartProvider.setQuantity(
                                    product.id,
                                    quantity - product.packagingQuantity,
                                    product.packagingQuantity,
                                  )
                              : null,
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => cartProvider.setQuantity(
                            product.id,
                            quantity + product.packagingQuantity,
                            product.packagingQuantity,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (quantity > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Итого: ${(product.price * quantity).toStringAsFixed(2)} ₽',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildNutrition(NutritionInfo nutrition) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nutrition.calories != null && nutrition.calories!.isNotEmpty)
          Text('Калории: ${nutrition.calories} ккал'),
        if (nutrition.proteins != null && nutrition.proteins!.isNotEmpty)
          Text('Белки: ${nutrition.proteins} г'),
        if (nutrition.fats != null && nutrition.fats!.isNotEmpty)
          Text('Жиры: ${nutrition.fats} г'),
        if (nutrition.carbohydrates != null &&
            nutrition.carbohydrates!.isNotEmpty)
          Text('Углеводы: ${nutrition.carbohydrates} г'),
      ],
    );
  }

  Widget _buildStorage(StorageCondition storage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (storage.temperature.isNotEmpty)
          Text('Температура: ${storage.temperature}'),
        if (storage.humidity.isNotEmpty) Text('Влажность: ${storage.humidity}'),
        if (storage.shelfLife.isNotEmpty)
          Text('Срок хранения: ${storage.shelfLife} ${storage.unit}'),
      ],
    );
  }

  Widget _buildNoImage() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.image_not_supported,
        size: 50,
        color: Colors.grey,
      ),
    );
  }
}
