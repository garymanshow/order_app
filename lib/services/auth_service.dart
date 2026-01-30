// lib/services/auth_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Models
import '../models/client.dart';
import '../models/employee.dart';
import '../models/user.dart';
import '../models/sheet_metadata.dart';
import '../models/product.dart';
import '../models/order_item.dart';

class AuthService {
  /// Нормализует телефон: добавляет '+' если отсутствует
  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    return trimmed.startsWith('+') ? trimmed : '+$trimmed';
  }

  Future<AuthResponse?> authenticate(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

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

      // 🔥 СОСТАВНОЙ ЗАПРОС К APPS SCRIPT
      final response = await _makeCompositeRequest(
        phone: normalizedPhone,
        localMetadata: localMetadata, // ← ИСПРАВЛЕНО: правильное имя параметра
      );

      if (response == null) return null;

      // Сохраняем обновленные метаданные
      await prefs.setString('local_metadata', jsonEncode(response.metadata));

      return AuthResponse(
        user: response.user,
        metadata: response.metadata,
        clientData: response.clientData,
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Ошибка авторизации: $e');
      return null;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: Составной запрос к Apps Script
  Future<AuthResponse?> _makeCompositeRequest({
    required String phone,
    required Map<String, SheetMetadata> localMetadata,
  }) async {
    final url =
        Uri.parse('${dotenv.env['APPS_SCRIPT_URL']}?action=authenticate');

    final requestBody = {
      'phone': phone,
      'localMetadata': localMetadata
          .map((key, value) => MapEntry(key, value.toJson()))
          .cast<String, dynamic>(), // ← ДОБАВЛЕНО: приведение типов
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] != true) {
          return null;
        }

        // Десериализация пользователя
        final userData = data['user'];
        User user;
        if (userData['role'] != null) {
          user = Employee.fromJson(userData);
        } else {
          user = Client.fromJson(userData);
        }

        // Десериализация метаданных
        final metadataData = data['metadata'] as Map<String, dynamic>;
        final metadata = metadataData.map((key, value) => MapEntry(
            key, SheetMetadata.fromJson(value as Map<String, dynamic>)));

        // Десериализация данных клиента
        final clientDataObj = _deserializeClientData(data['clientData']);

        return AuthResponse(
          user: user,
          metadata: metadata, // ← ИСПРАВЛЕНО: правильное имя параметра
          clientData: clientDataObj,
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return null;
    } catch (e) {
      print('Ошибка составного запроса: $e');
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
