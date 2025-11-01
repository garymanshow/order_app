// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  static const _phoneKey = 'auth_phone';
  static const _nameKey = 'auth_name';
  static const _roleKey = 'auth_role';
  static const _discountKey = 'auth_discount';

  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmployee => _currentUser is Employee;
  bool get isClient => _currentUser is Client;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_phoneKey);
    if (phone == null) return;

    final name = prefs.getString(_nameKey) ?? '';
    final role = prefs.getString(_roleKey);
    final discountStr = prefs.getString(_discountKey);

    if (role != null) {
      _currentUser = Employee(phone: phone, name: name, role: role);
    } else if (discountStr != null) {
      final discount = int.tryParse(discountStr);
      _currentUser = Client(phone: phone, name: name, discount: discount);
    } else {
      _currentUser = Client(phone: phone, name: name, discount: null);
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

  Future<void> _saveToPrefs(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, user.phone);
    await prefs.setString(_nameKey, user.name);

    if (user is Employee) {
      await prefs.setString(_roleKey, user.role);
      await prefs.remove(_discountKey);
    } else if (user is Client) {
      await prefs.remove(_roleKey);
      if (user.discount != null) {
        await prefs.setString(_discountKey, user.discount.toString());
      } else {
        await prefs.remove(_discountKey);
      }
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
