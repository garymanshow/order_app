// lib/services/sheets_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SheetsApiService {
  final String _webAppUrl =
      'https://script.google.com/macros/s/AKfycbzutzlds1N_cDHLFyd2o7Y-_il-EpGzRiSDCPQexChsXtaMravhovRPCGhAGeoD64OVeg/exec';
  final String _secretKey = dotenv.env['APP_SCRIPT_SECRET'] ??
      's3ivohyRqt7ZZTys3khBkTpsg+sP9tQzC9pyVabQd7Q=';

  Future<bool> _sendRequest(String action, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'secret': _secretKey,
          'data': data,
        }),
      );

      // 🔍 Проверка: если ответ — HTML, значит, ошибка
      if (response.headers['content-type']?.contains('text/html') == true) {
        print(
            'ERROR: Получен HTML вместо JSON. Проверьте URL и настройки Apps Script.');
        return false;
      }

      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      print('Ошибка: $e');
      return false;
    }
  }

  Future<bool> updateOrderStatus({
    required String phone,
    required String date,
    required String newStatus,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'updateStatusByPhoneAndDate',
          'sheetName': 'Заказы',
          'data': {'phone': phone, 'date': date, 'newStatus': newStatus},
          'secret': _secretKey,
        }),
      );
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      print('Ошибка обновления статуса: $e');
      return false;
    }
  }

  Future<bool> appendOrders(List<List<dynamic>> ordersRows) async {
    try {
      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'appendRows',
          'sheetName': 'Заказы',
          'data': ordersRows,
          'secret': _secretKey,
        }),
      );
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      print('Ошибка отправки заказа: $e');
      return false;
    }
  }

  Future<bool> deleteOrdersByPhoneAndClient({
    required String phone,
    required String clientName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'deleteOrdersByPhoneAndClient',
          'sheetName': 'Заказы',
          'data': {'phone': phone, 'clientName': clientName},
          'secret': _secretKey,
        }),
      );
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      print('Ошибка удаления заказов: $e');
      return false;
    }
  }
}
