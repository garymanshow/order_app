// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<Employee>? _availableRoles; // ← НОВОЕ ПОЛЕ ДЛЯ МНОЖЕСТВЕННЫХ РОЛЕЙ
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  ClientData? get clientData => _clientData;
  Map<String, SheetMetadata>? get metadata => _metadata;
  List<Employee>? get availableRoles => _availableRoles; // ← ГЕТТЕР

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmployee => _currentUser is Employee;
  bool get isClient => _currentUser is Client;
  bool get hasMultipleRoles =>
      _availableRoles != null && _availableRoles!.length > 1; // ← ГЕТТЕР

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('auth_user');
    final timestamp = prefs.getString('auth_timestamp');

    if (userData != null && timestamp != null) {
      try {
        final json = jsonDecode(userData);

        if (json['role'] == null) {
          _currentUser = Client.fromJson(json);
        } else {
          _currentUser = Employee.fromJson(json);
        }
      } catch (e) {
        print('Ошибка восстановления авторизации: $e');
        await logout();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // 🔥 ОБНОВЛЕННЫЙ МЕТОД LOGIN С ПОДДЕРЖКОЙ FCM-ТОКЕНА И МНОЖЕСТВЕННЫХ РОЛЕЙ
  Future<void> login(String phone, {String? fcmToken}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Загружаем локальные метаданные
      final prefs = await SharedPreferences.getInstance();
      final localMetaJson = prefs.getString('local_metadata');
      Map<String, SheetMetadata> localMetadata = {};

      if (localMetaJson != null) {
        final metaMap = jsonDecode(localMetaJson) as Map<String, dynamic>;
        localMetadata = metaMap.map((key, value) => MapEntry(
            key, SheetMetadata.fromJson(value as Map<String, dynamic>)));
      }

      // Вызываем API для аутентификации и получения данных
      final apiService = ApiService();
      final authResponse = await apiService.authenticate(
        phone: phone,
        localMetadata: localMetadata,
        fcmToken: fcmToken, // ← ПЕРЕДАЁМ ТОКЕН
      );

      if (authResponse != null) {
        final userData = authResponse['user'];

        // 🔥 ПРОВЕРКА: массив сотрудников или один пользователь
        if (userData is List) {
          // Несколько ролей - сохраняем список
          _availableRoles = (userData as List)
              .map((item) => Employee.fromJson(item as Map<String, dynamic>))
              .toList();
          _currentUser = null; // Пока не выбрана конкретная роль
        } else {
          // Один пользователь
          if (userData['role'] != null) {
            _currentUser = Employee.fromJson(userData);
            _availableRoles = null; // Сбрасываем список ролей
          } else {
            _currentUser = Client.fromJson(userData);
            _availableRoles = null; // Сбрасываем список ролей
          }
        }

        _clientData = authResponse['data'];
        _metadata = authResponse['metadata'];

        // Сохраняем данные в кэш
        await prefs.setString(
            'auth_user', jsonEncode(_currentUser?.toJson() ?? {}));
        await prefs.setString(
            'auth_timestamp', DateTime.now().toIso8601String());
        await prefs.setString('local_metadata', jsonEncode(_metadata));
        await prefs.setString('client_data', jsonEncode(_clientData!.toJson()));

        // 🔥 СОХРАНЯЕМ FCM-ТОКЕН В КЭШ
        if (fcmToken != null) {
          await prefs.setString('fcm_token', fcmToken);
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

  // 🔥 НОВЫЙ МЕТОД ДЛЯ ВЫБОРА РОЛИ
  void selectRole(Employee selectedRole) {
    _currentUser = selectedRole;
    _availableRoles = null;
    notifyListeners();
  }

  // 🔥 НОВЫЙ МЕТОД ДЛЯ ОБНОВЛЕНИЯ КЛИЕНТА
  void setClient(Client client) {
    _currentUser = client;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Очищаем все связанные данные
    await prefs.remove('auth_user');
    await prefs.remove('auth_timestamp');
    await prefs.remove('local_metadata');
    await prefs.remove('client_data');
    await prefs.remove('fcm_token'); // ← ОЧИЩАЕМ ТОКЕН

    _currentUser = null;
    _clientData = null;
    _metadata = null;
    _availableRoles = null; // ← ОЧИЩАЕМ РОЛИ
    notifyListeners();
  }

  Future<void> clearAllCache() async {
    if (!kDebugMode) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('🧹 Весь кэш приложения очищен');

    _currentUser = null;
    _clientData = null;
    _metadata = null;
    _availableRoles = null; // ← ОЧИЩАЕМ РОЛИ
    notifyListeners();
  }
}
