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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final GlobalKey _productsSectionKey = GlobalKey();

  // Контроллеры слайдеров
  final PageController _productPageController =
      PageController(viewportFraction: 0.85);
  int _currentProductPage = 0;

  final PageController _featuresPageController =
      PageController(viewportFraction: 0.8);
  int _currentFeaturesPage = 0;

  // Контроллеры формы
  final _contactController = TextEditingController();
  String _selectedContactType = 'phone';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSubtitleRotation();
    _loadShowcaseData();
  }

  @override
  void dispose() {
    _subtitleTimer?.cancel();
    _contactController.dispose();
    _productPageController.dispose();
    _featuresPageController.dispose();
    super.dispose();
  }

  // 🔥 ЛОГИКА ВАЛИДАЦИИ И ОТПРАВКИ (Главная форма)
  void _submitForm() {
    // Запускаем валидацию всех полей формы
    if (_formKey.currentState!.validate()) {
      String contact = _contactController.text;

      // Нормализация перед отправкой
      if (_selectedContactType == 'phone') {
        contact = PhoneValidator.normalizePhone(contact) ?? contact;
      } else if (_selectedContactType == 'telegram') {
        contact = AuthValidator.normalizeTelegram(contact);
      }

      print('Отправка заявки: $contact');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заявка отправлена!')),
      );

      // Опционально: очистить поле после отправки
      _contactController.clear();
    }
  }

  // Динамический валидатор для главной формы
  String? Function(String?) get _currentValidator {
    switch (_selectedContactType) {
      case 'phone':
        return PhoneValidator.validatePhone;
      case 'email':
        return AuthValidator.validateEmail;
      case 'telegram':
        return (value) => AuthValidator.validateSocialLink(value, 'telegram');
      default:
        return (value) => null;
    }
  }

  String get _hintText {
    switch (_selectedContactType) {
      case 'phone':
        return '+7 (999) 123-45-67';
      case 'email':
        return 'example@mail.com';
      case 'telegram':
        return '@username или ссылка';
      default:
        return '';
    }
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

  // 🔥 ЗАГРУЗКА ДАННЫХ
  Future<void> _loadShowcaseData() async {
    try {
      final cacheService = await CacheService.getInstance();
      final localContacts = await cacheService.getAdminContacts();
      final localProducts = await cacheService.getProducts();

      if (localContacts.isNotEmpty && localProducts.isNotEmpty) {
        if (mounted) {
          setState(() {
            _adminContacts = localContacts;
            _products = localProducts.take(7).toList();
            _isLoading = false;
          });
        }
        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity != ConnectivityResult.none) {
          _refreshShowcaseData();
        }
      } else {
        await _refreshShowcaseData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки: $e';
          _isLoading = false;
        });
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
        setState(() {
          _error = 'Нет ответа от сервера';
          _isLoading = false;
        });
        return;
      }

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        setState(() {
          _error = 'Нет данных в ответе';
          _isLoading = false;
        });
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
      final products = productsRaw is List
          ? productsRaw
              .map((item) => Product.fromMap(item as Map<String, dynamic>))
              .toList()
          : <Product>[];

      await cacheService.saveAdminContacts(contacts);
      await cacheService.saveProducts(products);

      if (mounted) {
        setState(() {
          _adminContacts = contacts;
          _products = products.toList();
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка сети: $e';
          _isLoading = false;
        });
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
      print('Ошибка открытия почты: $e');
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
      builder: (context) {
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
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Телефон',
                          groupValue: contactMethod,
                          activeColor: const Color(0xFF5D4037),
                          onChanged: (value) {
                            setStateDialog(() => contactMethod = value!);
                          },
                        ),
                        const Text('Телефон', style: TextStyle(fontSize: 12)),
                        Radio<String>(
                          value: 'Email',
                          groupValue: contactMethod,
                          activeColor: const Color(0xFF5D4037),
                          onChanged: (value) {
                            setStateDialog(() => contactMethod = value!);
                          },
                        ),
                        const Text('Email', style: TextStyle(fontSize: 12)),
                        Radio<String>(
                          value: 'Мессенджер',
                          groupValue: contactMethod,
                          activeColor: const Color(0xFF5D4037),
                          onChanged: (value) {
                            setStateDialog(() => contactMethod = value!);
                          },
                        ),
                        const Text('Мессенджер',
                            style: TextStyle(fontSize: 12)),
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
                          // 🔥 ВАЛИДАЦИЯ В ДИАЛОГЕ
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
                            if (contactValue.trim().isEmpty)
                              validationError = 'Введите номер телефона';
                          } else if (contactMethod == 'Email') {
                            validationError =
                                AuthValidator.validateEmail(contactValue);
                            if (contactValue.trim().isEmpty)
                              validationError = 'Введите Email';
                          } else {
                            validationError = AuthValidator.validateSocialLink(
                                contactValue, 'telegram');
                            if (contactValue.trim().isEmpty)
                              validationError = 'Введите контакт';
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
      print('❌ Ошибка чтения оферты: $e');
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
        child: Form(
          key: _formKey, // Привязываем ключ формы
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
      ),
    );
  }

  // ==========================================
  // 🎨 WIDGET BUILDERS
  // ==========================================

  Widget _buildAppBar() {
    return Container(
      height: 100,
      color: const Color(0xFF5D4037).withOpacity(0.95),
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
          else if (_products.isEmpty)
            const Center(child: Text('Товары не найдены'))
          else
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 420,
                  child: PageView.builder(
                    itemCount: _products.length,
                    controller: _productPageController,
                    onPageChanged: (index) =>
                        setState(() => _currentProductPage = index),
                    itemBuilder: (context, index) =>
                        _buildSlidingProductCard(_products[index]),
                  ),
                ),
                // Стрелка влево
                if (_currentProductPage > 0)
                  Positioned(
                      left: 0,
                      child: _buildNavArrow(
                          icon: Icons.chevron_left,
                          onTap: () => _productPageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut))),
                // Стрелка вправо
                if (_currentProductPage < _products.length - 1)
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
                color: Colors.black.withOpacity(0.08),
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
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(product.name,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${product.price} ₽',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5D4037)))
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
                  color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
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

  // 🔥 ПРЕИМУЩЕСТВА (СЛАЙДЕР СО СТРЕЛКАМИ)
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

          // 🔥 ИСПРАВЛЕНО: Обернули в Stack для стрелок
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 250, // Фиксированная высота слайдера преимуществ
                child: PageView.builder(
                  itemCount: features.length,
                  controller: _featuresPageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentFeaturesPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    // Добавляем отступы для карточки внутри слайдера
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: _buildFeatureCard(features[index]),
                    );
                  },
                ),
              ),

              // 🔥 СТРЕЛКА ВЛЕВО
              if (_currentFeaturesPage > 0)
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

              // 🔥 СТРЕЛКА ВПРАВО
              if (_currentFeaturesPage < features.length - 1)
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

  // Карточка преимущества (используется внутри слайдера)
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
              feature['desc'] as String? ?? '', // Защита от null
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

  // 🔥 СЕКЦИЯ КОНТАКТОВ (ВОССТАНОВЛЕНА С ФОРМОЙ)
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

          // Контакты администратора
          _buildContactItem(Icons.email, adminEmail, 'Напишите нам',
              onTap: adminEmail != 'Загрузка...'
                  ? () => _handleEmailTap(adminEmail)
                  : null),
          const SizedBox(height: 16),
          _buildContactItem(
              Icons.location_on, 'г. Красноярск', 'пр. Металлургов, 51 К'),

          const SizedBox(height: 32),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 32),

          // 🔥 ФОРМА ОБРАТНОЙ СВЯЗИ
          const Text('Оставить заявку',
              style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 16),

          // Выбор типа связи
          DropdownButtonFormField<String>(
            value: _selectedContactType,
            decoration: const InputDecoration(
              labelText: 'Способ связи',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            dropdownColor: const Color(0xFF5D4037),
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(
                  value: 'phone',
                  child:
                      Text('Телефон', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(
                  value: 'email',
                  child: Text('Email', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(
                  value: 'telegram',
                  child:
                      Text('Telegram', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (value) {
              setState(() {
                _selectedContactType = value!;
                _contactController.clear(); // Очищаем при смене типа
              });
            },
          ),
          const SizedBox(height: 16),

          // Поле ввода
          TextFormField(
            controller: _contactController,
            validator: _currentValidator,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ваш контакт',
              hintText: _hintText,
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red.shade200),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red.shade200),
              ),
            ),
            keyboardType: _selectedContactType == 'phone'
                ? TextInputType.phone
                : TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),

          // Кнопка отправки
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5D4037),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Отправить заявку',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 24),

          // Кнопка "Стать партнером" (открывает диалог)
          OutlinedButton(
            onPressed: _showPartnerRequestDialog,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Стать партнёром (оферта)'),
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
