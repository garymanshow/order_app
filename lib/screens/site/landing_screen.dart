// lib/screens/site/landing_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  // 🔥 ЕДИНАЯ КОНСТАНТА ДЛЯ ВСЕХ УПОМИНАНИЙ ГОДА
  static const int _startYear = 2018;
  final ApiService _apiService = ApiService();
  final GlobalKey _productsSectionKey = GlobalKey();

  // 🔥 АНИМИРОВАННЫЕ ПОДЗАГОЛОВКИ
  final List<String> _heroSubtitles = [
    'Готовый формат для увеличения чека Вашей торговой точки',
    'Премиум десерты в инновационной упаковке с кольцом',
    'Срок реализации до 90 суток — минимальные списания',
    'Высокая маржинальность для Вашего бизнеса',
    'Доставка по Сибири в короткие сроки',
  ];

  int _currentSubtitleIndex = 0;
  Timer? _subtitleTimer;

  // 🔥 ДАННЫЕ ДЛЯ ВИТРИНЫ
  List<Product> _products = [];
  List<Map<String, dynamic>> _adminContacts = []; // ✅ Используем Map

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSubtitleRotation();
    _loadShowcaseData(); // 🔥 Загрузка данных (кэш → сервер)
  }

  @override
  void dispose() {
    _subtitleTimer?.cancel();
    super.dispose();
  }

  // 🔥 РОТАЦИЯ ПОДЗАГОЛОВКОВ
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

  // 🔥 ЗАГРУЗКА ДАННЫХ ДЛЯ ВИТРИНЫ (ПРИОРИТЕТ КЭША)
  Future<void> _loadShowcaseData() async {
    try {
      print('🔍 Загрузка данных витрины...');

      // 1. Проверить локальный кэш
      final cacheService = await CacheService.getInstance();
      final localContacts = await cacheService.getAdminContacts();
      final localProducts = await cacheService.getProducts();

      print(
          '📦 Кэш: ${localContacts.length} контактов, ${localProducts.length} товаров');

      if (localContacts.isNotEmpty && localProducts.isNotEmpty) {
        // ✅ ЕСТЬ КЭШ → показать сразу (0 запросов!)
        print('✅ Загружено из кэша');

        if (mounted) {
          setState(() {
            _adminContacts = localContacts;
            _products =
                localProducts.take(7).toList(); // 🔥 Только 7 для витрины
            _isLoading = false;
          });
        }

        // 🔄 Фоновое обновление (если есть интернет)
        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity != ConnectivityResult.none) {
          print('🔄 Интернет есть, обновляем данные в фоне...');
          _refreshShowcaseData(); // Неблокирующее
        }
      } else {
        // ❌ НЕТ КЭША → запрос к серверу
        print('⚠️ Кэш пуст, запрашиваем сервер...');
        await _refreshShowcaseData();
      }
    } catch (e) {
      print('❌ Ошибка загрузки данных витрины: $e');
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 🔥 ОБНОВЛЕНИЕ ДАННЫХ С СЕРВЕРА (ГОСТЕВОЙ РЕЖИМ)
  Future<void> _refreshShowcaseData() async {
    try {
      print('📤 Запрос authenticate(\'\') для гостевого режима...');

      final response = await _apiService.authenticate(
        phone: '',
        localMetadata: {},
      );

      if (!mounted) return;

      if (response == null) {
        print('⚠️ Ответ от сервера: null');
        setState(() {
          _error = 'Нет ответа от сервера';
          _isLoading = false;
        });
        return;
      }

      // ✅ ИСПРАВЛЕНИЕ: Проверяем наличие 'data', а не 'success'
      // ApiService уже отфильтровал ошибки, если мы здесь — значит запрос прошел
      final data = response['data'] as Map<String, dynamic>?;

      if (data == null) {
        print('⚠️ data в ответе отсутствует');
        if (mounted) {
          setState(() {
            _error = 'Нет данных в ответе';
            _isLoading = false;
          });
        }
        return;
      }

      // 💾 Сохранить в кэш
      final cacheService = await CacheService.getInstance();

      // 🔥 Парсинг контактов
      final employeesRaw = data['employees'];
      final contacts = employeesRaw is List
          ? employeesRaw
              .where((e) => e['Роль'] == 'Администратор')
              .cast<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[];

      // 🔥 Парсинг товаров
      final productsRaw = data['products'];
      final products = productsRaw is List
          ? productsRaw
              .map((item) => Product.fromJson(item as Map<String, dynamic>))
              .toList()
          : <Product>[];

      await cacheService.saveAdminContacts(contacts);
      await cacheService.saveProducts(products);

      print(
          '✅ Сохранено в кэш: ${contacts.length} контактов, ${products.length} товаров');

      // ✅ Обновить UI
      if (mounted) {
        setState(() {
          _adminContacts = contacts;
          _products = products.toList();
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      print('❌ Ошибка обновления данных: $e');
      if (mounted) {
        setState(() {
          _error = 'Ошибка сети: $e';
          _isLoading = false;
        });
      }
    }
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

  // 🔥 ПЕРЕХОД К АВТОРИЗАЦИИ
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
      // 🔥 ПЛАВАЮЩИЕ КНОПКИ — КОМПАКТНЫЕ, НО МАКСИМАЛЬНО РАЗНЕСЕНЫ
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // 🔥 Максимальное расстояние
          children: [
            // 🔥 ЛЕВАЯ КНОПКА — компактная
            FloatingActionButton.extended(
              onPressed: () => _navigateToLogin(),
              backgroundColor: const Color(0xFF5D4037),
              heroTag: 'partner',
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'Стать партнёром',
                style: TextStyle(color: Colors.white),
              ),
              elevation: 4,
            ),
            // 🔥 ПРАВАЯ КНОПКА — компактная
            FloatingActionButton.extended(
              onPressed: () => _navigateToLogin(),
              backgroundColor: const Color(0xFF5D4037),
              heroTag: 'login',
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                'Вход для партнеров',
                style: TextStyle(color: Colors.white),
              ),
              elevation: 4,
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // 🔥 APP BAR С ДИНАМИЧЕСКИМИ КОНТАКТАМИ
  Widget _buildAppBar() {
    return Container(
      height: 100, // 🔥 Чуть меньше, так как только логотип + название
      color: const Color(0xFF5D4037).withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 🔥 Центрируем содержимое
        children: [
          // 🔥 ЛОГОТИП
          ClipRRect(
            borderRadius:
                BorderRadius.circular(8), // 🔥 Скругление углов (опционально)
            child: Image.asset(
              'assets/images/auth/logo.webp',
              height: 60, // 🔥 Высота логотипа
              width: 60, // 🔥 Ширина логотипа
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('⚠️ Логотип не найден: assets/images/auth/logo.webp');
                return const Icon(
                  Icons.cake,
                  size: 60,
                  color: Colors.white,
                );
              },
            ),
          ),
          const SizedBox(width: 16), // 🔥 Отступ между логотипом и названием
          // 🔥 НАЗВАНИЕ КОМПАНИИ
          const Text(
            'Вкусные моменты',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.bold,
              fontSize: 28, // 🔥 Чуть крупнее
              color: Colors.white,
              letterSpacing: 2, // 🔥 Разреженные буквы для премиум-вида
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black26,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 HERO СЕКЦИЯ (ГРАДИЕНТ, БЕЗ ФОТО)
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
            'Премиум кондитерские изделия\nдля Вашего бизнеса',
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
                  'Вход для партнеров',
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

  // 🔥 ВИТРИНА ТОВАРОВ
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

          // 🔥 СОСТОЯНИЯ: ЗАГРУЗКА / ОШИБКА / ПУСТО / ДАННЫЕ
          if (_isLoading)
            _buildSkeletonGrid()
          else if (_error != null)
            Center(
              child: Column(
                children: [
                  Text('❌ $_error', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadShowcaseData,
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
              itemCount: _products.length,
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

  // 🔥 СКЕЛЕТОНЫ ДЛЯ ТОВАРОВ (ПОКА ГРУЗЯТСЯ)
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
                    color: Colors.grey[300],
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

  // 🔥 КАРТОЧКА ТОВАРА
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
                child: _buildProductImage(product),
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

  // 🔥 ФОТО ТОВАРА ИЗ ASSETS
  Widget _buildProductImage(Product product) {
    // 🔥 ИСПОЛЬЗУЕМ ID ТОВАРА ДЛЯ ИМЕНИ ФАЙЛА
    print(product.id);
    final imageUrl = 'assets/images/products/${product.id}.webp';

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('⚠️ Фото не найдено: $imageUrl');
        return const Icon(Icons.cake, size: 64, color: Color(0xFF5D4037));
      },
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
            'Ручная работа с $_startYear года',
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
            'Крафтовые изделия, современный дизайн\n'
            'бельгийский шоколад, ваниль из Мадагаскара\n'
            'свежие яйца и натуральное сибирское масло.',
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
              _buildStatItem(_startYear.toString(), 'Работаем'),
              _buildStatItem('4', 'Региона'),
              _buildStatItem('100+', 'Партнёров'),
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
        'title': 'Срок до 90 суток',
        'desc': 'Минимальные списания'
      },
      {
        'icon': Icons.trending_up,
        'title': 'Маржинальность до 60%',
        'desc': 'Высокая прибыль'
      },
      {
        'icon': Icons.local_shipping,
        'title': 'Доставка по Сибири',
        'desc': 'В согласованные сроки'
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
          Icon(
            feature['icon'] as IconData,
            size: 48,
            color: const Color(0xFF5D4037),
          ),
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
//          _buildContactItem(Icons.phone, '+7 (391) 200-12-34', 'Позвоните нам'),
//          const SizedBox(height: 16),
          _buildContactItem(
              Icons.email, 'info@vkusnyemomenty.ru', 'Напишите нам'),
          const SizedBox(height: 16),
          _buildContactItem(
              Icons.location_on, 'г. Красноярск', 'пр. Металлургов, 41 Б'),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _navigateToLogin(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5D4037),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
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
    // 🔥 ДИНАМИЧЕСКИЙ ГОД
    final currentYear = DateTime.now().year;
    final yearText = _startYear == currentYear
        ? _startYear.toString()
        : '$_startYear-$currentYear';

    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF3E2723),
      child: Column(
        children: [
          Text(
            '© $yearText «Вкусные моменты»', // ← Динамический год
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
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
}
