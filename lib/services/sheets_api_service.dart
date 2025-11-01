// lib/services/sheets_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SheetsApiService {
  final String _webAppUrl =
      'https://script.google.com/macros/s/AKfycbzutzlds1N_cDHLFyd2o7Y-_il-EpGzRiSDCPQexChsXtaMravhovRPCGhAGeoD64OVeg/exec';

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
        }),
      );
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      print('Ошибка отправки заказа: $e');
      return false;
    }
  }
}
