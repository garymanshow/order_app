// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/client.dart'; // ← добавьте импорт Client
import '../models/employee.dart'; // ← добавьте импорт Employee

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;

  // 🔥 ГЕТТЕРЫ ДЛЯ НАВИГАЦИИ
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmployee => _currentUser is Employee;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('auth_user');
    final timestamp = prefs.getString('auth_timestamp');

    if (userData != null && timestamp != null) {
      try {
        final user = User.fromJson(jsonDecode(userData));
        _currentUser = user;
      } catch (e) {
        print('Ошибка восстановления авторизации: $e');
        await logout();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД LOGIN
  Future<void> login(String phone, {String? fcmToken}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Создаем клиента вместо базового User
      final user = Client(
        phone: phone,
        name: 'Клиент',
        discount: 0.0,
        minOrderAmount: 0.0,
      );
      _currentUser = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user', jsonEncode(user.toJson()));
      await prefs.setString('auth_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('Ошибка входа: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Очищаем только аутентификационные данные
    await prefs.remove('auth_user');
    await prefs.remove('auth_timestamp');

    _currentUser = null;
    notifyListeners();
  }

  // 🔥 МЕТОД ОЧИСТКИ КЭША
  Future<void> clearAllCache() async {
    if (!kDebugMode) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('🧹 Весь кэш приложения очищен');

    _currentUser = null;
    notifyListeners();
  }
}
