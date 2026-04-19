// lib/models/unit_of_measure_sheet.dart

class UnitOfMeasureSheet {
  final String code;
  final String symbol;
  final String name;
  final String category; // weight, volume, piece, time
  final double toBase;
  final String baseUnit;

  // === НОВЫЕ ПОЛЯ ДЛЯ ВРЕМЕНИ ===
  final bool isTimeUnit;
  final String? baseTimeUnit; // Например, "день" или "час"
  // =============================

  UnitOfMeasureSheet({
    required this.code,
    required this.symbol,
    required this.name,
    required this.category,
    required this.toBase,
    required this.baseUnit,
    this.isTimeUnit = false,
    this.baseTimeUnit,
  });

  factory UnitOfMeasureSheet.fromJson(Map<String, dynamic> json) {
    // 🔥 ИСПРАВЛЕНО: Парсинг чисел с запятой (1,5 -> 1.5)
    double parseToBase(dynamic value) {
      if (value == null) return 1.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        // Заменяем запятую на точку перед парсингом
        return double.tryParse(value.replaceAll(',', '.')) ?? 1.0;
      }
      return 1.0;
    }

    final category =
        json['Категория'] as String? ?? json['category'] as String? ?? '';

    // Определяем, является ли единица временем
    // Можно добавить явную колонку "isTime" в таблицу, либо проверять по категории
    final isTime = category == 'time';

    return UnitOfMeasureSheet(
      code: json['Код'] as String? ?? json['code'] as String? ?? '',
      symbol: json['Символ'] as String? ?? json['symbol'] as String? ?? '',
      name: json['Название'] as String? ?? json['name'] as String? ?? '',
      category: category,
      toBase: parseToBase(json['Коэффициент к базовой'] ?? json['toBase']),
      baseUnit: json['Базовая единица'] as String? ??
          json['baseUnit'] as String? ??
          '',
      isTimeUnit: isTime,
      baseTimeUnit: isTime ? (json['Базовая единица'] ?? 'день') : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'symbol': symbol,
      'name': name,
      'category': category,
      'toBase': toBase,
      'baseUnit': baseUnit,
      'isTimeUnit': isTimeUnit,
      'baseTimeUnit': baseTimeUnit,
    };
  }
}
