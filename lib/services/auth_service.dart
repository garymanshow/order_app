// lib/services/auth_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Models
import '../models/client.dart';
import '../models/employee.dart';
import '../models/user.dart';
import '../models/sheet_metadata.dart';
import '../models/product.dart';
import '../models/order_item.dart';

// Services
import '../services/api_service.dart';

// Utils
import '../utils/phone_validator.dart';

class AuthService {
  static String get _secret =>
      dotenv.env['APP_SCRIPT_SECRET'] ?? 'SECRET_NOT_FOUND';

  Future<AuthResponse?> authenticate(String phone) async {
    // 🔥 Используем утилиту PhoneValidator для нормализации
    final normalizedPhone = PhoneValidator.normalizePhone(phone);

    if (normalizedPhone == null) {
      print('❌ Неверный формат телефона: $phone');
      return null;
    }

    // 🔥 Дополнительная валидация для авторизации
    if (!PhoneValidator.isValidAuthPhone(normalizedPhone)) {
      print('❌ Телефон не прошел валидацию для авторизации: $normalizedPhone');
      return null;
    }

    try {
      // 🔥 ПОЛУЧАЕМ ЛОКАЛЬНЫЕ МЕТАДАННЫЕ
      final prefs = await SharedPreferences.getInstance();
      final localMetadataJson = prefs.getString('local_metadata');
      Map<String, SheetMetadata> localMetadata = {};

      if (localMetadataJson != null) {
        final metadataMap =
            jsonDecode(localMetadataJson) as Map<String, dynamic>;
        localMetadata = metadataMap.map((key, value) => MapEntry(
            key, SheetMetadata.fromJson(value as Map<String, dynamic>)));
      }

      // 🔥 ИСПОЛЬЗУЕМ ApiService вместо собственного HTTP-запроса
      final apiService = ApiService();
      final authResponse = await apiService.authenticate(
        phone: normalizedPhone,
        localMetadata: localMetadata, // ← ИСПРАВЛЕНО: правильное имя параметра
        fcmToken: null, // FCM обрабатывается в AuthProvider
      );

      if (authResponse == null) return null;

      // Сохраняем обновленные метаданные
      await prefs.setString(
          'local_metadata', jsonEncode(authResponse['metadata']));

      // Десериализация пользователя
      final userData = authResponse['user'];
      User user;
      if (userData['role'] != null) {
        user = Employee.fromJson(userData);
      } else {
        user = Client.fromJson(userData);
      }

      // Десериализация данных клиента
      final clientDataObj = _deserializeClientData(authResponse['data']);

      final result = AuthResponse(
        user: user,
        metadata: authResponse['metadata'] as Map<String,
            SheetMetadata>, // ← ИСПРАВЛЕНО: правильное имя параметра
        clientData: clientDataObj,
        timestamp: DateTime.now().toIso8601String(),
      );

      return result;
    } catch (e) {
      print('Ошибка авторизации: $e');
      return null;
    }
  }

  // 🔥 ДЕСЕРИАЛИЗАЦИЯ ДАННЫХ КЛИЕНТА
  ClientData _deserializeClientData(dynamic data) {
    if (data == null) return ClientData();

    final clientData = ClientData();
    final clientDataMap = data as Map<String, dynamic>;

    if (clientDataMap['products'] != null) {
      clientData.products = (clientDataMap['products'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['orders'] != null) {
      clientData.orders = (clientDataMap['orders'] as List)
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['cart'] != null) {
      clientData.cart = clientDataMap['cart'] as Map<String, dynamic>;
    }

    return clientData;
  }
}

class ClientData {
  List<Product> products = [];
  List<OrderItem> orders = [];
  Map<String, dynamic> cart = {};

  ClientData();
}

class AuthResponse {
  final User user;
  final Map<String, SheetMetadata> metadata;
  final ClientData? clientData;
  final String timestamp;

  AuthResponse({
    required this.user,
    required this.metadata,
    this.clientData,
    required this.timestamp,
  });
}
