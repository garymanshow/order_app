// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/order_item.dart';
import '../models/sheet_metadata.dart';
import '../models/status_update.dart';
import '../models/warehouse_operation.dart';

class ApiService {
  // 🔔 FCM: URL вашего веб-приложения Apps Script
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbwMFNoa4KdrixvWrx7YnTWslZCM4upPiPRMjzlgUBg2LmaBqFOt8Z7SkERlAvO8GpPQMA/exec';

  // 🔔 FCM: метод отправки токена (если нужно отдельно от логина)
  Future<Map<String, dynamic>> sendFcmToken({
    required String phoneNumber,
    required String fcmToken,
    String? role, // null для клиентов, строка для сотрудников
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'saveFcmToken',
          'phoneNumber': phoneNumber,
          'fcmToken': fcmToken,
          'role': role, // для автоматического определения листа
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        return result;
      } else {
        throw Exception('Ошибка сохранения FCM токена: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Ошибка отправки FCM токена: $e');
      rethrow;
    }
  }

  // 🔥 АУТЕНТИФИКАЦИЯ С ПЕРЕДАЧЕЙ FCM-ТОКЕНА
  Future<Map<String, dynamic>?> authenticate({
    required String phone,
    required Map<String, SheetMetadata> localMetadata,
    String? fcmToken, // 🔔 FCM: новый параметр
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'authenticate',
          'phone': phone,
          'localMetadata': localMetadata.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
          'fcmToken': fcmToken, // 🔔 FCM: передаём токен в аутентификацию
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Проверяем успешность аутентификации
        if (data['success'] == true && data['user'] != null) {
          return {
            'user': data['user'],
            'data': data['data'],
            'metadata': data['metadata'],
          };
        } else {
          print('⚠️ Аутентификация не удалась: ${data['message']}');
          return null;
        }
      } else {
        throw Exception('Ошибка аутентификации: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Ошибка запроса аутентификации: $e');
      rethrow;
    }
  }

  // 🔥 ЗАГРУЗКА ДАННЫХ КЛИЕНТА
  Future<Map<String, dynamic>?> fetchClientData(String phone) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'fetchClientData',
          'phone': phone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки данных клиента: $e');
      return null;
    }
  }

  // 🔥 ЗАГРУЗКА ПРОДУКТОВ
  Future<List<dynamic>?> fetchProducts({
    String? category,
    String? clientId,
  }) async {
    try {
      final payload = {
        'action': 'fetchProducts',
        if (category != null) 'category': category,
        if (clientId != null) 'clientId': clientId,
      };

      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['products'];
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки продуктов: $e');
      return null;
    }
  }

  // 🔥 СОЗДАНИЕ ЗАКАЗА
  Future<Map<String, dynamic>?> createOrder({
    required String clientId,
    required String employeeId,
    required List<dynamic> items,
    required double totalAmount,
    String? deliveryCity,
    String? deliveryAddress,
    String? comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'createOrder',
          'clientId': clientId,
          'employeeId': employeeId,
          'items': items,
          'totalAmount': totalAmount,
          if (deliveryCity != null) 'deliveryCity': deliveryCity,
          if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
          if (comment != null) 'comment': comment,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Ошибка создания заказа: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Ошибка создания заказа: $e');
      rethrow;
    }
  }

  // 🔥 ЗАГРУЗКА ЗАКАЗОВ
  Future<List<dynamic>?> fetchOrders({
    String? clientId,
    String? employeeId,
    String? status,
  }) async {
    try {
      final payload = {
        'action': 'fetchOrders',
        if (clientId != null) 'clientId': clientId,
        if (employeeId != null) 'employeeId': employeeId,
        if (status != null) 'status': status,
      };

      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['orders'];
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки заказов: $e');
      return null;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ СТАТУСА ЗАКАЗА
  Future<bool> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'updateOrderStatus',
          'orderId': orderId,
          'newStatus': newStatus,
          if (comment != null) 'comment': comment,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления статуса заказа: $e');
      return false;
    }
  }

  // 🔥 Обновление статусов по клиентам (для маршрутного листа)
  Future<bool> updateOrderStatuses(List<StatusUpdate> updates) async {
    final requestBody = {
      'action': 'updateOrderStatuses',
      'sheetName': 'Заказы',
      'secret': dotenv.env['APPS_SCRIPT_SECRET'],
      'updates': updates.map((update) => update.toJson()).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl), // Используем ваш существующий _scriptUrl
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('Ошибка обновления статусов заказов: $e');
      return false;
    }
  }

  // 🔥 ЗАГРУЗКА МЕТАДАННЫХ
  Future<Map<String, SheetMetadata>?> fetchMetadata() async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'fetchMetadata'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['metadata'] != null) {
          final metadataMap = data['metadata'] as Map<String, dynamic>;
          return metadataMap.map(
              (key, value) => MapEntry(key, SheetMetadata.fromJson(value)));
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки метаданных: $e');
      return null;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ МЕТАДАННЫХ (после изменений в таблице)
  Future<bool> updateMetadata(String sheetName) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'updateMetadata',
          'sheetName': sheetName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления метаданных: $e');
      return false;
    }
  }

  // 🔔 FCM: МЕТОД ОТПРАВКИ УВЕДОМЛЕНИЯ ЧЕРЕЗ СЕРВЕР (опционально)
  // Если вы хотите отправлять уведомления напрямую из приложения (не через my-push-server)
  Future<bool> sendNotification({
    required String targetPhone,
    required String title,
    required String body,
    String? role, // null для клиентов, 'admin'/'manager' для сотрудников
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'sendNotification',
          'targetPhone': targetPhone,
          'title': title,
          'body': body,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка отправки уведомления: $e');
      return false;
    }
  }

  // 🔥 УДАЛЕНИЕ ЗАКАЗА (для администратора)
  Future<bool> deleteOrder(String orderId) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'deleteOrder',
          'orderId': orderId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления заказа: $e');
      return false;
    }
  }

  // 🔥 ЭКСПОРТ/ИМПОРТ ДАННЫХ
  Future<Map<String, dynamic>?> exportData() async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'exportData'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Ошибка экспорта данных: $e');
      return null;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: обновление заказов
  Future<bool> updateOrders(List<OrderItem> orders) async {
    final url =
        Uri.parse('${dotenv.env['APPS_SCRIPT_URL']}?action=updateOrders');

    // Используем toMap() для совместимости с Google Таблицами
    final ordersData = orders.map((order) => order.toMap()).toList();

    final requestBody = {
      'orders': ordersData,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('Ошибка обновления заказов: $e');
      return false;
    }
  }

  Future<bool> importData(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'importData',
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка импорта данных: $e');
      return false;
    }
  }

  // Сохранение операций склада
  Future<bool> addWarehouseOperation(WarehouseOperation operation) async {
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['APPS_SCRIPT_URL']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'addWarehouseOperation',
          'operation': operation.toMap(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка сохранения операции склада: $e');
      return false;
    }
  }
}
