// lib/services/google_sheets_service.dart
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

    final timeStr = (response.values?.first.first ?? '') as String;
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
  /// Обновляет данные в таблице
  /// Либо по rowIndex, либо по filters (только одно из двух)
  Future<void> update({
    required String sheetName,
    int? rowIndex,
    List<Map<String, String>>? filters,
    required Map<String, dynamic> data,
  }) async {
    _ensureInitialized();

    if (rowIndex == null && filters == null) {
      throw Exception('Должен быть указан либо rowIndex, либо filters');
    }

    if (rowIndex != null && filters != null) {
      throw Exception('Нельзя указывать одновременно rowIndex и filters');
    }

    if (rowIndex != null) {
      // Существующая логика по rowIndex
      final headersResponse = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId,
        '$sheetName!1:1',
      );
      final headers = headersResponse.values?.first ?? [];

      final rowValues = List.filled(headers.length, '');
      data.forEach((key, value) {
        final index = headers.indexOf(key);
        if (index != -1) {
          rowValues[index] = value.toString();
        }
      });

      await _sheetsApi!.spreadsheets.values.update(
        sheets.ValueRange(values: [rowValues]),
        _spreadsheetId,
        '$sheetName!A$rowIndex',
        valueInputOption: 'RAW',
      );
    } else if (filters != null) {
      // 🔥 БЕЗОПАСНОЕ ОБНОВЛЕНИЕ ДЛЯ КОРОТКИХ СТРОК
      final allData = await _readAllRows(sheetName);
      if (allData.isEmpty) return;

      final headers = allData[0].cast<String>();
      final dataRows = allData.skip(1).toList();

      for (int i = 0; i < dataRows.length; i++) {
        final originalRow = dataRows[i];
        bool matches = true;

        // Проверяем фильтры (с безопасным доступом к ячейкам)
        for (var filter in filters) {
          final colIndex = headers.indexOf(filter['column']!);
          if (colIndex == -1) continue;

          final cellValue =
              (colIndex < originalRow.length ? originalRow[colIndex] : '')
                  .toString();
          if (cellValue != filter['value']) {
            matches = false;
            break;
          }
        }

        if (matches) {
          // 🔥 Дополняем строку до нужной длины
          final normalizedRow = List<String>.filled(headers.length, '');
          for (int j = 0; j < originalRow.length && j < headers.length; j++) {
            normalizedRow[j] = originalRow[j].toString();
          }

          // Обновляем указанные поля
          data.forEach((column, value) {
            final colIndex = headers.indexOf(column);
            if (colIndex != -1) {
              String cellValue = value.toString();
              // Нормализация телефона (если применимо)
              if (column == 'Телефон' && !cellValue.startsWith('+')) {
                cellValue = '+$cellValue';
              }
              normalizedRow[colIndex] = cellValue;
            }
          });

          final rowIndexToUpdate = i + 2;
          await _sheetsApi!.spreadsheets.values.update(
            sheets.ValueRange(values: [normalizedRow]),
            _spreadsheetId,
            '$sheetName!A$rowIndexToUpdate',
            valueInputOption: 'RAW',
          );
        }
      }
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

    // 🔥 ИСПОЛЬЗУЕМ BATCH ДЛЯ УДАЛЕНИЯ
    if (rowIndexes.isNotEmpty) {
      final requests = <sheets.Request>[];

      // Удаляем в обратном порядке для корректности индексов
      for (final rowIndex in rowIndexes.reversed) {
        requests.add(
          sheets.Request(
            deleteDimension: sheets.DeleteDimensionRequest(
              range: sheets.DimensionRange(
                sheetId: await getSheetId(sheetName),
                dimension: 'ROWS',
                startIndex: rowIndex - 1,
                endIndex: rowIndex,
              ),
            ),
          ),
        );
      }

      await batchUpdate(requests);
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// 🔥 Выполняет несколько операций в одном запросе
  Future<void> batchUpdate(List<sheets.Request> requests) async {
    _ensureInitialized();

    if (requests.isEmpty) return;

    final batchRequest = sheets.BatchUpdateSpreadsheetRequest(
      requests: requests,
    );

    await _sheetsApi!.spreadsheets.batchUpdate(
      batchRequest,
      _spreadsheetId,
    );
  }

  /// 🔥 Находит rowIndex по фильтрам (для использования в batch-запросах)
  Future<int?> findRowIndexByFilters({
    required String sheetName,
    required List<Map<String, String>> filters,
  }) async {
    _ensureInitialized();

    final allData = await _readAllRows(sheetName);
    if (allData.isEmpty) return null;

    final headers = allData[0].cast<String>();
    final dataRows = allData.skip(1).toList();

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      bool matches = true;

      for (var filter in filters) {
        final colIndex = headers.indexOf(filter['column']!);
        if (colIndex == -1) continue;
        final cellValue =
            (colIndex < row.length ? row[colIndex] : '').toString();
        if (cellValue != filter['value']) {
          matches = false;
          break;
        }
      }

      if (matches) {
        return i + 2; // 1-based индексация + заголовок
      }
    }

    return null;
  }

  /// 🔥 Создаёт запрос на обновление строки для batch-операции
  Future<sheets.Request> createUpdateRowRequest({
    required String sheetName,
    required int rowIndex,
    required Map<String, dynamic> data,
  }) async {
    _ensureInitialized();

    final headersResponse = await _sheetsApi!.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!1:1',
    );
    final headers = headersResponse.values?.first ?? [];
    final sheetId = await getSheetId(sheetName);

    final rowValues = List.filled(headers.length, '');
    data.forEach((key, value) {
      final index = headers.indexOf(key);
      if (index != -1) {
        rowValues[index] = value.toString();
      }
    });

    return sheets.Request(
      updateCells: sheets.UpdateCellsRequest(
        rows: [
          sheets.RowData(
            values: rowValues
                .map((cell) => sheets.CellData(
                    userEnteredValue: sheets.ExtendedValue(stringValue: cell)))
                .toList(),
          ),
        ],
        fields: 'userEnteredValue',
        start: sheets.GridCoordinate(
          sheetId: sheetId,
          rowIndex: rowIndex - 1, // 0-based для API
          columnIndex: 0,
        ),
      ),
    );
  }

  /// 🔥 Создаёт запрос на добавление строк для batch-операции
  Future<sheets.Request> createAppendRowsRequest({
    required String sheetName,
    required List<List<dynamic>> records,
  }) async {
    _ensureInitialized();

    final sheetId = await getSheetId(sheetName);

    final rowData = records.map((record) {
      return sheets.RowData(
        values: record
            .map((cell) => sheets.CellData(
                userEnteredValue:
                    sheets.ExtendedValue(stringValue: cell.toString())))
            .toList(),
      );
    }).toList();

    return sheets.Request(
      appendCells: sheets.AppendCellsRequest(
        sheetId: sheetId,
        fields: 'userEnteredValue',
        rows: rowData,
      ),
    );
  }

  /// 🔥 Создаёт запрос на удаление строк для batch-операции
  Future<sheets.Request> createDeleteRowsRequest({
    required String sheetName,
    required int startRowIndex,
    required int rowCount,
  }) async {
    _ensureInitialized();

    final sheetId = await getSheetId(sheetName);

    return sheets.Request(
      deleteDimension: sheets.DeleteDimensionRequest(
        range: sheets.DimensionRange(
          sheetId: sheetId,
          dimension: 'ROWS',
          startIndex: startRowIndex - 1, // 0-based
          endIndex: startRowIndex - 1 + rowCount, // 0-based, exclusive
        ),
      ),
    );
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  Future<List<List<dynamic>>> _readAllRows(String sheetName) async {
    final response = await _sheetsApi!.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!A:Z',
    );
    return response.values ?? [];
  }

  Future<int> getSheetId(String sheetName) async {
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
