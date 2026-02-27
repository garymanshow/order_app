// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
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
import '../services/api_service.dart';
import '../utils/phone_validator.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  ClientData? _clientData;
  Map<String, SheetMetadata>? _metadata;
  List<Employee>? _availableRoles;
  bool _isLoading = false;
  String? _fcmToken;

  User? get currentUser => _currentUser;
  ClientData? get clientData => _clientData;
  Map<String, SheetMetadata>? get metadata => _metadata;
  List<Employee>? get availableRoles => _availableRoles;
  String? get fcmToken => _fcmToken;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmployee => _currentUser is Employee;
  bool get isClient => _currentUser is Client;
  bool get hasMultipleRoles =>
      _availableRoles != null && _availableRoles!.length > 1;

  // 🔔 FCM: метод получения токена с учётом платформы
  Future<String?> getFcmToken() async {
    try {
      if (kIsWeb) {
        final status = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        if (status.authorizationStatus != AuthorizationStatus.authorized) {
          print('⚠️ Пользователь не разрешил уведомления');
          return null;
        }
      }

      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        _fcmToken = token;
        print('✅ FCM Token получен: ${token.substring(0, 20)}...');
        return token;
      } else {
        print('⚠️ FCM Token не получен (token is null)');
        return null;
      }
    } catch (e) {
      print('❌ Ошибка получения FCM токена: $e');
      return null;
    }
  }

  // 🔔 FCM: метод отправки токена на сервер
  Future<void> sendFcmTokenToServer(String? phoneNumber, String? token) async {
    if (phoneNumber == null ||
        phoneNumber.isEmpty ||
        token == null ||
        token.isEmpty) {
      return;
    }

    try {
      final apiService = ApiService();
      await apiService.sendFcmToken(phoneNumber: phoneNumber, fcmToken: token);
      print('✅ FCM Token отправлен на сервер для $phoneNumber');
    } catch (e) {
      print('❌ Ошибка отправки FCM токена на сервер: $e');
    }
  }

  // 🔔 FCM: подписка на обновление токена
  void subscribeToFcmTokenRefresh() {
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      print(
          '⚠️ FCM не поддерживается на десктопных платформах. Пропускаем инициализацию.');
      return;
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('🔄 FCM Token обновлён: ${newToken.substring(0, 20)}...');

      _fcmToken = newToken;

      if (_currentUser != null && _currentUser!.phone?.isNotEmpty == true) {
        await sendFcmTokenToServer(_currentUser!.phone, newToken);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);

      notifyListeners();
    });
  }

  // 🔥 ДЕСЕРИАЛИЗАЦИЯ ДАННЫХ КЛИЕНТА
  ClientData _deserializeClientData(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) {
      return ClientData();
    }

    print('🔍 Десериализация products: ${data['products']}');
    print('🔍 Десериализация orders: ${data['orders']}');
    print('🔍 Десериализация clients: ${data['clients']}');

    final clientData = ClientData();
    final clientDataMap = data;

    // 🔥 Сначала загружаем продукты, чтобы создать карту displayNames
    if (clientDataMap['products'] != null) {
      print('🔍 Десериализация products (используем fromMap)');
      clientData.products = (clientDataMap['products'] as List?)
              ?.map((item) => Product.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [];
    }

    // 🔥 Создаем карту ID продукта → отформатированное название
    final Map<String, String> productDisplayNames = {};
    for (var product in clientData.products) {
      productDisplayNames[product.id] = product.displayName;
    }

    // 🔥 Загружаем заказы с использованием displayNames
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

  // 🔥 ДЕСЕРИАЛИЗАЦИЯ МЕТАДАННЫХ
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

  Future<void> init() async {
    print('🟢 AuthProvider.init() START');
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    print('🟢 SharedPreferences получены');
    final userData = prefs.getString('auth_user');
    final timestamp = prefs.getString('auth_timestamp');
    final cachedToken = prefs.getString('fcm_token');
    final cachedClientData = prefs.getString('client_data');

    print('🟢 userData: ${userData != null}');
    print('🟢 timestamp: ${timestamp != null}');
    print('🟢 cachedToken: ${cachedToken != null}');
    print('🟢 cachedClientData: ${cachedClientData != null}');

    subscribeToFcmTokenRefresh();

    getFcmToken().then((token) {
      _fcmToken = token ?? cachedToken;

      if (token != null &&
          token != cachedToken &&
          _currentUser != null &&
          _currentUser!.phone?.isNotEmpty == true) {
        sendFcmTokenToServer(_currentUser!.phone, token);
      }
    });

    if (userData != null && timestamp != null) {
      try {
        final json = jsonDecode(userData);

        if (json['role'] == null) {
          _currentUser = Client.fromJson(json);
        } else {
          _currentUser = Employee.fromJson(json);
        }
        _fcmToken = cachedToken;

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

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД LOGIN
  Future<void> login(String phone, {String? fcmToken}) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🟢 login() начат с телефоном: $phone');

      final normalizedPhone = PhoneValidator.normalizePhone(phone);
      if (normalizedPhone == null) {
        throw Exception('Неверный формат телефона');
      }
      print('🟢 Нормализованный телефон: $normalizedPhone');

      String? tokenToUse;

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        tokenToUse = fcmToken ?? await getFcmToken();
      }

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
        fcmToken: tokenToUse,
      );

      if (authResponse != null) {
        final userData = authResponse['user'];
        print('🟢 userData получен: $userData');

        if (userData is List) {
          _availableRoles = userData
              .map((item) => Employee.fromJson(item as Map<String, dynamic>))
              .toList();
          _currentUser = null;
        } else {
          if (userData['role'] != null) {
            _currentUser = Employee.fromJson(userData);
            _availableRoles = null;
          } else {
            _currentUser = Client.fromJson(userData);
            _availableRoles = null;
          }
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

        _fcmToken = tokenToUse;
        print('🟢 Шаг 4: _fcmToken установлен');

        if (_clientData != null) {
          try {
            print('🟢 Шаг 5: Проверка клиентов перед сохранением');
            for (int i = 0; i < _clientData!.clients.length; i++) {
              final client = _clientData!.clients[i];
              try {
                print('   Клиент $i: ${client.name}');
                final clientJson = client.toJson();
                print('   ✅ toJson для клиента $i успешен');
              } catch (e) {
                print('❌ Ошибка toJson для клиента $i: $e');
                rethrow;
              }
            }

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

        if (tokenToUse != null) {
          await prefs.setString('fcm_token', tokenToUse);
        }

        print('✅ Авторизация успешна, данные загружены');
        print('🟢 Финальное состояние:');
        print('   - _currentUser: ${_currentUser}');
        print('   - isAuthenticated: ${isAuthenticated}');
      } else {
        throw Exception('Сервер вернул null ответ');
      }
    } catch (e) {
      print('❌ Ошибка входа: $e');
      _currentUser = null;
      _clientData = null;
      _metadata = null;
      _fcmToken = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
    _currentUser = null;
    _clientData = null;
    _metadata = null;
    _availableRoles = null;
    _fcmToken = null;

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_user');
      await prefs.remove('auth_timestamp');
      await prefs.remove('local_metadata');
      await prefs.remove('client_data');
      await prefs.remove('fcm_token');
      await prefs.remove('selected_client_id');
      await prefs.remove('current_user_phone');
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
    _fcmToken = null;
    notifyListeners();
  }
}
