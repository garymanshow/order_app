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
import '../models/product.dart';
import '../models/sheet_metadata.dart';
import '../models/nutrition_info.dart';
import '../models/user.dart';
import '../screens/two_factor_screen.dart';
import '../services/api_service.dart';
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

  // 👇 ДЛЯ PUSH (только Web Push, без FCM)
  bool _pushSubscriptionAttempted = false;
  Timer? _pushReminderTimer;

  AuthProvider({required this.navigatorKey});

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

  // ================== PUSH УВЕДОМЛЕНИЯ ==================

  /// 🔔 Автоматическая подписка на push после входа
  Future<void> _handlePushSubscription(String phone) async {
    if (!kIsWeb) return;

    // Предотвращаем множественные попытки
    if (_pushSubscriptionAttempted) {
      print('ℹ️ Подписка уже была предпринята ранее');
      return;
    }

    _pushSubscriptionAttempted = true;

    try {
      final pushService = WebPushService();
      await pushService.initialize(EnvService.vapidPublicKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('push_user_id', phone);

      if (_currentUser is Employee) {
        // 🔴 СОТРУДНИКИ - обязательная подписка с напоминаниями
        await _handleEmployeePushSubscription(pushService);
      } else {
        // 🟢 КЛИЕНТЫ - опциональная подписка с предложением
        await _handleClientPushSubscription(pushService);
      }
    } catch (e) {
      print('❌ Ошибка в _handlePushSubscription: $e');
    }
  }

  /// 🔴 ДЛЯ СОТРУДНИКОВ - с напоминаниями
  Future<void> _handleEmployeePushSubscription(
      WebPushService pushService) async {
    bool subscribed = await pushService.subscribe();

    if (!subscribed) {
      print('⚠️ Сотрудник не подписался, запускаем напоминания');
      _startPushReminders();
    } else {
      print('✅ Сотрудник успешно подписан');
    }
  }

  /// 🟢 ДЛЯ КЛИЕНТОВ - спрашиваем разрешение
  Future<void> _handleClientPushSubscription(WebPushService pushService) async {
    // Проверяем, может уже подписан
    if (pushService.isSubscribed) {
      return;
    }

    // Проверяем, может уже отказывались
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('push_offer_declined') == true) {
      print('ℹ️ Клиент ранее отказался от уведомлений');
      return;
    }

    // Показываем диалог с объяснением выгоды
    final shouldSubscribe = await _showPushOfferDialog();

    if (shouldSubscribe) {
      bool subscribed = await pushService.subscribe();

      if (subscribed) {
        print('✅ Клиент согласился на уведомления');
        _showThankYouMessage();
      } else {
        print('ℹ️ Клиент хотел подписаться, но не получилось');
      }
    } else {
      print('ℹ️ Клиент отказался от уведомлений');
      await prefs.setBool('push_offer_declined', true);
    }
  }

  /// 💬 Диалог предложения push для клиента
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
                Text(
                  'Мы будем присылать уведомления, когда:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                _buildBenefitItem(
                    Icons.check_circle, '✅ Заказ принят в обработку'),
                _buildBenefitItem(
                    Icons.factory, '🏭 Заказ запущен в производство'),
                _buildBenefitItem(
                    Icons.check_circle, '🍰 Заказ готов к выдаче'),
                _buildBenefitItem(
                    Icons.local_shipping, '🚚 Статус доставки изменился'),
                _buildBenefitItem(Icons.help, '❓ Появились вопросы по заказу'),
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
                        child: Text(
                          'Это бесплатно и займет всего 2 секунды!',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
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

  void _showThankYouMessage() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    '✅ Отлично! Теперь вы будете в курсе всех изменений!')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// 🔔 Запуск напоминаний для сотрудников
  void _startPushReminders() {
    if (_pushReminderTimer != null) return;

    // Показываем напоминание через 5 секунд
    Future.delayed(Duration(seconds: 5), () {
      _checkSubscriptionAndRemind();
    });

    // Запускаем таймер для периодических напоминаний
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
        title: const Text('🔔 Не забудьте включить уведомления'),
        content: const Text(
            'Для быстрого реагирования на заказы необходимо разрешить уведомления.\n\n'
            'Нажмите "Разрешить" в следующем диалоге браузера.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Напомнить позже'),
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
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Уведомления включены!')));
              }
            },
            child: const Text('Попробовать сейчас'),
          ),
        ],
      ),
    );
  }

  // ================== ДЕСЕРИАЛИЗАЦИЯ ДАННЫХ ==================

  ClientData _deserializeClientData(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) {
      return ClientData();
    }

    print('🔍 Десериализация products: ${data['products']}');
    print('🔍 Десериализация orders: ${data['orders']}');
    print('🔍 Десериализация clients: ${data['clients']}');

    final clientData = ClientData();
    final clientDataMap = data;

    // Сначала загружаем продукты, чтобы создать карту displayNames
    if (clientDataMap['products'] != null) {
      print('🔍 Десериализация products (используем fromMap)');
      clientData.products = (clientDataMap['products'] as List?)
              ?.map((item) => Product.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // Создаем карту ID продукта → отформатированное название
    final Map<String, String> productDisplayNames = {};
    for (var product in clientData.products) {
      productDisplayNames[product.id] = product.displayName;
    }

    // Загружаем заказы с использованием displayNames
    if (clientDataMap['orders'] != null) {
      clientData.orders = (clientDataMap['orders'] as List?)
              ?.map((item) => OrderItem.fromMap(
                    item as Map<String, dynamic>,
                    productDisplayNames: productDisplayNames,
                  ))
              .toList() ??
          [];
    }

    if (clientDataMap['compositions'] != null) {
      clientData.compositions = (clientDataMap['compositions'] as List?)
              ?.map(
                  (item) => Composition.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    if (clientDataMap['fillings'] != null) {
      clientData.fillings = (clientDataMap['fillings'] as List?)
              ?.map((item) => Filling.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    if (clientDataMap['nutritionInfos'] != null) {
      clientData.nutritionInfos = (clientDataMap['nutritionInfos'] as List?)
              ?.map((item) =>
                  NutritionInfo.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    if (clientDataMap['deliveryConditions'] != null) {
      clientData.deliveryConditions =
          (clientDataMap['deliveryConditions'] as List?)
                  ?.map((item) =>
                      DeliveryCondition.fromJson(item as Map<String, dynamic>))
                  .toList() ??
              [];
    }

    if (clientDataMap['clientCategories'] != null) {
      clientData.clientCategories = (clientDataMap['clientCategories'] as List?)
              ?.map((item) =>
                  ClientCategory.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    if (clientDataMap['clients'] != null) {
      clientData.clients = (clientDataMap['clients'] as List?)
              ?.map((item) => Client.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    if (clientDataMap['cart'] != null && clientDataMap['cart'] is Map) {
      clientData.cart = clientDataMap['cart'] as Map<String, dynamic>;
    }

    print('🔍 Проверка заказов:');
    if (clientData.orders.isNotEmpty) {
      for (var order in clientData.orders) {
        print(
            '   - Заказ: ${order.displayName}, статус: ${order.status}, цена: ${order.totalPrice}');
      }
    } else {
      print('   - Заказы отсутствуют');
    }

    clientData.buildIndexes();
    return clientData;
  }

  Map<String, SheetMetadata> _deserializeMetadata(dynamic metadata) {
    print('📊 _deserializeMetadata START');
    print('📊 Тип metadata: ${metadata.runtimeType}');
    print('📊 metadata keys: ${metadata is Map ? metadata.keys : 'не Map'}');

    if (metadata == null || metadata is! Map<String, dynamic>) {
      print('📊 metadata is null or not Map, возвращаем {}');
      return {};
    }

    final result = <String, SheetMetadata>{};
    final metadataMap = metadata;

    for (final entry in metadataMap.entries) {
      final key = entry.key;
      final value = entry.value;

      print('📊 Обработка листа: $key');
      print('   - value type: ${value.runtimeType}');

      if (value is Map<String, dynamic>) {
        try {
          print('   - lastUpdate: ${value['lastUpdate']}');
          print('   - editor: ${value['editor']}');

          final sheetMetadata = SheetMetadata.fromJson(value);
          result[key] = sheetMetadata;
          print('   ✅ Успешно создан SheetMetadata для $key');
        } catch (e) {
          print('   ❌ Ошибка создания SheetMetadata для $key: $e');
          print('   📄 Проблемные данные: $value');
        }
      } else {
        print('   ⚠️ value не является Map, пропускаем');
      }
    }

    print('📊 _deserializeMetadata END, загружено: ${result.length}');
    return result;
  }

  // ================== ИНИЦИАЛИЗАЦИЯ ==================

  Future<void> init() async {
    print('🟢 AuthProvider.init() START');
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    print('🟢 SharedPreferences получены');
    final userData = prefs.getString('auth_user');
    final timestamp = prefs.getString('auth_timestamp');
    final cachedClientData = prefs.getString('client_data');

    print('🟢 userData: ${userData != null}');
    print('🟢 timestamp: ${timestamp != null}');
    print('🟢 cachedClientData: ${cachedClientData != null}');

    if (userData != null && timestamp != null) {
      try {
        final json = jsonDecode(userData);

        if (json['role'] == null) {
          _currentUser = Client.fromJson(json);
        } else {
          _currentUser = Employee.fromJson(json);
        }

        if (cachedClientData != null) {
          try {
            final clientDataJson = jsonDecode(cachedClientData);
            _clientData = ClientData.fromJson(clientDataJson);
            print('✅ ClientData восстановлен из SharedPreferences');
            print('   - Продуктов: ${_clientData?.products.length}');
            print('   - Заказов: ${_clientData?.orders.length}');
            print('   - Клиентов: ${_clientData?.clients.length}');

            _clientData?.buildIndexes();
            print('   - Индексы перестроены');
          } catch (e) {
            print('❌ Ошибка восстановления ClientData: $e');
            _clientData = null;
          }
        }
      } catch (e) {
        print('Ошибка восстановления авторизации: $e');
        await logout();
      }
    }

    _isLoading = false;
    notifyListeners();
    print('🟢 AuthProvider.init() END');
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

      final prefs = await SharedPreferences.getInstance();
      final localMetaJson = prefs.getString('local_metadata');
      Map<String, SheetMetadata> localMetadata = {};

      if (localMetaJson != null) {
        final metaMap = jsonDecode(localMetaJson) as Map<String, dynamic>;
        localMetadata = metaMap.map((key, value) => MapEntry(
            key, SheetMetadata.fromJson(value as Map<String, dynamic>)));
      }

      final apiService = ApiService();
      final authResponse = await apiService.authenticate(
        phone: normalizedPhone,
        localMetadata: localMetadata,
      );

      if (authResponse != null) {
        final userData = authResponse['user'];
        print('🟢 userData получен: $userData');

        User? tempUser;

        if (userData is List) {
          _availableRoles = userData
              .map((item) => Employee.fromJson(item as Map<String, dynamic>))
              .toList();
          tempUser = null;
        } else {
          if (userData['role'] != null) {
            tempUser = Employee.fromJson(userData);
            _availableRoles = null;
          } else {
            tempUser = Client.fromJson(userData);
            _availableRoles = null;
          }
        }

        print('🟢 Временный пользователь: $tempUser');

        // 🔥 ПРОВЕРКА 2FA ДЛЯ СОТРУДНИКОВ
        if (tempUser is Employee && tempUser.twoFactorAuth) {
          print('🔐 Требуется 2FA для сотрудника: ${tempUser.name}');

          if (!tempUser.canUseTwoFactor) {
            throw Exception('Для сотрудника с 2FA не указан email');
          }

          final twoFactorResult = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TwoFactorScreen(employee: tempUser as Employee),
            ),
          );

          if (twoFactorResult != true) {
            print('❌ 2FA не пройдена или отменена');
            _isLoading = false;
            notifyListeners();
            return;
          }

          print('✅ 2FA успешно пройдена');
        }

        _currentUser = tempUser;

        if (userData is List && _availableRoles != null) {
          // Логика выбора роли, если нужно
        }

        print('🟢 После установки _currentUser:');
        print('   - _currentUser: ${_currentUser}');
        print('   - _currentUser тип: ${_currentUser.runtimeType}');
        print('   - _currentUser?.phone: ${_currentUser?.phone}');

        final data = authResponse['data'];
        final metadata = authResponse['metadata'];

        if (data == null || metadata == null) {
          throw Exception('Сервер не вернул данные или метаданные');
        }

        print('🟢 Шаг 2: _deserializeClientData выполнен');
        _clientData = _deserializeClientData(data);

        print('🟢 Шаг 2.1: ClientData десериализован');
        print('   - products: ${_clientData?.products.length}');
        print('   - orders: ${_clientData?.orders.length}');
        print('   - clients: ${_clientData?.clients.length}');

        _metadata = _deserializeMetadata(metadata);
        print('🟢 Шаг 3: _metadata заполнен, листов: ${_metadata?.length}');

        if (_clientData != null) {
          try {
            print('🟢 Шаг 5: Проверка клиентов перед сохранением');
            print('🟢 Шаг 6: Начинаем toJson для всех клиентов');
            final clientDataJson = _clientData!.toJson();
            await prefs.setString('client_data', jsonEncode(clientDataJson));
            print('🟢 Шаг 8: ClientData сохранен');
          } catch (e) {
            print('❌ Ошибка сохранения ClientData: $e');
            rethrow;
          }
        }

        await prefs.setString(
            'auth_user', jsonEncode(_currentUser?.toJson() ?? {}));
        await prefs.setString(
            'auth_timestamp', DateTime.now().toIso8601String());

        final serializableMetadata = _metadata?.map((key, value) {
          return MapEntry(key, value.toJson());
        });
        await prefs.setString(
            'local_metadata', jsonEncode(serializableMetadata ?? {}));

        print('✅ Авторизация успешна, данные загружены');
        print('🟢 Финальное состояние:');
        print('   - _currentUser: ${_currentUser}');
        print('   - isAuthenticated: ${isAuthenticated}');

        // 👇 ВЫЗЫВАЕМ ПОДПИСКУ НА PUSH ПОСЛЕ УСПЕШНОГО ВХОДА
        if (kIsWeb && _currentUser != null) {
          _handlePushSubscription(_currentUser!.phone!).catchError((e) {
            print('⚠️ Ошибка фоновой подписки: $e');
          });
        }
      } else {
        throw Exception('Сервер вернул null ответ');
      }
    } catch (e) {
      print('❌ Ошибка входа: $e');
      _currentUser = null;
      _clientData = null;
      _metadata = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================== УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЕМ ==================

  void selectRole(Employee selectedRole) {
    _currentUser = selectedRole;
    _availableRoles = null;
    notifyListeners();
  }

  void setClient(Client client) {
    _currentUser = client;
    notifyListeners();
  }

  Future<void> logout() async {
    _pushSubscriptionAttempted = false;
    _pushReminderTimer?.cancel();
    _pushReminderTimer = null;

    _currentUser = null;
    _clientData = null;
    _metadata = null;
    _availableRoles = null;

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
      print('✅ Все данные очищены при выходе');
    } catch (e) {
      print('❌ Ошибка при выходе: $e');
    }
  }

  Future<void> clearAllCache() async {
    if (!kDebugMode) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('🧹 Весь кэш приложения очищен');

    _currentUser = null;
    _clientData = null;
    _metadata = null;
    _availableRoles = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pushReminderTimer?.cancel();
    super.dispose();
  }
}
