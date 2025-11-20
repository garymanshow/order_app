// lib/services/sheet_all_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SheetAllApiService {
  final String _webAppUrl = dotenv.env['APP_SCRIPT_URL'] ?? '';
  final String _secretKey = dotenv.env['APP_SCRIPT_SECRET'] ?? '';

  /// Единый метод отправки запроса
  Future<Map<String, dynamic>> _sendRequest({
    required String action,
    required String sheetName,
    Map<String, dynamic>? filters,
    Map<String, dynamic>? orderBy,
    int? limit,
    int? offset,
    dynamic? data,
  }) async {
    final payload = {
      'action': action,
      'sheetName': sheetName,
      'secret': _secretKey,
      if (filters != null) 'filter': filters,
      if (orderBy != null) 'orderBy': orderBy,
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
      if (data != null) 'data': data,
    };

    try {
      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.headers['content-type']?.contains('text/html') == true) {
        return {'success': false, 'error': 'Apps Script вернул HTML'};
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': 'Ошибка сети: $e'};
    }
  }

  // ——————— CRUD ———————

  Future<List<dynamic>> read({
    required String sheetName,
    Map<String, dynamic>? filters,
    Map<String, dynamic>? orderBy,
    int? limit,
    int? offset,
  }) async {
    final response = await _sendRequest(
      action: 'read',
      sheetName: sheetName,
      filters: filters,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Ошибка чтения');
    }
    return List<dynamic>.from(response['data'] ?? []);
  }

  Future<bool> create({
    required String sheetName,
    required List<dynamic> data,
  }) async {
    final response = await _sendRequest(
      action: 'create',
      sheetName: sheetName,
      data: data,
    );
    return response['success'] == true;
  }

  Future<bool> update({
    required String sheetName,
    required Map<String, dynamic> filters,
    required Map<String, dynamic> updateData,
  }) async {
    final response = await _sendRequest(
      action: 'update',
      sheetName: sheetName,
      filters: filters,
      data: {'updateData': updateData},
    );
    return response['success'] == true;
  }

  Future<bool> delete({
    required String sheetName,
    required Map<String, dynamic> filters,
  }) async {
    final response = await _sendRequest(
      action: 'delete',
      sheetName: sheetName,
      filters: filters,
    );
    return response['success'] == true;
  }
}
