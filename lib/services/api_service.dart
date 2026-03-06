// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/order_item.dart';
import '../models/sheet_metadata.dart';
import '../models/status_update.dart';
import '../models/product.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/delivery_condition.dart';

class ApiService {
  static String get _scriptUrl =>
      dotenv.env['APP_SCRIPT_URL'] ?? 'URL_NOT_FOUND';
  static String get _secret =>
      dotenv.env['APP_SCRIPT_SECRET'] ?? 'SECRET_NOT_FOUND';

  // 🔥 ЕДИНЫЙ МЕТОД ДЛЯ ВСЕХ ЗАПРОСОВ
  Future<http.Response> _makeRequest(
      String action, Map<String, dynamic> data) async {
    final url = Uri.parse(_scriptUrl);

    // Добавляем action и secret к данным
    data['action'] = action;
    data['secret'] = _secret;

    // Всегда отправляем как text/plain для веба
    final headers = {
      'Content-Type': 'text/plain',
    };

    final body = jsonEncode(data);

    print('\n📤 ===== ЗАПРОС К GAS =====');
    print('📤 URL: $url');
    print('📤 Action: $action');
    print('📤 Headers: $headers');
    print('📤 Body: $body');

    try {
      // Для веба используем стандартный post, браузер сам обработает редиректы
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      print('📥 Статус: ${response.statusCode}');
      print('📥 Ответ: ${response.body}');
      print('📥 ===== КОНЕЦ ЗАПРОСА =====\n');

      return response;
    } catch (e) {
      print('❌ Ошибка запроса: $e');
      rethrow;
    }
  }

  // 🔧 ТЕСТОВЫЙ МЕТОД
  Future<bool> testConnection() async {
    print('\n🔧 ===== ТЕСТИРОВАНИЕ СОЕДИНЕНИЯ =====');
    print('🔧 URL: $_scriptUrl');
    print('🔧 Секрет: $_secret');

    try {
      final response = await _makeRequest('test', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('🔧 Ответ: $data');
        print('🔧 ===== ТЕСТ УСПЕШЕН =====\n');
        return data['status'] == 'success';
      } else {
        print('🔧 ===== ТЕСТ НЕ УДАЛСЯ =====\n');
        return false;
      }
    } catch (e) {
      print('🔧 Ошибка: $e');
      print('🔧 ===== ТЕСТ НЕ УДАЛСЯ =====\n');
      return false;
    }
  }

  // 🔥 АУТЕНТИФИКАЦИЯ
  Future<Map<String, dynamic>?> authenticate({
    required String phone,
    required Map<String, SheetMetadata> localMetadata,
    String? fcmToken,
  }) async {
    print('\n🔐 ===== НАЧАЛО АУТЕНТИФИКАЦИИ =====');
    print('🔐 Телефон: $phone');
    print('🔐 Секретный ключ: $_secret');
    print('🔐 URL скрипта: $_scriptUrl');
    print('🔐 FCM токен: ${fcmToken ?? 'не передан'}');
    print('🔐 Локальные метаданные: ${localMetadata.length} листов');

    try {
      final data = {
        'phone': phone,
        'localMetadata': localMetadata.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      };

      final response = await _makeRequest('authenticate', data);

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> result = jsonDecode(response.body);
          print('🔍 Распарсенный JSON:');
          print('🔍 status: ${result['status']}');
          print('🔍 success: ${result['success']}');
          print('🔍 message: ${result['message']}');
          print(
              '🔍 user: ${result['user'] != null ? 'присутствует' : 'отсутствует'}');
          print(
              '🔍 metadata: ${result['metadata'] != null ? 'присутствует' : 'отсутствует'}');
          print(
              '🔍 data: ${result['data'] != null ? 'присутствует' : 'отсутствует'}');

          if (result['success'] == true && result['user'] != null) {
            print('✅ Аутентификация успешна!');
            print('🔐 ===== КОНЕЦ АУТЕНТИФИКАЦИИ =====\n');

            return {
              'user': result['user'],
              'data': result['data'] ?? {},
              'metadata': result['metadata'] ?? {},
            };
          } else {
            print('⚠️ Аутентификация не удалась: ${result['message']}');
            print('🔐 ===== КОНЕЦ АУТЕНТИФИКАЦИИ (ОШИБКА) =====\n');
            return null;
          }
        } catch (e) {
          print('❌ Ошибка парсинга JSON: $e');
          print('❌ Сырой ответ: ${response.body}');
          print('🔐 ===== КОНЕЦ АУТЕНТИФИКАЦИИ (ОШИБКА) =====\n');
          rethrow;
        }
      } else {
        print('❌ HTTP ошибка: ${response.statusCode}');
        print('❌ Тело ответа: ${response.body}');
        print('🔐 ===== КОНЕЦ АУТЕНТИФИКАЦИИ (ОШИБКА) =====\n');
        throw Exception('Ошибка аутентификации: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Критическая ошибка в authenticate: $e');
      print('🔐 ===== КОНЕЦ АУТЕНТИФИКАЦИИ (ИСКЛЮЧЕНИЕ) =====\n');
      rethrow;
    }
  }

  // 🔔 FCM: отправка токена
  Future<Map<String, dynamic>> sendFcmToken({
    required String phoneNumber,
    required String fcmToken,
    String? role,
  }) async {
    try {
      final data = {
        'phoneNumber': phoneNumber,
        'fcmToken': fcmToken,
        if (role != null) 'role': role,
      };

      final response = await _makeRequest('saveFcmToken', data);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Ошибка сохранения FCM токена: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Ошибка отправки FCM токена: $e');
      rethrow;
    }
  }

  // 🔥 ЗАГРУЗКА ДАННЫХ КЛИЕНТА
  Future<Map<String, dynamic>?> fetchClientData(String phone) async {
    try {
      final response = await _makeRequest('fetchClientData', {'phone': phone});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
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
      final data = {
        if (category != null) 'category': category,
        if (clientId != null) 'clientId': clientId,
      };

      final response = await _makeRequest('fetchProducts', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result['products'] as List<dynamic>?;
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
      final data = {
        'clientId': clientId,
        'employeeId': employeeId,
        'items': items,
        'totalAmount': totalAmount,
        if (deliveryCity != null) 'deliveryCity': deliveryCity,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
        if (comment != null) 'comment': comment,
      };

      final response = await _makeRequest('createOrder', data);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
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
      final data = {
        if (clientId != null) 'clientId': clientId,
        if (employeeId != null) 'employeeId': employeeId,
        if (status != null) 'status': status,
      };

      final response = await _makeRequest('fetchOrders', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result['orders'] as List<dynamic>?;
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
      final data = {
        'orderId': orderId,
        'newStatus': newStatus,
        if (comment != null) 'comment': comment,
      };

      final response = await _makeRequest('updateOrderStatus', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления статуса заказа: $e');
      return false;
    }
  }

  // 🔥 Обновление статусов по клиентам
  Future<bool> updateOrderStatuses(List<StatusUpdate> updates) async {
    try {
      final data = {
        'updates': updates.map((update) => update.toJson()).toList(),
      };

      final response = await _makeRequest('updateOrderStatuses', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления статусов заказов: $e');
      return false;
    }
  }

  // 🔥 ЗАГРУЗКА МЕТАДАННЫХ
  Future<Map<String, SheetMetadata>?> fetchMetadata() async {
    try {
      final response = await _makeRequest('fetchMetadata', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['metadata'] != null) {
          final metadataMap = result['metadata'] as Map<String, dynamic>;
          return metadataMap.map((key, value) => MapEntry(
              key, SheetMetadata.fromJson(value as Map<String, dynamic>)));
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки метаданных: $e');
      return null;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ МЕТАДАННЫХ
  Future<bool> updateMetadata(String sheetName) async {
    try {
      final response =
          await _makeRequest('updateMetadata', {'sheetName': sheetName});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления метаданных: $e');
      return false;
    }
  }

  // 🔔 FCM: ОТПРАВКА УВЕДОМЛЕНИЯ
  Future<bool> sendNotification({
    required String targetPhone,
    required String title,
    required String body,
    String? role,
  }) async {
    try {
      final data = {
        'targetPhone': targetPhone,
        'title': title,
        'body': body,
        if (role != null) 'role': role,
      };

      final response = await _makeRequest('sendNotification', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка отправки уведомления: $e');
      return false;
    }
  }

  // 🔥 УДАЛЕНИЕ ЗАКАЗА
  Future<bool> deleteOrder(String orderId) async {
    try {
      final response = await _makeRequest('deleteOrder', {'orderId': orderId});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления заказа: $e');
      return false;
    }
  }

  // 🔥 ЭКСПОРТ ДАННЫХ
  Future<Map<String, dynamic>?> exportData() async {
    try {
      final response = await _makeRequest('exportData', {});

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Ошибка экспорта данных: $e');
      return null;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ ЗАКАЗОВ
  Future<bool> updateOrders(List<OrderItem> orders) async {
    try {
      final ordersData = orders.map((order) => order.toMap()).toList();

      final response =
          await _makeRequest('updateOrders', {'orders': ordersData});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления заказов: $e');
      return false;
    }
  }

  // 📥 ИМПОРТ ДАННЫХ
  Future<bool> importData(Map<String, dynamic> data) async {
    try {
      final response = await _makeRequest('importData', {'data': data});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка импорта данных: $e');
      return false;
    }
  }

  // 🏬 СОХРАНЕНИЕ ОПЕРАЦИЙ СКЛАДА
  Future<bool> addWarehouseOperation({
    required String phone,
    required Map<String, dynamic> operationData,
  }) async {
    try {
      final data = {
        'phone': phone,
        'operationData': operationData,
      };

      final response = await _makeRequest('addWarehouseOperation', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка сохранения операции склада: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: СОЗДАНИЕ ПРОДУКТА
  Future<bool> createProduct(Product product) async {
    try {
      final response =
          await _makeRequest('createProduct', {'product': product.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка создания продукта: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: ОБНОВЛЕНИЕ ПРОДУКТА
  Future<bool> updateProduct(Product product) async {
    try {
      final response =
          await _makeRequest('updateProduct', {'product': product.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления продукта: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: УДАЛЕНИЕ ПРОДУКТА
  Future<bool> deleteProduct(String productId) async {
    try {
      final response =
          await _makeRequest('deleteProduct', {'productId': productId});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления продукта: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: СОЗДАНИЕ КЛИЕНТА
  Future<bool> createClient(Client client) async {
    try {
      final response =
          await _makeRequest('createClient', {'client': client.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка создания клиента: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: ОБНОВЛЕНИЕ КЛИЕНТА
  Future<bool> updateClient(Client client) async {
    try {
      final response =
          await _makeRequest('updateClient', {'client': client.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления клиента: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: УДАЛЕНИЕ КЛИЕНТА
  Future<bool> deleteClient(String clientPhone) async {
    try {
      final response =
          await _makeRequest('deleteClient', {'clientPhone': clientPhone});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления клиента: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: СОЗДАНИЕ СОТРУДНИКА
  Future<bool> createEmployee(Employee employee) async {
    try {
      final response =
          await _makeRequest('createEmployee', {'employee': employee.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка создания сотрудника: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: ОБНОВЛЕНИЕ СОТРУДНИКА
  Future<bool> updateEmployee(Employee employee) async {
    try {
      final response =
          await _makeRequest('updateEmployee', {'employee': employee.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления сотрудника: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: УДАЛЕНИЕ СОТРУДНИКА
  Future<bool> deleteEmployee(String employeePhone) async {
    try {
      final response = await _makeRequest(
          'deleteEmployee', {'employeePhone': employeePhone});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления сотрудника: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: СОЗДАНИЕ УСЛОВИЯ ДОСТАВКИ
  Future<bool> createDeliveryCondition(DeliveryCondition condition) async {
    try {
      final response = await _makeRequest(
          'createDeliveryCondition', {'condition': condition.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка создания условия доставки: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: ОБНОВЛЕНИЕ УСЛОВИЯ ДОСТАВКИ
  Future<bool> updateDeliveryCondition(DeliveryCondition condition) async {
    try {
      final response = await _makeRequest(
          'updateDeliveryCondition', {'condition': condition.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления условия доставки: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: УДАЛЕНИЕ УСЛОВИЯ ДОСТАВКИ
  Future<bool> deleteDeliveryCondition(String location) async {
    try {
      final response =
          await _makeRequest('deleteDeliveryCondition', {'location': location});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления условия доставки: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: МАССОВОЕ ОБНОВЛЕНИЕ ТЕЛЕФОНА В ЗАКАЗАХ
  Future<bool> updateOrdersPhone(String oldPhone, String newPhone) async {
    try {
      final data = {
        'oldPhone': oldPhone,
        'newPhone': newPhone,
      };

      final response = await _makeRequest('updateOrdersPhone', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления телефона в заказах: $e');
      return false;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: МАССОВОЕ ОБНОВЛЕНИЕ СТАТУСОВ ЗАКАЗОВ
  Future<bool> updateOrdersBatch(List<OrderItem> orders) async {
    try {
      final ordersData = orders.map((o) => o.toJson()).toList();

      final response =
          await _makeRequest('updateOrdersBatch', {'orders': ordersData});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка массового обновления заказов: $e');
      return false;
    }
  }
}
