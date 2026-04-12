// lib/screens/site/landing_screen.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../utils/phone_validator.dart';
import '../../utils/auth_validator.dart';
import '../auth_phone_screen.dart';
import '../price_list_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  // 🔥 КОНСТАНТЫ
  static const String _companyName = 'ИП «Вкусные моменты»';
  static const String _companyAddress = 'г. Красноярск, пр. Металлургов, 51К';
  static const int _startYear = 2018;

  final ApiService _apiService = ApiService();
  final GlobalKey _productsSectionKey = GlobalKey();

  // Контроллеры слайдеров (Бесконечная прокрутка: старт с 10000)
  final PageController _productPageController =
      PageController(initialPage: 10000, viewportFraction: 0.85);
  int _currentProductPage = 10000;

  final PageController _featuresPageController =
      PageController(initialPage: 10000, viewportFraction: 0.8);
  int _currentFeaturesPage = 10000;

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

  List<Product> _products = [];
  List<Map<String, dynamic>> _adminContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startSubtitleRotation();
    _loadShowcaseData();
  }

  @override
  void dispose() {
    _subtitleTimer?.cancel();
    _productPageController.dispose();
    _featuresPageController.dispose();
    super.dispose();
  }

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

  // 🔥 ФИЛЬТРАЦИЯ ТОВАРОВ: удаляем пустышки и дубликаты картинок по размеру файла
  Future<List<Product>> _filterValidProducts(List<Product> products) async {
    final seenSizes = <int>{};
    final validProducts = <Product>[];

    for (final product in products) {
      if (product.id.isEmpty) continue;

      try {
        final byteData = await rootBundle.load(product.assetPath);
        final sizeInBytes = byteData.lengthInBytes;

        if (sizeInBytes < 1024) continue;
        if (seenSizes.contains(sizeInBytes)) continue;

        seenSizes.add(sizeInBytes);
        validProducts.add(product);
      } catch (e) {
        continue;
      }
    }

    return validProducts;
  }

  // 🔥 ЗАГРУЗКА ДАННЫХ
  Future<void> _loadShowcaseData() async {
    try {
      final cacheService = await CacheService.getInstance();
      final localContacts = cacheService.getAdminContacts();
      final localProducts = cacheService.getProducts();

      if (localContacts.isNotEmpty && localProducts.isNotEmpty) {
        final filteredProducts = await _filterValidProducts(localProducts);
        if (mounted) {
          setState(() {
            _adminContacts = localContacts;
            _products = filteredProducts.take(7).toList();
            _isLoading = false;
          });
        }
        final connectivity = await Connectivity().checkConnectivity();
        if (!connectivity.contains(ConnectivityResult.none)) {
          _refreshShowcaseData();
        }
      } else {
        await _refreshShowcaseData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshShowcaseData() async {
    try {
      final response = await _apiService.authenticate(
        phone: '',
        localMetadata: {},
      );

      if (!mounted) return;
      if (response == null) {
        setState(() => _isLoading = false);
        return;
      }

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        setState(() => _isLoading = false);
        return;
      }

      final cacheService = await CacheService.getInstance();
      final employeesRaw = data['employees'];
      final contacts = employeesRaw is List
          ? employeesRaw
              .where((e) => e['Роль'] == 'Администратор')
              .cast<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[];

      final productsRaw = data['products'];
      final rawProducts = productsRaw is List
          ? productsRaw
              .map((item) => Product.fromMap(item as Map<String, dynamic>))
              .toList()
          : <Product>[];

      final products = await _filterValidProducts(rawProducts);

      await cacheService.saveAdminContacts(contacts);
      await cacheService.saveProducts(products);

      if (mounted) {
        setState(() {
          _adminContacts = contacts;
          _products = products.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔥 ОТПРАВКА ПИСЬМА (Из диалога)
  Future<void> _sendPartnerRequest({
    required String name,
    required String method,
    required String contact,
    required String comment,
  }) async {
    final String adminEmail =
        (_adminContacts.isNotEmpty && _adminContacts[0]['Email'] != null)
            ? _adminContacts[0]['Email'].toString()
            : 'info@vkusnyemomenty.ru';

    final subject = Uri.encodeComponent('Новая заявка на партнерство от $name');
    final body = Uri.encodeComponent('''
Здравствуйте!

Поступила новая заявка на партнерство с сайта витрины.

Данные клиента:
------------------------------------
Имя / Организация: $name
Способ связи: $method
Контакт: $contact
Комментарий: ${comment.isNotEmpty ? comment : 'Нет комментария'}
------------------------------------

Пожалуйста, свяжитесь с клиентом в ближайшее время.
    ''');

    final Uri emailUri =
        Uri.parse('mailto:$adminEmail?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Не удалось открыть почтовое приложение')),
          );
        }
      }
    } catch (e) {
      debugPrint('Ошибка открытия почты: $e');
    }
  }

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

  // 🔥 ДИАЛОГ "СТАТЬ ПАРТНЕРОМ"
  void _showPartnerRequestDialog() {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final commentController = TextEditingController();
    String contactMethod = 'Телефон';
    bool isAgreed = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Стать партнёром',
                  style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Оставьте свои контакты, и мы свяжемся с вами.',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Ваше имя или организация *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Способ связи:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    
                    // 🔥 ИСПРАВЛЕНО: Обычный Row с выбором метода (без устаревших Radio)
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Телефон'),
                          selected: contactMethod == 'Телефон',
                          onSelected: (_) => setStateDialog(() => contactMethod = 'Телефон'),
                        ),
                        ChoiceChip(
                          label: const Text('Email'),
                          selected: contactMethod == 'Email',
                          onSelected: (_) => setStateDialog(() => contactMethod = 'Email'),
                        ),
                        ChoiceChip(
                          label: const Text('Мессенджер'),
                          selected: contactMethod == 'Мессенджер',
                          onSelected: (_) => setStateDialog(() => contactMethod = 'Мессенджер'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactController,
                      keyboardType: contactMethod == 'Телефон'
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: contactMethod == 'Телефон'
                            ? 'Номер телефона'
                            : contactMethod == 'Email'
                                ? 'Email адрес'
                                : 'Ссылка или никнейм',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий (необязательно)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => setStateDialog(() => isAgreed = !isAgreed),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isAgreed,
                            activeColor: const Color(0xFF5D4037),
                            onChanged: (val) =>
                                setStateDialog(() => isAgreed = val ?? false),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showOfferDialog(),
                              child: const Text(
                                  'Принимаю условия публичной оферты',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF5D4037),
                                      decoration: TextDecoration.underline)),
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена',
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: isAgreed
                      ? () {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Пожалуйста, введите имя')),
                            );
                            return;
                          }

                          String? validationError;
                          final contactValue = contactController.text;

                          if (contactMethod == 'Телефон') {
                            validationError =
                                PhoneValidator.validatePhone(contactValue);
                            if (contactValue.trim().isEmpty) {
                              validationError = 'Введите номер телефона';
                            }
                          } else if (contactMethod == 'Email') {
                            validationError =
                                AuthValidator.validateEmail(contactValue);
                            if (contactValue.trim().isEmpty) {
                              validationError = 'Введите Email';
                            }
                          } else {
                            validationError = AuthValidator.validateSocialLink(
                                contactValue, 'telegram');
                            if (contactValue.trim().isEmpty) {
                              validationError = 'Введите контакт';
                            }
                          }

                          if (validationError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(validationError)),
                            );
                            return;
                          }

                          Navigator.pop(context);
                          _sendPartnerRequest(
                            name: nameController.text,
                            method: contactMethod,
                            contact: contactController.text,
                            comment: commentController.text,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      foregroundColor: Colors.white),
                  child: const Text('Отправить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showOfferDialog() async {
    String offerText = 'Ошибка загрузки текста оферты.';
    final String adminEmail =
        (_adminContacts.isNotEmpty && _adminContacts[0]['Email'] != null)
            ? _adminContacts[0]['Email'].toString()
            : 'info@vkusnyemomenty.ru';

    try {
      String rawText = await rootBundle.loadString('texts/offer.txt');
      offerText = rawText
          .replaceAll('%COMPANY_NAME%', _companyName)
          .replaceAll('%COMPANY_ADDRESS%', _companyAddress)
          .replaceAll('%ADMIN_EMAIL%', adminEmail);
    } catch (e) {
      debugPrint('❌ Ошибка чтения оферты: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Публичная оферта',
            style: TextStyle(
                fontFamily: 'PlayfairDisplay', color: Color(0xFF5D4037))),
        content: SingleChildScrollView(
            child: Text(offerText, style: const TextStyle(fontSize: 12))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'))
        ],
      ),
    );
  }

  void _handleEmailTap(String email) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Скопировать адрес'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: email));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email скопирован')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Написать письмо'),
              onTap: () async {
                Navigator.pop(context);
                final Uri emailUri = Uri(scheme: 'mailto', path: email);
                if (await canLaunchUrl(emailUri)) await launchUrl(emailUri);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin() async {
    final cacheService = Provider.of<CacheService>(context, listen: false);
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => AuthPhoneScreen()));
    if (result == true && mounted) {
      await cacheService.markAsUsed();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const PriceListScreen()));
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
    );
  }

  // ==========================================
  // 🎨 WIDGET BUILDERS
  // ==========================================

  Widget _buildAppBar() {
    return Container(
      height: 100,
      color: const Color(0xFF5D4037).withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/auth/logo.webp',
                height: 60,
                width: 60,
                fit: BoxFit.contain,
                errorBuilder: (c, o, s) =>
                    const Icon(Icons.cake, size: 60, color: Colors.white)),
          ),
          const SizedBox(width: 16),
          const Text('Вкусные моменты',
              style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: 600,
      width: double.infinity,
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFF5F5DC), Color(0xFFFFF8E1), Color(0xFF5D4037)],
              stops: [0.0, 0.6, 1.0])),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text('Премиум кондитерские изделия\nдля Вашего бизнеса',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
          const SizedBox(height: 20),
          AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(_heroSubtitles[_currentSubtitleIndex],
                  key: ValueKey<int>(_currentSubtitleIndex),
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 20, color: Color(0xFF757575)))),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: _navigateToLogin,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25))),
                  child: const Text('Вход для партнеров',
                      style: TextStyle(color: Colors.white))),
              const SizedBox(width: 16),
              OutlinedButton(
                  onPressed: _scrollToProducts,
                  style: OutlinedButton.styleFrom(
                      side:
                          const BorderSide(color: Color(0xFF5D4037), width: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25))),
                  child: const Text('Смотреть продукцию',
                      style: TextStyle(color: Color(0xFF5D4037)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsShowcase() {
    if (!_isLoading && _products.isEmpty) {
      return Container(
        key: _productsSectionKey,
        padding: const EdgeInsets.symmetric(vertical: 24),
        color: Colors.white,
        child: Column(
          children: const [
            Text('Наш ассортимент',
                style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037))),
            SizedBox(height: 32),
            Center(child: Text('Ассортимент скоро будет обновлен')),
          ],
        ),
      );
    }

    return Container(
      key: _productsSectionKey,
      padding: const EdgeInsets.symmetric(vertical: 24),
      color: Colors.white,
      child: Column(
        children: [
          const Text('Наш ассортимент',
              style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
          const SizedBox(height: 32),
          if (_isLoading)
            _buildSkeletonSlider()
          else
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 420,
                  child: PageView.builder(
                    itemCount: null,
                    controller: _productPageController,
                    onPageChanged: (index) =>
                        setState(() => _currentProductPage = index),
                    itemBuilder: (context, index) {
                      final realIndex = index % _products.length;
                      final product = _products[realIndex];
                      return _buildSlidingProductCard(product);
                    },
                  ),
                ),
                if (_products.length > 1)
                  Positioned(
                      left: 0,
                      child: _buildNavArrow(
                          icon: Icons.chevron_left,
                          onTap: () => _productPageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut))),
                if (_products.length > 1)
                  Positioned(
                      right: 0,
                      child: _buildNavArrow(
                          icon: Icons.chevron_right,
                          onTap: () => _productPageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut))),
              ],
            ),
          TextButton(
              onPressed: _navigateToLogin,
              child: const Text('Смотреть весь прайс-лист →',
                  style: TextStyle(color: Color(0xFF5D4037)))),
        ],
      ),
    );
  }

  Widget _buildSlidingProductCard(Product product) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ]),
      child: Column(
        children: [
          Expanded(
              flex: 7,
              child: Container(
                  color: const Color(0xFFF5F5DC),
                  child: Center(child: _buildProductImage(product)))),
          Expanded(
              flex: 3,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(product.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5D4037))),
                      ]))),
        ],
      ),
    );
  }

  Widget _buildSkeletonSlider() => SizedBox(
      height: 420,
      child: PageView.builder(
          itemCount: 3,
          controller: PageController(viewportFraction: 0.85),
          itemBuilder: (c, i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20)))));

  Widget _buildNavArrow(
          {required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: const Color(0xFF5D4037))));

  Widget _buildProductImage(Product product) {
    return Image.asset('assets/images/products/${product.id}.webp',
        fit: BoxFit.cover,
        errorBuilder: (c, o, s) =>
            const Icon(Icons.cake, size: 64, color: Color(0xFF5D4037)));
  }

  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      color: const Color(0xFFFFF8E1),
      child: Column(
        children: [
          const Text('О нас',
              style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
          const SizedBox(height: 24),
          Text('Ручная работа с $_startYear года',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4037))),
          const SizedBox(height: 16),
          const Text('Только премиальные ингредиенты',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF757575))),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildStatItem(_startYear.toString(), 'Работаем'),
            _buildStatItem('4', 'Региона'),
            _buildStatItem('100+', 'Партнёров')
          ]),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) => Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037))),
        Text(label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF757575)))
      ]);

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
      padding: const EdgeInsets.symmetric(vertical: 32),
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
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 250,
                child: PageView.builder(
                  itemCount: null,
                  controller: _featuresPageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentFeaturesPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final realIndex = index % features.length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: _buildFeatureCard(features[realIndex]),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                child: _buildNavArrow(
                  icon: Icons.chevron_left,
                  onTap: () {
                    _featuresPageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
              Positioned(
                right: 0,
                child: _buildNavArrow(
                  icon: Icons.chevron_right,
                  onTap: () {
                    _featuresPageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              feature['desc'] as String? ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 12,
                color: Color(0xFF757575),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 ОЧИЩЕННАЯ СЕКЦИЯ КОНТАКТОВ (Только инфа и кнопка)
  Widget _buildContactSection() {
    final String adminEmail =
        (_adminContacts.isNotEmpty && _adminContacts[0]['Email'] != null)
            ? _adminContacts[0]['Email'].toString()
            : 'Загрузка...';

    return Container(
      padding: const EdgeInsets.all(32),
      color: const Color(0xFF5D4037),
      child: Column(
        children: [
          const Text('Свяжитесь с нами',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 32),
          
          _buildContactItem(Icons.email, adminEmail, 'Напишите нам',
              onTap: adminEmail != 'Загрузка...'
                  ? () => _handleEmailTap(adminEmail)
                  : null),
          const SizedBox(height: 16),
          _buildContactItem(
              Icons.location_on, 'г. Красноярск', 'пр. Металлургов, 51 К'),
              
          const SizedBox(height: 40),
          
          ElevatedButton(
            onPressed: _showPartnerRequestDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5D4037),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Стать партнёром (оферта)',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text, String label,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12))
          ])
        ]),
      ),
    );
  }

  Widget _buildFooter() {
    final currentYear = DateTime.now().year;
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF3E2723),
      child: Text('© $_startYear-$currentYear «Вкусные моменты»',
          style: const TextStyle(color: Colors.white70)),
    );
  }
}
