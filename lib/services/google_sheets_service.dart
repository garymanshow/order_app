// lib/services/google_sheets_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class GoogleSheetsService {
  // 🔴 ЗАМЕНИТЕ <spreadsheet_id> НА ВАШ РЕАЛЬНЫЙ ID ТАБЛИЦЫ
  final String _sheetUrl =
      'https://docs.google.com/spreadsheets/d/16LQhpJgAduO-g7V5pl9zXNuvPMUzs0vwoHZJlz_FXe8/gviz/tq?tqx=out:csv';

  /// Удаляет внешние двойные кавычки из CSV-значения, если они есть
  String _cleanCsvField(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<List<Product>> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse(_sheetUrl));

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        final List<Product> products = [];

        // Пропускаем заголовок (i = 0)
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          // Разделяем по запятым (простой CSV-парсинг)
          List<String> columns = line.split(',');

          // Ожидаем как минимум 5 столбцов: ID, Название, Цена, Кратность, Фото
          if (columns.length < 5) continue;

          // Очищаем поля от кавычек и пробелов
          final id = _cleanCsvField(columns[0]);
          final name = _cleanCsvField(columns[1]);
          final priceStr = _cleanCsvField(columns[2]);
          final multiplicityStr = _cleanCsvField(columns[3]);
          final imageValue = _cleanCsvField(columns[4]);

          // Пропускаем строки без ID
          if (id.isEmpty) continue;

          // Обработка изображения
          String? imageUrl;
          String? imageBase64;

          if (imageValue.startsWith('http')) {
            imageUrl = imageValue;
          } else if (imageValue.isNotEmpty) {
            try {
              base64Decode(imageValue); // Проверка на валидный Base64
              imageBase64 = imageValue;
            } catch (e) {
              print('Некорректная Base64 строка: $imageValue');
            }
          }

          // Парсинг цены и кратности
          // Очистка и парсинг цены с поддержкой запятой
          double _parsePrice(String input) {
            // Удаляем всё, кроме цифр, точки и запятой
            final cleaned = input.replaceAll(RegExp(r'[^\d.,]'), '');

            // Если строка пуста — 0
            if (cleaned.isEmpty) return 0.0;

            // Заменяем запятую на точку (поддержка русской локали)
            final normalized = cleaned.replaceAll(',', '.');

            // Удаляем лишние точки (оставляем только одну)
            final parts = normalized.split('.');
            if (parts.length > 2) {
              // Например: "1.234.56" → "1234.56"
              final integerPart = parts.take(parts.length - 1).join('');
              final decimalPart = parts.last;
              return double.tryParse('$integerPart.$decimalPart') ?? 0.0;
            }

            return double.tryParse(normalized) ?? 0.0;
          }

          // Используем:
          final price = _parsePrice(priceStr);
          final multiplicity = int.tryParse(multiplicityStr) ?? 1;

          products.add(Product(
            id: id,
            name: name,
            imageUrl: imageUrl,
            imageBase64: imageBase64,
            price: price,
            multiplicity: multiplicity,
          ));
        }
        return products;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка загрузки данных из Google Sheets: $e');
    }
  }
}
