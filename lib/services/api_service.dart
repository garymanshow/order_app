// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/order_item.dart';
import '../models/sheet_metadata.dart';
import '../models/status_update.dart';

class ApiService {
  static String get _scriptUrl =>
      dotenv.env['APP_SCRIPT_URL'] ?? 'URL_NOT_FOUND';
  static String get _secret =>
      dotenv.env['APP_SCRIPT_SECRET'] ?? 'SECRET_NOT_FOUND';

  // Улучшенная обработка редиректов с логированием
  Future<http.Response> _postWithRedirect(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    print('\n📤 ===== НАЧАЛО HTTP ЗАПРОСА =====');
    print('📤 URL: $url');
    print('📤 Метод: POST');
    print('📤 Заголовки: $headers');
    print('📤 Тело запроса: $body');

    var request = http.Request('POST', url);
    if (headers != null) request.headers.addAll(headers);
    if (body != null) request.body = body as String;

    request.followRedirects = false;

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    print('\n📥 ПЕРВЫЙ ОТВЕТ:');
    print('📥 Статус: ${response.statusCode}');
    print('📥 Заголовки: ${response.headers}');

    String responseBody = response.body;
    print(
        '📥 Тело (первые 200 символов): ${responseBody.length > 200 ? responseBody.substring(0, 200) : responseBody}');

    if (response.statusCode == 302) {
      final location = response.headers['location'];
      print('\n🔄 ОБНАРУЖЕН РЕДИРЕКТ 302');
      print('🔄 Location: $location');

      if (location != null) {
        print('🔄 Выполняем GET запрос на: $location');
        final redirectResponse =
            await http.get(Uri.parse(location), headers: headers);

        print('\n📥 ФИНАЛЬНЫЙ ОТВЕТ ПОСЛЕ РЕДИРЕКТА:');
        print('📥 Статус: ${redirectResponse.statusCode}');
        print('📥 Заголовки: ${redirectResponse.headers}');

        String redirectBody = redirectResponse.body;
        print(
            '📥 Тело (первые 500 символов): ${redirectBody.length > 500 ? redirectBody.substring(0, 500) : redirectBody}');

        return redirectResponse;
      }
    }

    print('\n📥 ФИНАЛЬНЫЙ ОТВЕТ:');
    print('📥 Статус: ${response.statusCode}');
    print('📥 Тело: ${response.body}');
    print('📥 ===== КОНЕЦ HTTP ЗАПРОСА =====\n');

    return response;
  }

  // 🔧 ТЕСТОВЫЙ МЕТОД ДЛЯ ПРОВЕРКИ СОЕДИНЕНИЯ
  Future<bool> testConnection() async {
    print('\n🔧 ===== ТЕСТИРОВАНИЕ СОЕДИНЕНИЯ =====');
    print('🔧 URL: $_scriptUrl');
    print('🔧 Секрет: $_secret');

    try {
      final Map<String, dynamic> requestBody = {
        'action': 'test',
        'secret': _secret,
      };

      print('🔧 Отправляемый JSON: ${jsonEncode(requestBody)}');

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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

  // 🔥 АУТЕНТИФИКАЦИЯ С ДЕТАЛЬНЫМ ЛОГИРОВАНИЕМ
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
      // Формируем тело запроса
      final Map<String, dynamic> requestBody = {
        'action': 'authenticate',
        'secret': _secret,
        'phone': phone,
        'localMetadata': localMetadata.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

      // Добавляем fcmToken только если он передан
      if (fcmToken != null && fcmToken.isNotEmpty) {
        requestBody['fcmToken'] = fcmToken;
        print('🔐 Добавлен fcmToken в запрос');
      }

      print('\n📦 ОТПРАВЛЯЕМЫЙ JSON:');
      print('📦 ${jsonEncode(requestBody)}');

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
        },
        body: jsonEncode(requestBody),
      );

      print('\n🔍 ОБРАБОТКА ОТВЕТА:');
      print('🔍 Статус код: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          print('🔍 Распарсенный JSON:');
          print('🔍 status: ${data['status']}');
          print('🔍 success: ${data['success']}');
          print('🔍 message: ${data['message']}');
          print(
              '🔍 user: ${data['user'] != null ? 'присутствует' : 'отсутствует'}');
          print(
              '🔍 metadata: ${data['metadata'] != null ? 'присутствует' : 'отсутствует'}');
          print(
              '🔍 data: ${data['data'] != null ? 'присутствует' : 'отсутствует'}');

          // Проверяем успешность аутентификации
          if (data['success'] == true && data['user'] != null) {
            print('✅ Аутентификация успешна!');
            print('🔐 ===== КОНЕЦ АУТЕНТИФИКАЦИИ =====\n');

            return {
              'user': data['user'],
              'data': data['data'] ?? {},
              'metadata': data['metadata'] ?? {},
            };
          } else {
            print('🔍 Распарсенный JSON:');
            print('🔍 status: ${data['status']}');
            print('🔍 success: ${data['success']}');
            print('🔍 message: ${data['message']}');
            print(
                '🔍 user: ${data['user'] != null ? 'присутствует' : 'отсутствует'}');
            print(
                '🔍 metadata: ${data['metadata'] != null ? 'присутствует' : 'отсутствует'}');
            print(
                '🔍 data: ${data['data'] != null ? 'присутствует' : 'отсутствует'}');
            print('⚠️ Аутентификация не удалась: ${data['message']}');
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

  // 🔔 FCM: метод отправки токена
  Future<Map<String, dynamic>> sendFcmToken({
    required String phoneNumber,
    required String fcmToken,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'action': 'saveFcmToken',
        'secret': _secret,
        'phoneNumber': phoneNumber,
        'fcmToken': fcmToken,
        if (role != null) 'role': role,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
      final Map<String, dynamic> requestBody = {
        'action': 'fetchClientData',
        'secret': _secret,
        'phone': phone,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
      final Map<String, dynamic> payload = {
        'action': 'fetchProducts',
        'secret': _secret,
        if (category != null) 'category': category,
        if (clientId != null) 'clientId': clientId,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['products'] as List<dynamic>?;
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
      final Map<String, dynamic> requestBody = {
        'action': 'createOrder',
        'secret': _secret,
        'clientId': clientId,
        'employeeId': employeeId,
        'items': items,
        'totalAmount': totalAmount,
        if (deliveryCity != null) 'deliveryCity': deliveryCity,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
        if (comment != null) 'comment': comment,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
      final Map<String, dynamic> payload = {
        'action': 'fetchOrders',
        'secret': _secret,
        if (clientId != null) 'clientId': clientId,
        if (employeeId != null) 'employeeId': employeeId,
        if (status != null) 'status': status,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['orders'] as List<dynamic>?;
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
      final Map<String, dynamic> requestBody = {
        'action': 'updateOrderStatus',
        'secret': _secret,
        'orderId': orderId,
        'newStatus': newStatus,
        if (comment != null) 'comment': comment,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления статуса заказа: $e');
      return false;
    }
  }

  // 🔥 Обновление статусов по клиентам
  Future<bool> updateOrderStatuses(List<StatusUpdate> updates) async {
    final Map<String, dynamic> requestBody = {
      'action': 'updateOrderStatuses',
      'sheetName': 'Заказы',
      'secret': _secret,
      'updates': updates.map((update) => update.toJson()).toList(),
    };

    try {
      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
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
      final Map<String, dynamic> requestBody = {
        'action': 'fetchMetadata',
        'secret': _secret,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['metadata'] != null) {
          final metadataMap = data['metadata'] as Map<String, dynamic>;
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
      final Map<String, dynamic> requestBody = {
        'action': 'updateMetadata',
        'secret': _secret,
        'sheetName': sheetName,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
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
      final Map<String, dynamic> requestBody = {
        'action': 'sendNotification',
        'secret': _secret,
        'targetPhone': targetPhone,
        'title': title,
        'body': body,
        if (role != null) 'role': role,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
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
      final Map<String, dynamic> requestBody = {
        'action': 'deleteOrder',
        'secret': _secret,
        'orderId': orderId,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
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
      final Map<String, dynamic> requestBody = {
        'action': 'exportData',
        'secret': _secret,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
    final ordersData = orders.map((order) => order.toMap()).toList();

    final Map<String, dynamic> requestBody = {
      'action': 'updateOrders',
      'secret': _secret,
      'orders': ordersData,
    };

    try {
      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('Ошибка обновления заказов: $e');
      return false;
    }
  }

  // 📥 ИМПОРТ ДАННЫХ
  Future<bool> importData(Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> requestBody = {
        'action': 'importData',
        'secret': _secret,
        'data': data,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
      final Map<String, dynamic> requestBody = {
        'action': 'addWarehouseOperation',
        'secret': _secret,
        'phone': phone,
        'operationData': operationData,
      };

      final response = await _postWithRedirect(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка сохранения операции склада: $e');
      return false;
    }
  }
}
