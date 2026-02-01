// lib/services/api_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Models
import '../models/client.dart';
import '../models/employee.dart';
import '../models/sheet_metadata.dart';
import '../models/product.dart';
import '../models/order_item.dart';
import '../models/composition.dart';
import '../models/filling.dart';
import '../models/nutrition_info.dart';
import '../models/delivery_condition.dart';
import '../models/client_category.dart';
import '../models/client_data.dart';

class ApiService {
  Future<Map<String, dynamic>?> authenticate({
    required String phone,
    required Map<String, SheetMetadata> localMetadata,
    String? fcmToken,
  }) async {
    final url =
        Uri.parse('${dotenv.env['APPS_SCRIPT_URL']}?action=authenticate');

    final requestBody = {
      'phone': phone,
      'localMetadata': localMetadata
          .map((key, value) => MapEntry(key, value.toJson()))
          .cast<String, dynamic>(),
      if (fcmToken != null) 'fcmToken': fcmToken,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Десериализация ответа
        final userData = data['user'];
        final metadataData = data['metadata'];
        final clientData = data['clientData'];

        // 🔥 НОВАЯ ЛОГИКА: ПОДДЕРЖКА МНОЖЕСТВЕННЫХ РОЛЕЙ
        dynamic user;
        if (userData is List) {
          // Несколько ролей сотрудника
          user = userData; // Возвращаем массив как есть
        } else if (userData is Map<String, dynamic>) {
          // Один пользователь
          if (userData['role'] != null) {
            user = Employee.fromJson(userData);
          } else {
            user = Client.fromJson(userData);
          }
        } else {
          throw Exception('Неожиданный формат данных пользователя');
        }

        final metadata = (metadataData as Map<String, dynamic>).map(
            (key, value) => MapEntry(
                key, SheetMetadata.fromJson(value as Map<String, dynamic>)));

        final clientDataObj = _deserializeClientData(clientData);

        return {
          'user': user,
          'metadata': metadata,
          'data': clientDataObj,
        };
      }

      return null;
    } catch (e) {
      print('Ошибка API: $e');
      return null;
    }
  }

  // Обновление заказов
  Future<bool> updateOrders(List<OrderItem> orders) async {
    final url =
        Uri.parse('${dotenv.env['APPS_SCRIPT_URL']}?action=updateOrders');

    final ordersData = orders.map((order) => order.toJson()).toList();

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

  // 🔥 НОВЫЙ МЕТОД ОТПРАВКИ ЗАКАЗА
  Future<bool> submitOrder({
    required List<OrderItem> orders,
    required String phone,
    required String clientName,
  }) async {
    final url =
        Uri.parse('${dotenv.env['APPS_SCRIPT_URL']}?action=submitOrder');

    // Подготовка данных для отправки
    final ordersData = orders.map((order) {
      return {
        'Статус': order.status,
        'Название': order.productName,
        'Количество': order.quantity,
        'Итоговая цена': order.totalPrice,
        'Дата': order.date,
        'Телефон': order.clientPhone,
        'Клиент': order.clientName,
        'ID Прайс-лист': order.priceListId,
      };
    }).toList();

    final requestBody = {
      'orders': ordersData,
      'phone': phone,
      'clientName': clientName,
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
      print('Ошибка отправки заказа: $e');
      return false;
    }
  }

  ClientData _deserializeClientData(dynamic data) {
    if (data == null) return ClientData();

    final clientData = ClientData();
    final clientDataMap = data as Map<String, dynamic>;

    if (clientDataMap['products'] != null) {
      clientData.products = (clientDataMap['products'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['compositions'] != null) {
      clientData.compositions = (clientDataMap['compositions'] as List)
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['fillings'] != null) {
      clientData.fillings = (clientDataMap['fillings'] as List)
          .map((item) => Filling.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['nutritionInfos'] != null) {
      clientData.nutritionInfos = (clientDataMap['nutritionInfos'] as List)
          .map((item) => NutritionInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['orders'] != null) {
      clientData.orders = (clientDataMap['orders'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['deliveryConditions'] != null) {
      clientData.deliveryConditions =
          (clientDataMap['deliveryConditions'] as List)
              .map((item) =>
                  DeliveryCondition.fromJson(item as Map<String, dynamic>))
              .toList();
    }

    if (clientDataMap['clientCategories'] != null) {
      clientData.clientCategories = (clientDataMap['clientCategories'] as List)
          .map((item) => ClientCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    clientData.buildIndexes();
    return clientData;
  }
}
