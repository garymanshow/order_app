// lib/providers/auth_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_category.dart';
import '../models/client.dart';
import '../models/client_data.dart';
import '../models/composition.dart';
import '../models/delivery_condition.dart';
import '../models/employee.dart';
import '../models/filling.dart';
import '../models/order_item.dart';
import '../models/price_category.dart';
import '../models/product.dart';
import '../models/nutrition_info.dart';
import '../models/user.dart';
import '../models/sheet_metadata.dart';
import '../screens/two_factor_screen.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/sync_service.dart';
import '../services/web_push_service.dart';
import '../services/env_service.dart';
import '../utils/phone_validator.dart';

class AuthProvider with ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey;

  User? _currentUser;
  ClientData? _clientData;
  Map<String, SheetMetadata>? _metadata;
  List<Employee>? _availableRoles;
  bool _isLoading = false;
  bool _isOffline = false;

  bool _clientSelected = false;

  bool get clientSelected => _clientSelected;

  // 👇 ДЛЯ PUSH (только Web Push, без FCM)
  bool _pushSubscriptionAttempted = false;
  Timer? _pushReminderTimer;

  // 👇 СЕРВИСЫ
  late final CacheService _cacheService;
  late final SyncService _syncService;
  final ApiService _apiService = ApiService();

  AuthProvider({required this.navigatorKey});

  // Геттеры
  User? get currentUser => _currentUser;
  ClientData? get clientData => _clientData;
  Map<String, SheetMetadata>? get metadata => _metadata;
  List<Employee>? get availableRoles => _availableRoles;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmployee => _currentUser is Employee;
  bool get isClient => _currentUser is Client;
  bool get hasMultipleRoles =>
      _availableRoles != null && _availableRoles!.length > 1;
  bool get isOffline => _isOffline;

  // ================== ИНИЦИАЛИЗАЦИЯ ==================

  Future<void> init() async {
    print('🟢 AuthProvider.init() START');
    _isLoading = true;
    notifyListeners();

    // Инициализируем сервисы
    _cacheService = await CacheService.getInstance();
    _syncService = SyncService();

    // Проверяем наличие кэшированных данных
    final hasCachedData = await _loadCachedData();

    if (hasCachedData) {
      print('✅ Загружены кэшированные данные');
      _isLoading = false;
      notifyListeners();

      // Фоновая синхронизация
      _syncService.sync().catchError((e) {
        print('⚠️ Фоновая синхронизация: $e');
      });
    } else {
      _isLoading = false;
      notifyListeners();
    }

    print('🟢 AuthProvider.init() END');
  }

  // ================== ЗАГРУЗКА КЭШИРОВАННЫХ ДАННЫХ ==================
  Future<bool> _loadCachedData() async {
    try {
      // Загружаем пользователя из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('auth_user');

      if (userData != null) {
        final json = jsonDecode(userData);
        if (json['role'] == null) {
          _currentUser = Client.fromJson(json);
        } else {
          _currentUser = Employee.fromJson(json);
        }
      }

      // Загружаем данные из Hive
      final orders = _cacheService.getOrders();
      final products = _cacheService.getProducts();
      final fillings = _cacheService.getFillings();
      final compositions = _cacheService.getCompositions();
      final priceCategories = _cacheService.getPriceCategories();

      if (orders.isNotEmpty || products.isNotEmpty) {
        // 🔥 ИСПРАВЛЕНО: создаём ClientData через сеттеры
        _clientData = ClientData()
          ..products = products
          ..orders = orders
          ..fillings = fillings
          ..compositions = compositions
          ..priceCategories = priceCategories;

        _clientData?.buildIndexes();

        print('📦 Кэшированные данные загружены:');
        print('   - Заказов: ${orders.length}');
        print('   - Продуктов: ${products.length}');
        print('   - Начинок: ${fillings.length}');
        print('   - Составов: ${compositions.length}');
        print('   - Категорий: ${priceCategories.length}');

        return true;
      }

      return false;
    } catch (e) {
      print('❌ Ошибка загрузки кэша: $e');
      return false;
    }
  }

  // ================== АУТЕНТИФИКАЦИЯ ==================

  Future<void> login(String phone, {required BuildContext context}) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🟢 login() начат с телефоном: $phone');

      final normalizedPhone = PhoneValidator.normalizePhone(phone);
      if (normalizedPhone == null) {
        throw Exception('Неверный формат телефона');
      }
      print('🟢 Нормализованный телефон: $normalizedPhone');

      // Загружаем локальные метаданные для сравнения
      final localMetadata = _cacheService.getMetadata();

      // Пытаемся получить данные с сервера
      Map<String, dynamic>? authResponse;
      bool hasNetwork = await _checkNetwork();

      if (hasNetwork) {
        try {
          authResponse = await _apiService.authenticate(
            phone: normalizedPhone,
            localMetadata: localMetadata,
          );
        } catch (e) {
          print('⚠️ Ошибка сети: $e');
          authResponse = null;
        }
      }

      if (authResponse != null) {
        // Есть ответ от сервера — обновляем кэш
        // 🔥 ИСПРАВЛЕНО: Оборачиваем обработку ответа в try-catch
        try {
          await _handleServerResponse(authResponse, normalizedPhone, context);
          _isOffline = false;
        } catch (e) {
          print('❌ Ошибка обработки ответа сервера: $e');
          // Если ошибка при парсинге, пробуем кэш
          final hasCache = await _loadCachedData();
          if (hasCache && _currentUser != null) {
            _isOffline = true;
            _showOfflineModeDialog(context);
          } else {
            rethrow; // Если кэша нет, кидаем ошибку дальше
          }
        }
      } else {
        // Нет сети — пытаемся загрузить из кэша
        final hasCache = await _loadCachedData();
        if (hasCache && _currentUser != null) {
          _isOffline = true;
          _showOfflineModeDialog(context);
        } else {
          throw Exception('Нет интернета и нет кэшированных данных');
        }
      }

      // 🔥 ВАЖНО: Если мы здесь, значит авторизация прошла успешно (либо онлайн, либо из кэша)
      // Убеждаемся, что isLoading false перед тем как идти дальше
      _isLoading = false;
      notifyListeners();

      // 🔥 PUSH ПОДПИСКА: Запускаем отдельно, чтобы ошибки не ломали вход
      if (kIsWeb && _currentUser != null) {
        // Запускаем без await, чтобы не блокировать UI, и ловим все ошибки внутри
        _handlePushSubscriptionSafe(_currentUser!.phone!);
      }
    } catch (e) {
      print('❌ Критическая ошибка входа: $e');
      _currentUser = null;
      _clientData = null;
      _metadata = null;
      _isLoading = false; // Убеждаемся что ложим спиннер при ошибке
      notifyListeners();
      rethrow;
    }
    // finally убран, так как мы управляем _isLoading явно в успешном пути и в catch
  }

  // 🔥 БЕЗОПАССНЫЙ ОБЕРТКА ДЛЯ PUSH
  Future<void> _handlePushSubscriptionSafe(String phone) async {
    try {
      await _handlePushSubscription(phone);
    } catch (e) {
      print('⚠️ PUSH ошибка (безопасный режим): $e');
      // Ошибка здесь никак не повлияет на состояние авторизации
    }
  }

  Future<void> _handleServerResponse(
    Map<String, dynamic> authResponse,
    String phone,
    BuildContext context,
  ) async {
    final userData = authResponse['user'];
    final data = authResponse['data'];
    final metadata = authResponse['metadata'];

    if (userData == null) {
      throw Exception('Сервер не вернул данные пользователя');
    }

    // Десериализуем пользователя
    if (userData is List) {
      _availableRoles = userData
          .map((item) => Employee.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      if (userData['role'] != null) {
        _currentUser = Employee.fromJson(userData);
      } else {
        _currentUser = Client.fromJson(userData);
      }
    }

    // 🔥 ПРОВЕРКА 2FA ДЛЯ СОТРУДНИКОВ
    if (_currentUser is Employee && (_currentUser as Employee).twoFactorAuth) {
      await _handleTwoFactorAuth(context);
    }

    // Сохраняем данные в кэш
    if (data != null && metadata != null) {
      _clientData = _deserializeClientData(data);
      _metadata = _deserializeMetadata(metadata);

      // Сохраняем в Hive
      await _saveToCache();

      // Сохраняем в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'auth_user', jsonEncode(_currentUser?.toJson() ?? {}));
      await prefs.setString('auth_timestamp', DateTime.now().toIso8601String());
    }
  }

  Future<void> _handleTwoFactorAuth(BuildContext context) async {
    final employee = _currentUser as Employee;

    if (!employee.canUseTwoFactor) {
      throw Exception('Для сотрудника с 2FA не указан email');
    }

    final twoFactorResult = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TwoFactorScreen(employee: employee),
      ),
    );

    if (twoFactorResult != true) {
      throw Exception('2FA не пройдена');
    }
  }

  Future<void> _saveToCache() async {
    if (_clientData == null) return;

    await _cacheService.saveOrders(_clientData!.orders);
    await _cacheService.saveProducts(_clientData!.products);
    await _cacheService.saveFillings(_clientData!.fillings);
    await _cacheService.saveCompositions(_clientData!.compositions);
    await _cacheService.savePriceCategories(_clientData!.priceCategories);

    if (_metadata != null) {
      await _cacheService.saveMetadata(_metadata!);
    }

    print('✅ Данные сохранены в Hive кэш');
  }

  Future<bool> _checkNetwork() async {
    try {
      final result = await _apiService.testConnection();
      return result;
    } catch (e) {
      return false;
    }
  }

  void _showOfflineModeDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📱 Офлайн-режим: данные загружены из кэша'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // ================== PUSH УВЕДОМЛЕНИЯ ==================

  Future<void> _handlePushSubscription(String phone) async {
    if (!kIsWeb) return;
    if (_pushSubscriptionAttempted) return;

    _pushSubscriptionAttempted = true;

    try {
      final pushService = WebPushService();
      await pushService.initialize(EnvService.vapidPublicKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('push_user_id', phone);

      if (_currentUser is Employee) {
        await _handleEmployeePushSubscription(pushService);
      } else {
        await _handleClientPushSubscription(pushService);
      }
    } catch (e) {
      print('❌ Ошибка в _handlePushSubscription: $e');
    }
  }

  Future<void> _handleEmployeePushSubscription(
      WebPushService pushService) async {
    bool subscribed = await pushService.subscribe();
    if (!subscribed) {
      _startPushReminders();
    }
  }

  Future<void> _handleClientPushSubscription(WebPushService pushService) async {
    if (pushService.isSubscribed) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('push_offer_declined') == true) return;

    final shouldSubscribe = await _showPushOfferDialog();
    if (shouldSubscribe) {
      await pushService.subscribe();
    } else {
      await prefs.setBool('push_offer_declined', true);
    }
  }

  Future<bool> _showPushOfferDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('🔔 Быть в курсе заказа?')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Мы будем присылать уведомления, когда:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                _buildBenefitItem(
                    Icons.check_circle, '✅ Заказ принят в обработку'),
                _buildBenefitItem(
                    Icons.factory, '🏭 Заказ запущен в производство'),
                _buildBenefitItem(
                    Icons.check_circle, '🍰 Заказ готов к выдаче'),
                _buildBenefitItem(
                    Icons.local_shipping, '🚚 Статус доставки изменился'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Expanded(
                          child:
                              Text('Это бесплатно и займет всего 2 секунды!')),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    Text('Нет, спасибо', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('✅ Да, хочу быть в курсе!'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _startPushReminders() {
    if (_pushReminderTimer != null) return;

    Future.delayed(Duration(seconds: 5), () => _checkSubscriptionAndRemind());
    _pushReminderTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      _checkSubscriptionAndRemind();
    });
  }

  Future<void> _checkSubscriptionAndRemind() async {
    if (!kIsWeb) return;

    final pushService = WebPushService();
    await pushService.initialize(EnvService.vapidPublicKey);

    if (pushService.isSubscribed) {
      _pushReminderTimer?.cancel();
      _pushReminderTimer = null;
      return;
    }

    _showPushReminder();
  }

  void _showPushReminder() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🔔 Не забудьте включить уведомления'),
        content: Text(
            'Для быстрого реагирования на заказы необходимо разрешить уведомления.\n\n'
            'Нажмите "Разрешить" в следующем диалоге браузера.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Напомнить позже'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final pushService = WebPushService();
              await pushService.initialize(EnvService.vapidPublicKey);
              final subscribed = await pushService.subscribe();
              if (subscribed) {
                _pushReminderTimer?.cancel();
                _pushReminderTimer = null;
              }
            },
            child: Text('Попробовать сейчас'),
          ),
        ],
      ),
    );
  }

  // ================== ДЕСЕРИАЛИЗАЦИЯ ==================

  ClientData _deserializeClientData(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) {
      return ClientData();
    }

    final clientData = ClientData();
    final clientDataMap = data;

    // Десериализация products
    if (clientDataMap['products'] != null) {
      clientData.products = (clientDataMap['products'] as List?)
              ?.map((item) => Product.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // Создаем карту displayNames для заказов
    final Map<String, String> productDisplayNames = {};
    for (var product in clientData.products) {
      productDisplayNames[product.id] = product.displayName;
    }

    // Десериализация orders
    if (clientDataMap['orders'] != null) {
      clientData.orders = (clientDataMap['orders'] as List?)
              ?.map((item) => OrderItem.fromMap(
                    item as Map<String, dynamic>,
                    productDisplayNames: productDisplayNames,
                  ))
              .toList() ??
          [];
    }

    // Десериализация compositions
    if (clientDataMap['compositions'] != null) {
      clientData.compositions = (clientDataMap['compositions'] as List?)
              ?.map(
                  (item) => Composition.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // Десериализация fillings
    if (clientDataMap['fillings'] != null) {
      clientData.fillings = (clientDataMap['fillings'] as List?)
              ?.map((item) => Filling.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // Десериализация nutritionInfos
    if (clientDataMap['nutritionInfos'] != null) {
      clientData.nutritionInfos = (clientDataMap['nutritionInfos'] as List?)
              ?.map((item) =>
                  NutritionInfo.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // Десериализация deliveryConditions
    if (clientDataMap['deliveryConditions'] != null) {
      clientData.deliveryConditions =
          (clientDataMap['deliveryConditions'] as List?)
                  ?.map((item) =>
                      DeliveryCondition.fromJson(item as Map<String, dynamic>))
                  .toList() ??
              [];
    }

    // Десериализация clientCategories
    if (clientDataMap['clientCategories'] != null) {
      clientData.clientCategories = (clientDataMap['clientCategories'] as List?)
              ?.map((item) =>
                  ClientCategory.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // Десериализация clients
    if (clientDataMap['clients'] != null) {
      clientData.clients = (clientDataMap['clients'] as List?)
              ?.map((item) => Client.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // 🔥 Десериализация priceCategories
    if (clientDataMap['priceCategories'] != null) {
      clientData.priceCategories = (clientDataMap['priceCategories'] as List?)
              ?.map((item) =>
                  PriceCategory.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // Десериализация cart
    if (clientDataMap['cart'] != null && clientDataMap['cart'] is Map) {
      clientData.cart = clientDataMap['cart'] as Map<String, dynamic>;
    }

    clientData.buildIndexes();
    return clientData;
  }

  Map<String, SheetMetadata> _deserializeMetadata(dynamic metadata) {
    if (metadata == null || metadata is! Map<String, dynamic>) {
      return {};
    }

    final result = <String, SheetMetadata>{};

    for (final entry in metadata.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        try {
          result[entry.key] = SheetMetadata.fromJson(value);
        } catch (e) {
          print('⚠️ Ошибка десериализации метаданных для ${entry.key}: $e');
        }
      } else if (value is SheetMetadata) {
        // Если уже SheetMetadata, просто добавляем
        result[entry.key] = value;
      }
    }
    return result;
  }

  // ================== УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЕМ ==================

  void selectRole(Employee selectedRole) {
    _currentUser = selectedRole;
    _availableRoles = null;
    notifyListeners();
  }

  void setClient(Client client) {
    _currentUser = client;
    _clientSelected = true;
    notifyListeners();
  }

  // 🔥 СБРОС ВЫБРАННОГО КЛИЕНТА (при возврате к списку)
  void resetClientSelection() {
    _clientSelected = false;
    notifyListeners();
  }

  // 🔥 ВЫБОР КЛИЕНТА (при входе в прайс-лист)
  void selectClient(Client client) {
    _currentUser = client;
    _clientSelected = true;
    notifyListeners();
  }

  Future<void> logout() async {
    _clientSelected = false;
    _pushSubscriptionAttempted = false;
    _pushReminderTimer?.cancel();
    _pushReminderTimer = null;

    _currentUser = null;
    _clientData = null;
    _metadata = null;
    _availableRoles = null;
    _isOffline = false;

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_user');
      await prefs.remove('auth_timestamp');
      await prefs.remove('local_metadata');
      await prefs.remove('client_data');
      await prefs.remove('selected_client_id');
      await prefs.remove('current_user_phone');
      await prefs.remove('push_offer_declined');

      // Очищаем Hive
      await _cacheService.clearAll();

      print('✅ Все данные очищены при выходе');
    } catch (e) {
      print('❌ Ошибка при выходе: $e');
    }
  }

  Future<void> clearAllCache() async {
    if (!kDebugMode) return;
    await _cacheService.clearAll();
    print('🧹 Весь кэш очищен');
  }

  @override
  void dispose() {
    _pushReminderTimer?.cancel();
    super.dispose();
  }
}
