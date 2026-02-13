// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/client_data.dart';
import '../models/sheet_metadata.dart';
import '../services/api_service.dart';

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
      // Для веба требуется запрос разрешения на уведомления
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

  // 🔔 FCM: метод отправки токена на сервер (безопасная работа с nullable)
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

  // 🔔 FCM: подписка на обновление токена (вызывается один раз при старте приложения)
  void subscribeToFcmTokenRefresh() {
    // FCM не поддерживается на десктопных платформах (Linux, Windows, macOS)
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

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('auth_user');
    final timestamp = prefs.getString('auth_timestamp');
    final cachedToken = prefs.getString('fcm_token');

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
      } catch (e) {
        print('Ошибка восстановления авторизации: $e');
        await logout();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД LOGIN С ПОЛНЫМ ОТКЛЮЧЕНИЕМ FCM НА ДЕСКТОПЕ
  Future<void> login(String phone, {String? fcmToken}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 🔥 ПОЛНОЕ ОТКЛЮЧЕНИЕ FCM НА ДЕСКТОПНЫХ ПЛАТФОРМАХ
      String? tokenToUse;

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // Только на мобильных платформах получаем FCM токен
        tokenToUse = fcmToken ?? await getFcmToken();
      }
      // На десктопе tokenToUse остается null

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
        phone: phone,
        localMetadata: localMetadata,
        fcmToken: tokenToUse, // Может быть null - это нормально
      );

      if (authResponse != null) {
        final userData = authResponse['user'];

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

        _clientData = authResponse['data'];
        _metadata = authResponse['metadata'];
        _fcmToken = tokenToUse;

        await prefs.setString(
            'auth_user', jsonEncode(_currentUser?.toJson() ?? {}));
        await prefs.setString(
            'auth_timestamp', DateTime.now().toIso8601String());
        await prefs.setString('local_metadata', jsonEncode(_metadata));
        await prefs.setString('client_data', jsonEncode(_clientData!.toJson()));

        if (tokenToUse != null) {
          await prefs.setString('fcm_token', tokenToUse);
        }

        print('✅ Авторизация успешна, данные загружены');
      } else {
        throw Exception('Не удалось авторизоваться');
      }
    } catch (e) {
      print('Ошибка входа: $e');
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

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД LOGOUT С ПОЛНОЙ ОЧИСТКОЙ
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
