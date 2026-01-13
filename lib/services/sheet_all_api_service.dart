import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SheetAllApiService {
  final String _secretKey = dotenv.env['APP_SCRIPT_SECRET'] ?? '';

  /// Чтение данных из листа
  Future<List<dynamic>> read({
    required String sheetName,
    List<Map<String, dynamic>>? filters,
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

    if (response['status'] == 'success') {
      return List<dynamic>.from(response['data'] ?? []);
    } else {
      throw Exception(response['message'] ?? 'Ошибка при чтении данных');
    }
  }

  /// Создание новых записей
  Future<bool> create({
    required String sheetName,
    required List<List<dynamic>> data,
  }) async {
    final response = await _sendRequest(
      action: 'create',
      sheetName: sheetName,
      data: {'data': data},
    );
    return response['status'] == 'success';
  }

  /// Обновление записей по фильтру
  Future<bool> update({
    required String sheetName,
    required List<Map<String, dynamic>> filters,
    required Map<String, dynamic> updateData,
  }) async {
    final response = await _sendRequest(
      action: 'update',
      sheetName: sheetName,
      filters: filters,
      data: {'data': updateData},
    );
    return response['status'] == 'success';
  }

  /// Удаление записей по фильтру
  Future<bool> delete({
    required String sheetName,
    required List<Map<String, dynamic>> filters,
  }) async {
    final response = await _sendRequest(
      action: 'delete',
      sheetName: sheetName,
      filters: filters,
    );
    return response['status'] == 'success';
  }

  /// Единая точка отправки запросов
  Future<Map<String, dynamic>> _sendRequest({
    required String action,
    required String sheetName,
    List<Map<String, dynamic>>? filters,
    Map<String, dynamic>? orderBy,
    int? limit,
    int? offset,
    dynamic data,
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

    print('DEBUG: Тело запроса: ${jsonEncode(payload)}');

    try {
      // ИСПОЛЬЗУЙТЕ ОРИГИНАЛЬНЫЙ URL APPS SCRIPT
      final url = dotenv.env['APP_SCRIPT_URL'] ?? '';
      print('DEBUG: Отправка на: $url');

      // Следуем редиректу вручную с GET-запросом

      // Создаем GET-запрос к редиректу (после получения 302)
      final client = http.Client();

      final request = http.Request('POST', Uri.parse(url))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(payload);

      // Отправляем запрос без автоматического следования редиректам
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      print('DEBUG: Статус: ${response.statusCode}');
      print('DEBUG: Content-Type: ${response.headers['content-type']}');

      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          print('DEBUG: Редирект на: $redirectUrl');

          // ВАЖНО: Google Apps Script редиректит на URL, который ожидает GET с параметрами в URL
          // Конструируем URL с параметрами как query string
          final jsonStr = Uri.encodeComponent(jsonEncode(payload));
          final getUrl = '$redirectUrl&__data=$jsonStr';

          print('DEBUG: GET запрос на: $getUrl');

          final getResponse = await http.get(
            Uri.parse(getUrl),
            headers: {'Content-Type': 'application/json'},
          );

          client.close();

          if (getResponse.headers['content-type']?.contains('text/html') ==
              true) {
            return {
              'status': 'error',
              'message': 'Apps Script вернул HTML при GET запросе.',
            };
          }

          print('DEBUG: GET ответ: ${getResponse.body}');
          return jsonDecode(getResponse.body) as Map<String, dynamic>;
        }
      }

      client.close();

      // Если ответ HTML, а не JSON
      if (response.headers['content-type']?.contains('text/html') == true) {
        return {
          'status': 'error',
          'message': 'Apps Script вернул HTML. Статус: ${response.statusCode}',
        };
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('DEBUG: Исключение: $e');
      return {
        'status': 'error',
        'message': 'Ошибка запроса: $e',
      };
    }
  }
}
