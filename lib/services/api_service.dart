// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_item.dart';
import '../models/sheet_metadata.dart';
import '../models/status_update.dart';
import '../models/price_category.dart';
import '../models/product.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/delivery_condition.dart';
import '../models/warehouse_operation.dart';
import 'env_service.dart';

class ApiService {
  // 🔥 ИСПОЛЬЗУЕМ EnvService для URL (секрет больше не нужен!)
  static String get _scriptUrl => EnvService.scriptUrl;

  // 👇 secret больше не используется, но оставим для обратной совместимости
  // В будущем можно полностью удалить

  // 🔥 ЕДИНЫЙ МЕТОД ДЛЯ ВСЕХ ЗАПРОСОВ
  Future<http.Response> _makeRequest(
      String action, Map<String, dynamic> data) async {
    final url = Uri.parse(_scriptUrl);

    // Добавляем action к данным (secret больше не отправляем!)
    data['action'] = action;

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

    try {
      final response = await _makeRequest('test', {});

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
          print('❌ Получен HTML вместо JSON!');
          return false;
        }

        final Map<String, dynamic> data = jsonDecode(response.body);
        print('🔧 Ответ: $data');
        print('🔧 ===== ТЕСТ УСПЕШЕН =====\n');
        return data['status'] == 'success' || data['success'] == true;
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

  // 🔥 АУТЕНТИФИКАЦИЯ (без FCM)
  Future<Map<String, dynamic>?> authenticate({
    required String phone,
    required Map<String, SheetMetadata> localMetadata,
  }) async {
    print('\n🔐 ===== НАЧАЛО АУТЕНТИФИКАЦИИ =====');
    print('🔐 Телефон: $phone');
    print('🔐 URL скрипта: $_scriptUrl');
    print('🔐 Локальные метаданные: ${localMetadata.length} листов');

    try {
      final data = {
        'phone': phone,
        'localMetadata': localMetadata.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
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

  // Получает push-подписки для указанных телефонов (Web Push)
  Future<List<Map<String, dynamic>>> getPushSubscriptions({
    required String requesterPhone,
    required List<String> targetPhones,
  }) async {
    try {
      final response = await _makeRequest('getPushSubscriptions', {
        'requesterPhone': requesterPhone,
        'targetPhones': targetPhones,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['status'] == 'success' && result['subscriptions'] != null) {
          return List<Map<String, dynamic>>.from(result['subscriptions']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Ошибка получения подписок: $e');
      return [];
    }
  }

  Future<bool> sendNotification({
    required String targetPhone,
    required String title,
    required String body,
    String? role,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _makeRequest('sendNotification', {
        'targetPhone': targetPhone,
        'title': title,
        'body': body,
        if (role != null) 'role': role,
        if (data != null) 'data': data,
      });

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка отправки уведомления: $e');
      return false;
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

  /// Создание заказа
  /// Возвращает true при успешном создании, false при ошибке
  Future<bool> createOrder({
    required String clientId,
    required String employeeId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? deliveryCity,
    String? deliveryAddress,
    String? comment,
  }) async {
    try {
      // 🔥 ИСПРАВЛЕНО: Оборачиваем данные заказа в объект 'data'
      // и переименовываем clientId в phone для совместимости с GAS

      final orderData = {
        'items': items,
        'totalAmount': totalAmount,
        if (deliveryCity != null) 'deliveryCity': deliveryCity,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
        if (comment != null) 'comment': comment,
        // Добавляем employeeId внутрь data, если это нужно серверу
        'employeeId': employeeId,
      };

      final payload = {
        'phone': clientId, // GAS ожидает поле 'phone'
        'data': orderData, // GAS ожидает поле 'data'
      };

      final response = await _makeRequest('createOrder', payload);

      if (response.statusCode == 200) {
        // Защита от пустого ответа
        if (response.body.isEmpty) {
          print('❌ Ошибка: сервер вернул пустой ответ');
          return false;
        }

        final Map<String, dynamic> result = jsonDecode(response.body);

        // Проверяем success или status
        return result['success'] == true || result['status'] == 'success';
      } else {
        print('❌ Ошибка создания заказа: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Ошибка создания заказа: $e');
      return false;
    }
  }

  /// Альтернативный метод, возвращающий полный ответ (для отладки)
  Future<Map<String, dynamic>?> createOrderWithDetails({
    required String clientId,
    required String employeeId,
    required List<Map<String, dynamic>> items,
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
        print('❌ Ошибка создания заказа: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Ошибка создания заказа: $e');
      return null;
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

  // ==================== МЕТОДЫ ДЛЯ СОСТАВОВ ====================

  // Получить состав для продукта
  Future<List<Map<String, dynamic>>?> getCompositionForProduct(
      int productId) async {
    try {
      final response = await _makeRequest('getCompositionForProduct', {
        'productId': productId,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['composition'] != null) {
          return List<Map<String, dynamic>>.from(result['composition']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения состава продукта: $e');
      return null;
    }
  }

  // Получить состав для начинки
  Future<List<Map<String, dynamic>>?> getCompositionForFilling(
      int fillingId) async {
    try {
      final response = await _makeRequest('getCompositionForFilling', {
        'fillingId': fillingId,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['composition'] != null) {
          return List<Map<String, dynamic>>.from(result['composition']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения состава начинки: $e');
      return null;
    }
  }

  // Получить начинку по ID
  Future<Map<String, dynamic>?> getFilling(int fillingId) async {
    try {
      final response = await _makeRequest('getFilling', {
        'fillingId': fillingId,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['filling'] != null) {
          return result['filling'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения начинки: $e');
      return null;
    }
  }

  // Получить начинку по названию
  Future<Map<String, dynamic>?> getFillingByName(String name) async {
    try {
      final response = await _makeRequest('getFillingByName', {
        'name': name,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['filling'] != null) {
          return result['filling'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения начинки по названию: $e');
      return null;
    }
  }

  // ==================== СКЛАД (CRUD) ====================

  // 🔥 ПОЛУЧЕНИЕ ВСЕХ ОПЕРАЦИЙ СКЛАДА
  Future<Map<String, dynamic>?> fetchWarehouseOperations() async {
    try {
      final response = await _makeRequest('fetchWarehouseOperations', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result;
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки операций склада: $e');
      return null;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ОПЕРАЦИЙ СКЛАДА С ФИЛЬТРАМИ
  Future<Map<String, dynamic>?> fetchWarehouseOperationsFiltered(
      Map<String, dynamic> filters) async {
    try {
      final data = {
        'filters': filters,
      };

      final response =
          await _makeRequest('fetchWarehouseOperationsFiltered', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result;
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки отфильтрованных операций: $e');
      return null;
    }
  }

  // 🔥 ДОБАВЛЕНИЕ ОПЕРАЦИИ СКЛАДА
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
      print('❌ Ошибка добавления операции склада: $e');
      return false;
    }
  }

  // 🔥 ДОБАВЛЕНИЕ НЕСКОЛЬКИХ ОПЕРАЦИЙ
  Future<bool> addWarehouseOperations(
      List<Map<String, dynamic>> operations) async {
    try {
      final data = {
        'operations': operations,
      };

      final response = await _makeRequest('addWarehouseOperations', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка добавления операций: $e');
      return false;
    }
  }

  /// Удаление складской операции
  Future<bool> deleteWarehouseOperation(String operationId) async {
    try {
      final response = await _makeRequest('deleteWarehouseOperation', {
        'id': operationId,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления складской операции: $e');
      return false;
    }
  }

  /// Обновление складской операции
  Future<bool> updateWarehouseOperation(WarehouseOperation operation) async {
    try {
      final response = await _makeRequest('updateWarehouseOperation', {
        'operation': operation.toMap(),
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления складской операции: $e');
      return false;
    }
  }

  /// Получение одной складской операции по ID
  Future<WarehouseOperation?> getWarehouseOperation(String operationId) async {
    try {
      final response = await _makeRequest('getWarehouseOperation', {
        'id': operationId,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['operation'] != null) {
          return WarehouseOperation.fromJson(result['operation']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения складской операции: $e');
      return null;
    }
  }

  // ==================== РАБОТА С НАЧИНКАМИ (CRUD) ====================

  // 🔥 СОЗДАНИЕ НАЧИНКИ
  Future<bool> createFilling(Map<String, dynamic> fillingData) async {
    try {
      final response = await _makeRequest('createFilling', fillingData);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка создания начинки: $e');
      return false;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ НАЧИНКИ
  Future<bool> updateFilling(Map<String, dynamic> fillingData) async {
    try {
      final response = await _makeRequest('updateFilling', fillingData);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления начинки: $e');
      return false;
    }
  }

  // 🔥 УДАЛЕНИЕ НАЧИНКИ
  Future<bool> deleteFilling(String fillingId) async {
    try {
      final response =
          await _makeRequest('deleteFilling', {'fillingId': fillingId});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления начинки: $e');
      return false;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ НАЧИНОК
  Future<List<Map<String, dynamic>>?> fetchFillings() async {
    try {
      final response = await _makeRequest('fetchFillings', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['fillings'] != null) {
          return List<Map<String, dynamic>>.from(result['fillings']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки начинок: $e');
      return null;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ОСТАТКОВ ПРОИЗВОДСТВА
  Future<Map<String, dynamic>?> getProductionBalances() async {
    try {
      final response = await _makeRequest('getProductionBalances', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result;
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения остатков производства: $e');
      return null;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ПРЕДУПРЕЖДЕНИЙ ПРОИЗВОДСТВА
  Future<List<String>?> getProductionAlerts() async {
    try {
      final response = await _makeRequest('getProductionAlerts', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['alerts'] != null) {
          return List<String>.from(result['alerts']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения предупреждений: $e');
      return null;
    }
  }

  // ==================== РАБОТА С СОСТАВОМ (CRUD) ====================

  // 🔥 ПОЛУЧЕНИЕ СОСТАВА ПО ИСТОЧНИКУ
  Future<List<Map<String, dynamic>>?> getCompositionForSource(
    String sourceSheet,
    String sourceId,
  ) async {
    try {
      final response = await _makeRequest('getCompositionForSource', {
        'sourceSheet': sourceSheet,
        'sourceId': sourceId,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['composition'] != null) {
          return List<Map<String, dynamic>>.from(result['composition']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения состава: $e');
      return null;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ВСЕХ ИНГРЕДИЕНТОВ
  Future<List<String>?> getAllIngredients() async {
    try {
      final response = await _makeRequest('getAllIngredients', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['ingredients'] != null) {
          return List<String>.from(result['ingredients']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения ингредиентов: $e');
      return null;
    }
  }

  // 🔥 ДОБАВЛЕНИЕ ЭЛЕМЕНТА СОСТАВА
  Future<bool> addCompositionItem(Map<String, dynamic> itemData) async {
    try {
      final response = await _makeRequest('addCompositionItem', itemData);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка добавления элемента состава: $e');
      return false;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ ЭЛЕМЕНТА СОСТАВА
  Future<bool> updateCompositionItem(Map<String, dynamic> itemData) async {
    try {
      final response = await _makeRequest('updateCompositionItem', itemData);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления элемента состава: $e');
      return false;
    }
  }

  // 🔥 УДАЛЕНИЕ ЭЛЕМЕНТА СОСТАВА
  Future<bool> deleteCompositionItem(String itemId) async {
    try {
      final response =
          await _makeRequest('deleteCompositionItem', {'id': itemId});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления элемента состава: $e');
      return false;
    }
  }

  // ==================== ЕДИНИЦЫ ИЗМЕРЕНИЯ ====================

  // 🔥 ПОЛУЧЕНИЕ ВСЕХ ЕДИНИЦ ИЗМЕРЕНИЯ
  Future<Map<String, dynamic>?> fetchUnitsOfMeasure() async {
    try {
      final response = await _makeRequest('fetchUnitsOfMeasure', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result;
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки единиц измерения: $e');
      return null;
    }
  }

  // 🔥 ДОБАВЛЕНИЕ НОВОЙ ЕДИНИЦЫ ИЗМЕРЕНИЯ
  Future<bool> addUnitOfMeasure(Map<String, dynamic> unitData) async {
    try {
      final response = await _makeRequest('addUnitOfMeasure', unitData);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка добавления единицы измерения: $e');
      return false;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ ЕДИНИЦЫ ИЗМЕРЕНИЯ
  Future<bool> updateUnitOfMeasure(
      String code, Map<String, dynamic> unitData) async {
    try {
      final data = {
        'code': code,
        ...unitData,
      };

      final response = await _makeRequest('updateUnitOfMeasure', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления единицы измерения: $e');
      return false;
    }
  }

  // 🔥 УДАЛЕНИЕ ЕДИНИЦЫ ИЗМЕРЕНИЯ
  Future<bool> deleteUnitOfMeasure(String code) async {
    try {
      final response =
          await _makeRequest('deleteUnitOfMeasure', {'code': code});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления единицы измерения: $e');
      return false;
    }
  }

  // ==================== ПРОИЗВОДСТВО (CRUD) ====================

  // 🔥 ПОЛУЧЕНИЕ ВСЕХ ПРОИЗВОДСТВЕННЫХ ОПЕРАЦИЙ
  Future<List<Map<String, dynamic>>?> fetchProductionOperations() async {
    try {
      final response = await _makeRequest('fetchProductionOperations', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['operations'] != null) {
          return List<Map<String, dynamic>>.from(result['operations']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки производственных операций: $e');
      return null;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ОПЕРАЦИЙ ПО ФИЛЬТРАМ
  Future<List<Map<String, dynamic>>?> fetchProductionOperationsFiltered({
    String? sheet, // "Начинки" или "Прайс-лист"
    int? entityId, // ID сущности
    DateTime? fromDate, // С даты
    DateTime? toDate, // По дату
  }) async {
    try {
      final data = {
        if (sheet != null) 'sheet': sheet,
        if (entityId != null) 'entityId': entityId,
        if (fromDate != null) 'fromDate': _formatDate(fromDate),
        if (toDate != null) 'toDate': _formatDate(toDate),
      };

      final response =
          await _makeRequest('fetchProductionOperationsFiltered', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['operations'] != null) {
          return List<Map<String, dynamic>>.from(result['operations']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки отфильтрованных операций: $e');
      return null;
    }
  }

  // 🔥 СОЗДАНИЕ ПРОИЗВОДСТВЕННОЙ ОПЕРАЦИИ
  Future<bool> createProductionOperation({
    required String sheet, // "Начинки" или "Прайс-лист"
    required int entityId, // ID начинки или продукта
    required String name, // Наименование
    required double quantity, // Количество
    String? unit, // Единица измерения (если есть)
    required DateTime date, // Дата производства
  }) async {
    try {
      final data = {
        'sheet': sheet,
        'entityId': entityId,
        'name': name,
        'quantity': quantity,
        'date': _formatDate(date),
        if (unit != null && unit.isNotEmpty) 'unit': unit,
      };

      print('📝 Создание производственной операции: $data');

      final response = await _makeRequest('createProductionOperation', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка создания производственной операции: $e');
      return false;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ ПРОИЗВОДСТВЕННОЙ ОПЕРАЦИИ
  Future<bool> updateProductionOperation({
    required int rowId, // ID строки в таблице
    String? sheet,
    int? entityId,
    String? name,
    double? quantity,
    String? unit,
    DateTime? date,
  }) async {
    try {
      final data = {
        'rowId': rowId,
        if (sheet != null) 'sheet': sheet,
        if (entityId != null) 'entityId': entityId,
        if (name != null) 'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
        if (date != null) 'date': _formatDate(date),
      };

      final response = await _makeRequest('updateProductionOperation', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления производственной операции: $e');
      return false;
    }
  }

  // 🔥 УДАЛЕНИЕ ПРОИЗВОДСТВЕННОЙ ОПЕРАЦИИ
  Future<bool> deleteProductionOperation(int rowId) async {
    try {
      final response =
          await _makeRequest('deleteProductionOperation', {'rowId': rowId});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления производственной операции: $e');
      return false;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ПРОИЗВОДСТВЕННОЙ СТАТИСТИКИ
  Future<Map<String, dynamic>?> getProductionStats({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final data = {
        if (fromDate != null) 'fromDate': _formatDate(fromDate),
        if (toDate != null) 'toDate': _formatDate(toDate),
      };

      final response = await _makeRequest('getProductionStats', data);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result;
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения статистики производства: $e');
      return null;
    }
  }

  // 🔥 МАССОВОЕ СОЗДАНИЕ ПРОИЗВОДСТВЕННЫХ ОПЕРАЦИЙ
  Future<bool> createProductionOperationsBatch(
      List<Map<String, dynamic>> operations) async {
    try {
      final response = await _makeRequest(
          'createProductionOperationsBatch', {'operations': operations});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка массового создания операций: $e');
      return false;
    }
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  // Форматирование даты для отправки в GAS
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  // 🔥 СОЗДАНИЕ КАТЕГОРИИ ТОВАРА
  Future<bool> createPriceCategory(PriceCategory category) async {
    try {
      final response = await _makeRequest(
          'createPriceCategory', {'category': category.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка создания категории товара: $e');
      return false;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ КАТЕГОРИИ ТОВАРА
  Future<bool> updatePriceCategory(PriceCategory category) async {
    try {
      final response = await _makeRequest(
          'updatePriceCategory', {'category': category.toJson()});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления категории товара: $e');
      return false;
    }
  }

  // 🔥 УДАЛЕНИЕ КАТЕГОРИИ ТОВАРА
  Future<bool> deletePriceCategory(String categoryId) async {
    try {
      final response =
          await _makeRequest('deletePriceCategory', {'categoryId': categoryId});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления категории товара: $e');
      return false;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ВСЕХ КАТЕГОРИЙ ТОВАРОВ
  Future<List<PriceCategory>?> fetchPriceCategories() async {
    try {
      final response = await _makeRequest('fetchPriceCategories', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['categories'] != null) {
          final categoriesList = result['categories'] as List;
          return categoriesList
              .map((item) =>
                  PriceCategory.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки категорий товаров: $e');
      return null;
    }
  }

  // 🔥 СОЗДАНИЕ ПРОДУКТА
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

  // 🔥 ОБНОВЛЕНИЕ ПРОДУКТА
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

  // 🔥 УДАЛЕНИЕ ПРОДУКТА
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

  // 🔥 СОЗДАНИЕ КЛИЕНТА
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

  // 🔥 ОБНОВЛЕНИЕ КЛИЕНТА
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

  // 🔥 УДАЛЕНИЕ КЛИЕНТА
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

  // 🔥 СОЗДАНИЕ СОТРУДНИКА
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

  // 🔥 ОБНОВЛЕНИЕ СОТРУДНИКА
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

  // 🔥 УДАЛЕНИЕ СОТРУДНИКА
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

  // 🔥 СОЗДАНИЕ УСЛОВИЯ ДОСТАВКИ
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

  // 🔥 ОБНОВЛЕНИЕ УСЛОВИЯ ДОСТАВКИ
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

  // 🔥 УДАЛЕНИЕ УСЛОВИЯ ДОСТАВКИ
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

  // 🔥 МАССОВОЕ ОБНОВЛЕНИЕ ТЕЛЕФОНА В ЗАКАЗАХ
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

  // 🔥 МАССОВОЕ ОБНОВЛЕНИЕ СТАТУСОВ ЗАКАЗОВ
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

  // ==================== PUSH-УВЕДОМЛЕНИЯ ====================

  // 🔥 СОХРАНЕНИЕ PUSH-ПОДПИСКИ
  Future<bool> savePushSubscription({
    required String phone,
    required String role,
    required Map<String, dynamic> subscription,
  }) async {
    try {
      final response = await _makeRequest('savePushSubscription', {
        'phone': phone,
        'role': role,
        'subscription': subscription,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка сохранения подписки: $e');
      return false;
    }
  }

  // 🔥 УДАЛЕНИЕ PUSH-ПОДПИСКИ
  Future<bool> deletePushSubscription(String phone) async {
    try {
      final response = await _makeRequest('deletePushSubscription', {
        'phone': phone,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления подписки: $e');
      return false;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ПОДПИСОК ВОДИТЕЛЕЙ
  Future<List<Map<String, dynamic>>> getDriverSubscriptions() async {
    try {
      final response = await _makeRequest('getDriverSubscriptions', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['subscriptions'] != null) {
          return List<Map<String, dynamic>>.from(result['subscriptions']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Ошибка получения подписок: $e');
      return [];
    }
  }

  // 🔥 Массовая отправка уведомлений
  Future<Map<String, int>> sendBulkNotifications({
    required List<String> targetPhones,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _makeRequest('sendBulkNotifications', {
        'targetPhones': targetPhones,
        'title': title,
        'body': body,
        'data': data,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return {
            'sent': result['sent'] ?? 0,
            'failed': result['failed'] ?? 0,
          };
        }
      }
      return {'sent': 0, 'failed': targetPhones.length};
    } catch (e) {
      print('❌ Ошибка массовой отправки: $e');
      return {'sent': 0, 'failed': targetPhones.length};
    }
  }

  // 🔥 Отправка уведомления клиенту (с записью в историю)
  Future<bool> sendClientNotification({
    required String clientPhone,
    required String title,
    required String body,
    required String orderId,
  }) async {
    try {
      final response = await _makeRequest('sendClientNotification', {
        'clientPhone': clientPhone,
        'title': title,
        'body': body,
        'orderId': orderId,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка отправки клиенту: $e');
      return false;
    }
  }

  // Отправка обратной связи
  Future<bool> sendFeedback({
    required String name,
    required String email,
    required String phone,
    required String message,
  }) async {
    try {
      final response = await _makeRequest('sendFeedback', {
        'name': name,
        'email': email,
        'phone': phone,
        'message': message,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка отправки обратной связи: $e');
      return false;
    }
  }

  // Массовая отправка push-уведомлений по роли
  Future<Map<String, dynamic>> sendPushToRole({
    required String role,
    required String title,
    required String body,
  }) async {
    try {
      final response = await _makeRequest('sendPushToRole', {
        'role': role,
        'title': title,
        'body': body,
      });

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Ошибка отправки'};
    } catch (e) {
      print('❌ Ошибка массовой отправки: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // 🔥 ПОЛУЧЕНИЕ КОНТАКТОВ АДМИНА
  Future<Map<String, String>?> fetchAdminContact() async {
    try {
      final response = await _makeRequest('fetchEmployees', {
        'filters': {'role': 'Администратор'},
      });
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true && result['employees'] != null) {
          final admins = List.from(result['employees']);
          if (admins.isNotEmpty) {
            return {
              'name': admins[0]['name']?.toString() ?? '',
              'phone': admins[0]['phone']?.toString() ?? '',
              'email': admins[0]['email']?.toString() ?? '',
              'schedule':
                  admins[0]['schedule']?.toString() ?? 'Пн-Пт: 9:00 - 18:00',
            };
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Ошибка загрузки контактов админа: $e');
      return null;
    }
  }
}
