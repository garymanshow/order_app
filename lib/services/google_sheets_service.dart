import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleSheetsService {
  final String _spreadsheetId;
  sheets.SheetsApi? _sheetsApi;

  GoogleSheetsService(this._spreadsheetId);

  /// Инициализация сервиса с использованием Service Account из .env
  Future<void> init() async {
    final accountJsonBase64 = dotenv.env['GOOGLE_SERVICE_ACCOUNT_BASE64'];
    if (accountJsonBase64 == null) {
      throw Exception('GOOGLE_SERVICE_ACCOUNT_BASE64 not found in .env');
    }

    final jsonKey = utf8.decode(base64.decode(accountJsonBase64));
    final credentials = auth.ServiceAccountCredentials.fromJson(
      json.decode(jsonKey),
    );

    final authClient = await auth.clientViaServiceAccount(
      credentials,
      ['https://www.googleapis.com/auth/spreadsheets'],
    );

    _sheetsApi = sheets.SheetsApi(authClient);
  }

  /// Возвращает дату последнего обновления прайс-листа из листа "Метаданные"
  Future<DateTime> getLastPriceUpdateTime() async {
    _ensureInitialized();

    final response = await _sheetsApi!.spreadsheets.values.get(
      _spreadsheetId,
      'Метаданные!B1', // ← B1 содержит ISO-дату
    );

    final timeStr = (response.values?.first?.first ?? '') as String;
    if (timeStr.isEmpty) {
      return DateTime(1970); // очень старая дата → кэш всегда устаревший
    }

    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      print('Ошибка парсинга даты: $timeStr');
      return DateTime(1970);
    }
  }

  /// Преобразует List<List<dynamic>> в List<Map<String, dynamic>>
  List<Map<String, dynamic>> _rowsToRecords(
    List<List<dynamic>> rows,
  ) {
    if (rows.isEmpty) return [];
    final headers = rows[0].cast<String>();
    return rows.skip(1).map((row) {
      final map = <String, dynamic>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = i < row.length ? row[i] ?? '' : '';
      }
      return map;
    }).toList();
  }

  // ==================== READ ====================
  Future<List<Map<String, dynamic>>> read({
    required String sheetName,
    List<Map<String, String>>? filters,
  }) async {
    _ensureInitialized();

    // Читаем заголовки
    final headersResponse = await _sheetsApi!.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!1:1',
    );
    final headers =
        (headersResponse.values?.first ?? []).map((h) => h.toString()).toList();

    // Читаем все данные
    final dataResponse = await _sheetsApi!.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!2:${MAX_ROWS}', // например, 2:1000
    );

    final List<Map<String, dynamic>> records = [];

    if (dataResponse.values != null) {
      for (final row in dataResponse.values!) {
        // Пропускаем пустые строки
        if (row
            .every((cell) => cell == null || cell.toString().trim().isEmpty)) {
          continue;
        }

        final record = <String, dynamic>{};
        for (int i = 0; i < headers.length; i++) {
          final value = i < row.length ? row[i] : null;
          record[headers[i]] = value;
        }
        records.add(record);
      }
    }

    // Применяем фильтры (если есть)
    if (filters != null) {
      return records.where((record) {
        return filters.every((filter) {
          final cellValue = record[filter['column']]?.toString() ?? '';
          return cellValue == filter['value'];
        });
      }).toList();
    }

    return records;
  }

  static const int MAX_ROWS = 1000;

  // ==================== CREATE ====================
  Future<void> create({
    required String sheetName,
    required List<List<dynamic>> records,
  }) async {
    _ensureInitialized();
    await _sheetsApi!.spreadsheets.values.append(
      sheets.ValueRange(values: records),
      _spreadsheetId,
      '$sheetName!A:A',
      valueInputOption: 'USER_ENTERED',
    );
  }

  // ==================== UPDATE ====================
  Future<void> update({
    required String sheetName,
    required List<Map<String, String>> filters,
    required Map<String, dynamic> updateData,
  }) async {
    _ensureInitialized();

    // Сначала читаем все данные
    final allData = await _readAllRows(sheetName);
    if (allData.isEmpty) return;

    final headers = allData[0].cast<String>();
    final dataRows = allData.skip(1).toList();

    // Находим индексы строк для обновления
    final rowIndexes = <int>[];
    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      bool matches = true;
      for (var filter in filters) {
        final colIndex = headers.indexOf(filter['column']!);
        if (colIndex == -1) continue;
        final cellValue = (row[colIndex] ?? '').toString();
        if (cellValue != filter['value']) {
          matches = false;
          break;
        }
      }
      if (matches) {
        rowIndexes.add(i +
            2); // +2 потому что строки в Google Sheets начинаются с 1, и первая — заголовок
      }
    }

    // Обновляем каждую найденную строку
    for (int rowIndex in rowIndexes) {
      final range =
          '$sheetName!A$rowIndex:${String.fromCharCode('A'.codeUnitAt(0) + headers.length - 1)}$rowIndex';
      final newRow = List<dynamic>.filled(headers.length, '');
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i];
        if (updateData.containsKey(header)) {
          newRow[i] = updateData[header];
        } else {
          // Сохраняем старое значение
          newRow[i] = dataRows[rowIndex - 2][i] ?? '';
        }
      }
      await _sheetsApi!.spreadsheets.values.update(
        sheets.ValueRange(values: [newRow]),
        _spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    }
  }

  // ==================== DELETE ====================
  Future<void> delete({
    required String sheetName,
    required List<Map<String, String>> filters,
  }) async {
    _ensureInitialized();

    final allData = await _readAllRows(sheetName);
    if (allData.isEmpty) return;

    final headers = allData[0].cast<String>();
    final dataRows = allData.skip(1).toList();

    // Находим индексы строк для удаления (в обратном порядке!)
    final rowIndexes = <int>[];
    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      bool matches = true;
      for (var filter in filters) {
        final colIndex = headers.indexOf(filter['column']!);
        if (colIndex == -1) continue;
        final cellValue = (row[colIndex] ?? '').toString();
        if (cellValue != filter['value']) {
          matches = false;
          break;
        }
      }
      if (matches) {
        rowIndexes.add(i + 2); // +2: 1 — заголовок, 1 — смещение индекса
      }
    }

    // Удаляем с конца, чтобы не сбивались индексы
    for (int i = rowIndexes.length - 1; i >= 0; i--) {
      final rowIndex = rowIndexes[i];
      await _sheetsApi!.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(
          requests: [
            sheets.Request(
              deleteDimension: sheets.DeleteDimensionRequest(
                range: sheets.DimensionRange(
                  sheetId: await _getSheetId(sheetName),
                  dimension: 'ROWS',
                  startIndex: rowIndex - 1,
                  endIndex: rowIndex,
                ),
              ),
            ),
          ],
        ),
        _spreadsheetId,
      );
    }
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  Future<List<List<dynamic>>> _readAllRows(String sheetName) async {
    final response = await _sheetsApi!.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!A:Z',
    );
    return response.values ?? [];
  }

  Future<int> _getSheetId(String sheetName) async {
    final spreadsheet = await _sheetsApi!.spreadsheets.get(_spreadsheetId);
    final sheet = spreadsheet.sheets!.firstWhere(
      (s) => s.properties!.title == sheetName,
    );
    return sheet.properties!.sheetId!;
  }

  void _ensureInitialized() {
    if (_sheetsApi == null) {
      throw Exception(
          'GoogleSheetsService not initialized. Call init() first.');
    }
  }
}
