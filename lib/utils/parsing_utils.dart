//  lib/utils/parsing_utils.dart
import 'dart:typed_data';

class NumberUtils {
  static double? parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }
}

class ParsingUtils {
  // Парсит строку в double с поддержкой русских форматов (запятая как десятичный разделитель)
  static double? parseDiscount(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^\d,.-]'), '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.replaceAll(',', '.');
    try {
      return double.parse(normalized);
    } catch (e) {
      return null;
    }
  }

  /// Парсит строку в bool с поддержкой нескольких форматов
  static bool? parseBool(String? value) {
    if (value == null) return null;
    final str = value.toLowerCase().trim();
    return str == 'true' || str == '1' || str == 'да' || str == 'yes';
  }

  /// Безопасное преобразование строки в double (универсальный метод)
  static double? parseDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return double.tryParse(value.trim());
    } catch (e) {
      return null;
    }
  }

  /// Безопасное преобразование строки в int
  static int? parseInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return int.tryParse(value.trim());
    } catch (e) {
      return null;
    }
  }

  /// Парсит наценку/скидку, поддерживающую суффикс "%"
  /// Примеры: "15", "20%", " 25.5 % "
  static double? parseMarkup(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    String numberStr;
    if (trimmed.endsWith('%')) {
      numberStr = trimmed.substring(0, trimmed.length - 1).trim();
    } else {
      numberStr = trimmed;
    }
    return parseDouble(numberStr);
  }

  /// Парсит строку вида "1,2,3,4" в Uint8List
  /// Используется, например, для хранения бинарных данных в Google Таблицах
  static Uint8List? parseByteList(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    try {
      final parts = input.split(',');
      final parsedBytes = <int>[];
      for (final part in parts) {
        final num = int.tryParse(part.trim());
        if (num == null) return null;
        parsedBytes.add(num);
      }
      return Uint8List.fromList(parsedBytes);
    } catch (e) {
      return null;
    }
  }

  /// Парсит дату в формате DD.MM.YYYY → DateTime
  /// Если не удаётся — возвращает заглушку (можно изменить на null)
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final parts = dateStr.trim().split('.');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (e) {
      // ignore
    }
    return null; // или DateTime(2000, 1, 1), если нужна заглушка
  }
}
