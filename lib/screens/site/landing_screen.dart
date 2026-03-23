// lib/screens/site/landing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/product.dart';
import '../../models/price_category.dart';
import '../auth_phone_screen.dart';
import '../price_list_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  List<PriceCategory> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPublicData();
  }

  // 🔥 ЗАГРУЗКА ПУБЛИЧНЫХ ДАННЫХ (без авторизации)
  Future<void> _loadPublicData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Загружаем категории и товары
      final categories = await _apiService.fetchPriceCategories();
      final productsData = await _apiService.fetchProducts();

      if (categories != null) {
        setState(() => _categories = categories);
      }

      if (productsData != null) {
        setState(() {
          _products =
              productsData.map((item) => Product.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Не удалось загрузить товары';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка подключения: $e';
        _isLoading = false;
      });
      print('❌ Ошибка загрузки публичных данных: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF5D4037),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Вкусные моменты',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              background: Container(color: const Color(0xFF5D4037)),
            ),
            actions: [
              TextButton(
                onPressed: () => _navigateToLogin(),
                child: const Text(
                  'Войти для опта',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),

          // Hero секция
          SliverToBoxAdapter(child: _buildHeroSection()),

          // Витрина товаров
          if (!_isLoading && _error == null)
            SliverToBoxAdapter(child: _buildProductsShowcase())
          else if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            SliverToBoxAdapter(child: _buildErrorSection()),

          // О нас
          SliverToBoxAdapter(child: _buildAboutSection()),

          // Преимущества
          SliverToBoxAdapter(child: _buildFeaturesSection()),

          // Контакты
          SliverToBoxAdapter(child: _buildContactSection()),

          // Footer
          SliverToBoxAdapter(child: _buildFooter()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToLogin(),
        backgroundColor: const Color(0xFF5D4037),
        icon: const Icon(Icons.shopping_bag, color: Colors.white),
        label: const Text(
          'Стать партнёром',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // 🔥 HERO СЕКЦИЯ
  Widget _buildHeroSection() {
    return Container(
      height: 500,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F5DC), Color(0xFFFFF8E1)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Премиум кондитерские изделия\nдля вашего бизнеса',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Готовый формат для увеличения чека\nвашей торговой точки',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 18,
              color: Color(0xFF757575),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _navigateToLogin(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Войти для опта',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () {
                  // Прокрутка к товарам
                  Scrollable.ensureVisible(
                    context.findRenderObject() ?? RenderObject(),
                    duration: const Duration(milliseconds: 500),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF5D4037), width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Смотреть продукцию',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    color: Color(0xFF5D4037),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 🔥 ВИТРИНА ТОВАРОВ
  Widget _buildProductsShowcase() {
    final showcaseProducts = _products.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Наш ассортимент',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Премиум десерты в удобной упаковке',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 16,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: showcaseProducts.length,
            itemBuilder: (context, index) {
              return _buildProductCard(showcaseProducts[index]);
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => _navigateToLogin(),
              child: const Text(
                'Смотреть весь прайс-лист →',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 16,
                  color: Color(0xFF5D4037),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 КАРТОЧКА ТОВАРА
  Widget _buildProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5DC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Center(
                child: product.photoUrl != null && product.photoUrl!.isNotEmpty
                    ? Image.network(
                        product.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.cake,
                          size: 64,
                          color: Color(0xFF5D4037),
                        ),
                      )
                    : const Icon(
                        Icons.cake,
                        size: 64,
                        color: Color(0xFF5D4037),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${product.price} ₽',
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5D4037).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'от ${product.multiplicity} шт',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF5D4037),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 О НАС
  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      color: const Color(0xFFFFF8E1),
      child: Column(
        children: [
          const Text(
            'О нас',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ручная работа с 2018 года',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Только премиальные ингредиенты:\n'
            'французский шоколад, свежие яйца Сибири,\n'
            'ваниль из Мадагаскара',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 16,
              color: Color(0xFF757575),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF5D4037), thickness: 1),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('2018', 'Работаем'),
              _buildStatItem('4', 'Региона'),
              _buildStatItem('500+', 'Партнёров'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 14,
            color: Color(0xFF757575),
          ),
        ),
      ],
    );
  }

  // 🔥 ПРЕИМУЩЕСТВА
  Widget _buildFeaturesSection() {
    final features = [
      {
        'icon': Icons.lock_outline,
        'title': 'Герметичная упаковка',
        'desc': 'Алюминиевая пломба с кольцом'
      },
      {
        'icon': Icons.schedule,
        'title': 'Срок до 7 суток',
        'desc': 'Минимальные списания'
      },
      {
        'icon': Icons.trending_up,
        'title': 'Маржинальность 40-60%',
        'desc': 'Высокая прибыль'
      },
      {
        'icon': Icons.local_shipping,
        'title': 'Доставка по Сибири',
        'desc': 'Точно в срок'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(32),
      color: Colors.white,
      child: Column(
        children: [
          const Text(
            'Почему выбирают нас',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) => _buildFeatureCard(features[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(feature['icon'] as IconData,
              size: 48, color: const Color(0xFF5D4037)),
          const SizedBox(height: 12),
          Text(
            feature['title'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            feature['desc'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 12,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 КОНТАКТЫ
  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      color: const Color(0xFF5D4037),
      child: Column(
        children: [
          const Text(
            'Свяжитесь с нами',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          _buildContactItem(Icons.phone, '+7 (391) 200-12-34', 'Позвоните нам'),
          const SizedBox(height: 16),
          _buildContactItem(
              Icons.email, 'info@vkusnyemomenty.ru', 'Напишите нам'),
          const SizedBox(height: 16),
          _buildContactItem(Icons.location_on, 'г. Красноярск', 'Наш адрес'),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _navigateToLogin(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5D4037),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
            ),
            child: const Text(
              'Стать партнёром',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🔥 FOOTER
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF3E2723),
      child: const Column(
        children: [
          Text(
            '© 2018-2024 «Вкусные моменты»',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Производство премиум десертов',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 ОШИБКА
  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? 'Ошибка загрузки',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPublicData,
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }

  // 🔥 НАВИГАЦИЯ К ВХОДУ
  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthPhoneScreen()),
    ).then((result) {
      // Если успешно вошли - переходим к прайс-листу
      if (result == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PriceListScreen()),
        );
      }
    });
  }
}
