// lib/models/unit_of_measure_sheet.dart
import 'unit_of_measure.dart';
import '../utils/parsing_utils.dart';

class UnitOfMeasureSheet {
  final String code; // GR, KG, ML и т.д.
  final String symbol; // г, кг, мл
  final String name; // грамм, килограмм
  final String category; // weight, volume, piece
  final double toBase; // коэффициент к базовой
  final String baseUnit; // г, мл, шт

  UnitOfMeasureSheet({
    required this.code,
    required this.symbol,
    required this.name,
    required this.category,
    required this.toBase,
    required this.baseUnit,
  });

  factory UnitOfMeasureSheet.fromJson(Map<String, dynamic> json) {
    return UnitOfMeasureSheet(
      code: ParsingUtils.safeString(json['code']) ?? '',
      symbol: ParsingUtils.safeString(json['symbol']) ?? '',
      name: ParsingUtils.safeString(json['name']) ?? '',
      category: ParsingUtils.safeString(json['category']) ?? '',
      toBase: ParsingUtils.parseDouble(json['toBase']) ?? 1.0,
      baseUnit: ParsingUtils.safeString(json['baseUnit']) ?? '',
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
    };
  }

  // Для Google Sheets
  Map<String, dynamic> toMap() {
    return {
      'Код': code,
      'Символ': symbol,
      'Название': name,
      'Категория': category,
      'Коэффициент к базовой': toBase.toString().replaceAll('.', ','),
      'Базовая единица': baseUnit,
    };
  }

  factory UnitOfMeasureSheet.fromMap(Map<String, dynamic> map) {
    return UnitOfMeasureSheet(
      code: map['Код']?.toString() ?? '',
      symbol: map['Символ']?.toString() ?? '',
      name: map['Название']?.toString() ?? '',
      category: map['Категория']?.toString() ?? '',
      toBase: double.tryParse(
              map['Коэффициент к базовой']?.toString().replaceAll(',', '.') ??
                  '1') ??
          1.0,
      baseUnit: map['Базовая единица']?.toString() ?? '',
    );
  }

  // Для отображения в UI
  String get displayName => '$symbol - $name';
}
