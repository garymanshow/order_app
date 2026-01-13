// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmployee => _currentUser is Employee;
  bool get isClient => _currentUser is Client;
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('auth_phone');
    if (phone == null) return;

    final name = prefs.getString('auth_name') ?? '';
    final type = prefs.getString('auth_type') ?? 'client';

    if (type == 'client') {
      final discountStr = prefs.getString('auth_discount');
      final discount = discountStr != null ? int.tryParse(discountStr) : null;
      final minOrderAmount = prefs.getDouble('auth_min_order') ?? 0.0;
      _currentUser = Client(
        phone: phone,
        name: name,
        discount: discount,
        minOrderAmount: minOrderAmount,
        transportCost: null,
      );
    } else {
      final role = prefs.getString('auth_role') ?? 'Employee';
      _currentUser = Employee(phone: phone, name: name, role: role);
    }
    notifyListeners();
  }

  Future<void> login(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await AuthService().authenticate(phone);
      if (user == null) {
        _error = 'Пользователь не найден';
      } else {
        _currentUser = user;
        _saveToPrefs(user);
      }
    } catch (e) {
      _error = 'Ошибка авторизации: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Сохраняет сессию клиента
  Future<void> setClientSession(Client client) async {
    _currentUser = client;
    await _saveToPrefs(client);
    notifyListeners();
  }

  /// Вспомогательный метод сохранения в SharedPreferences
  Future<void> _saveToPrefs(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_phone', user.phone);
    await prefs.setString('auth_name', user.name);

    if (user is Client) {
      await prefs.setString('auth_type', 'client');
      await prefs.setString('auth_discount', user.discount?.toString() ?? '');
      await prefs.setDouble('auth_min_order', user.minOrderAmount);
      await prefs.remove('auth_role');
    } else if (user is Employee) {
      await prefs.setString('auth_type', 'employee');
      await prefs.setString('auth_role', user.role);
      await prefs.remove('auth_discount');
      await prefs.remove('auth_min_order');
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
