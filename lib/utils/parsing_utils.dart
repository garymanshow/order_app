// lib/utils/parsing_utils.dart
import 'dart:typed_data';

class NumberUtils {
  static double? parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }
}

class ParsingUtils {
  // 🔥 УНИВЕРСАЛЬНЫЙ МЕТОД: принимает dynamic и конвертирует в double
  static double? toDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }

    return null;
  }

  // 🔥 ИСПРАВЛЕН: парсит скидку с поддержкой русских форматов, принимает dynamic
  static double? parseDiscount(dynamic raw) {
    if (raw == null) return null;

    // Если уже число - возвращаем как double
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();

    // Если строка - обрабатываем
    String str;
    if (raw is String) {
      str = raw.trim();
    } else {
      str = raw.toString().trim();
    }

    if (str.isEmpty) return null;

    // Удаляем все, кроме цифр, запятых, точек и минуса
    final cleaned = str.replaceAll(RegExp(r'[^\d,.-]'), '');
    if (cleaned.isEmpty) return null;

    final normalized = cleaned.replaceAll(',', '.');
    try {
      return double.parse(normalized);
    } catch (e) {
      return null;
    }
  }

  /// 🔥 ИСПРАВЛЕН: парсит строку в bool с поддержкой нескольких форматов, принимает dynamic
  static bool? parseBool(dynamic value) {
    if (value == null) return null;

    // Если уже bool
    if (value is bool) return value;

    // Если число
    if (value is num) {
      return value == 1;
    }

    // Если строка
    final str = value.toString().toLowerCase().trim();
    if (str.isEmpty) return null;

    return str == 'true' ||
        str == '1' ||
        str == 'да' ||
        str == 'yes' ||
        str == 'истина';
  }

  /// 🔥 ИСПРАВЛЕН: безопасное преобразование в double, принимает dynamic
  static double? parseDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }

    return null;
  }

  /// 🔥 ИСПРАВЛЕН: безопасное преобразование в int, принимает dynamic
  static int? parseInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }

    return null;
  }

  /// Парсит наценку/скидку, поддерживающую суффикс "%"
  /// Примеры: "15", "20%", " 25.5 % "
  static double? parseMarkup(dynamic value) {
    if (value == null) return null;

    String str;
    if (value is String) {
      str = value.trim();
    } else {
      str = value.toString().trim();
    }

    if (str.isEmpty) return null;

    String numberStr;
    if (str.endsWith('%')) {
      numberStr = str.substring(0, str.length - 1).trim();
    } else {
      numberStr = str;
    }

    return parseDouble(numberStr);
  }

  /// Парсит строку вида "1,2,3,4" в Uint8List
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
    return null;
  }

  /// 🔥 НОВЫЙ: универсальный метод для безопасного получения строки
  static String? safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Если строка пустая или состоит только из пробелов - возвращаем null
      return value.trim().isEmpty ? null : value.trim();
    }
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  /// Универсальный метод для безопасного получения числа
  static num? safeNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return num.tryParse(trimmed);
    }
    return null;
  }
}
