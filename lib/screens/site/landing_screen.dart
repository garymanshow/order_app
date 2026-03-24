// lib/screens/site/landing_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../models/product.dart';
import '../auth_phone_screen.dart';
import '../price_list_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ApiService _apiService = ApiService();
  final GlobalKey _productsSectionKey = GlobalKey();

  // 🔥 АНИМИРОВАННЫЕ ПОДЗАГОЛОВКИ
  final List<String> _heroSubtitles = [
    'Готовый формат для увеличения чека вашей торговой точки',
    'Премиум десерты в инновационной упаковке с кольцом',
    'Срок реализации до 7 суток — минимальные списания',
    'Маржинальность 40-60% для вашего бизнеса',
    'Доставка по всей Сибири точно в срок',
  ];

  int _currentSubtitleIndex = 0;
  Timer? _subtitleTimer;

  List<Product> _products = [];
  bool _isLoading = true; // 🔥 Показываем скелетоны сразу
  String? _error;

  // 🔥 КОНТАКТЫ АДМИНА (динамические)
  Map<String, String>? _adminContact;

  @override
  void initState() {
    super.initState();

    // 🔥 ПОКАЗЫВАЕМ UI СРАЗУ (скелетоны)
    setState(() => _isLoading = true);

    // 🔥 ЗАПУСКАЕМ РОТАЦИЮ ТЕКСТА СРАЗУ
    _startSubtitleRotation();

    // 🔥 ГРУЗИМ ДАННЫЕ В ФОНЕ (не блокирует UI)
    Future.microtask(() async {
      await _loadPublicData();
      await _loadAdminContact();
    });
  }

  @override
  void dispose() {
    _subtitleTimer?.cancel();
    super.dispose();
  }

  // 🔥 РОТАЦИЯ ТЕКСТА
  void _startSubtitleRotation() {
    _subtitleTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentSubtitleIndex =
              (_currentSubtitleIndex + 1) % _heroSubtitles.length;
        });
      }
    });
  }

  // 🔥 ПРОКРУТКА К ТОВАРАМ
  void _scrollToProducts() {
    Future.delayed(const Duration(milliseconds: 200), () {
      final context = _productsSectionKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  // 🔥 ЗАГРУЗКА ТОВАРОВ (ФОН)
  Future<void> _loadPublicData() async {
    try {
      print('🔍 Загрузка товаров (фон)...');
      final productsData = await _apiService.fetchProducts();

      if (mounted) {
        if (productsData != null) {
          setState(() {
            _products =
                productsData.map((item) => Product.fromJson(item)).toList();
            _isLoading = false;
          });
          print('✅ Товары загружены: ${_products.length}');
        } else {
          setState(() {
            _error = 'Не удалось загрузить товары';
            _isLoading = false;
          });
          print('❌ Товары не загружены');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка подключения: $e';
          _isLoading = false;
        });
      }
      print('❌ Ошибка загрузки: $e');
    }
  }

  // 🔥 ЗАГРУЗКА КОНТАКТОВ АДМИНА (ФОН)
  Future<void> _loadAdminContact() async {
    try {
      print('🔍 Загрузка контактов админа (фон)...');
      final contact = await _apiService.fetchAdminContact();
      if (mounted && contact != null) {
        setState(() => _adminContact = contact);
        print('✅ Контакты загружены');
      }
    } catch (e) {
      print('⚠️ Контакты не загружены (используем запасные): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAppBar(),
            _buildHeroSection(),
            _buildProductsShowcase(),
            _buildAboutSection(),
            _buildFeaturesSection(),
            _buildContactSection(),
            _buildFooter(),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 16),
            FloatingActionButton.extended(
              onPressed: () => _navigateToLogin(),
              backgroundColor: const Color(0xFF5D4037),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'Стать партнёром',
                style: TextStyle(color: Colors.white),
              ),
            ),
            FloatingActionButton.extended(
              onPressed: () => _navigateToLogin(),
              backgroundColor: const Color(0xFF5D4037),
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                'Войти для опта',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // 🔥 APP BAR (с динамическими контактами)
  Widget _buildAppBar() {
    return Container(
      height: 120,
      color: const Color(0xFF5D4037).withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Вкусные моменты',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _adminContact?['phone'] ?? '+7 (391) 200-12-34',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _adminContact?['schedule'] ?? 'Пн-Пт: 9:00 - 18:00',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔥 HERO СЕКЦИЯ (градиент, без фото)
  Widget _buildHeroSection() {
    return Container(
      height: 600,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5F5DC),
            Color(0xFFFFF8E1),
            Color(0xFF5D4037),
          ],
          stops: [0.0, 0.6, 1.0],
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
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Text(
              _heroSubtitles[_currentSubtitleIndex],
              key: ValueKey<int>(_currentSubtitleIndex),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                color: Color(0xFF757575),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _heroSubtitles.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentSubtitleIndex == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentSubtitleIndex == index
                      ? const Color(0xFF5D4037)
                      : const Color(0xFF5D4037).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
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
                  elevation: 4,
                ),
                child: const Text(
                  'Войти для опта',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _scrollToProducts,
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
          GestureDetector(
            onTap: _scrollToProducts,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 40,
                color: const Color(0xFF5D4037).withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 ВИТРИНА ТОВАРОВ (со скелетонами)
  Widget _buildProductsShowcase() {
    return Container(
      key: _productsSectionKey,
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
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
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 🔥 СКЕЛЕТОНЫ ИЛИ ТОВАРЫ
          if (_isLoading)
            _buildSkeletonGrid()
          else if (_error != null)
            Center(
              child: Column(
                children: [
                  Text('❌ $_error', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPublicData,
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            )
          else if (_products.isEmpty)
            const Center(child: Text('Товары не найдены'))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _products.take(6).length,
              itemBuilder: (context, index) {
                return _buildProductCard(_products[index]);
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

  // 🔥 СКЕЛЕТОНЫ ДЛЯ ТОВАРОВ (пока грузятся)
  Widget _buildSkeletonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300], // ← теперь можно
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 20,
                          width: 60,
                          color: Colors.grey[300],
                        ),
                        Container(
                          height: 16,
                          width: 40,
                          color: Colors.grey[300],
                        ),
                      ],
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

  Widget _buildProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.cake,
                                size: 64, color: Color(0xFF5D4037)),
                      )
                    : const Icon(Icons.cake,
                        size: 64, color: Color(0xFF5D4037)),
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
                        color: const Color(0xFF5D4037).withValues(alpha: 0.1),
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

  // 🔥 ОСТАЛЬНЫЕ СЕКЦИИ (без изменений, сокращено для краткости)
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

  void _navigateToLogin() async {
    final cacheService = Provider.of<CacheService>(context, listen: false);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AuthPhoneScreen()),
    );

    if (result == true && mounted) {
      await cacheService.markAsUsed();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PriceListScreen()),
      );
    }
  }
}
