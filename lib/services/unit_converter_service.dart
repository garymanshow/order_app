// lib/services/unit_converter_service.dart
import '../models/unit_of_measure.dart';
import '../models/unit_of_measure_sheet.dart';

class UnitConversionException implements Exception {
  final String message;
  UnitConversionException(this.message);

  @override
  String toString() => 'Ошибка конвертации: $message';
}

class UnitConverterService {
  // Карта соответствия строковых обозначений UnitType
  static final Map<String, UnitType> _symbolToType = {
    // Русские обозначения
    'г': UnitType.gram,
    'кг': UnitType.kilogram,
    'мг': UnitType.milligram,
    'л': UnitType.liter,
    'мл': UnitType.milliliter,

    // Английские обозначения
    'g': UnitType.gram,
    'kg': UnitType.kilogram,
    'mg': UnitType.milligram,
    'l': UnitType.liter,
    'ml': UnitType.milliliter,
    'lb': UnitType.pound,
    'oz': UnitType.ounce,
    'gal': UnitType.gallon,
    'qt': UnitType.quart,
    'pt': UnitType.pint,
    'cup': UnitType.cup,
    'fl oz': UnitType.fluidOunce,
    'tbsp': UnitType.tablespoon,
    'tsp': UnitType.teaspoon,
  };

  // Конвертирует значение из одной единицы в другую
  static double convert({
    required double value,
    required UnitType from,
    required UnitType to,
  }) {
    if (from.category != to.category) {
      throw UnitConversionException(
          'Невозможно конвертировать ${from.category.ruName} в ${to.category.ruName}');
    }

    final baseValue = value * from.toBaseUnit;
    return baseValue / to.toBaseUnit;
  }

  // Конвертирует с использованием данных из листа
  static double convertWithSheetData({
    required double value,
    required UnitOfMeasureSheet from,
    required UnitOfMeasureSheet to,
  }) {
    if (from.category != to.category) {
      throw UnitConversionException(
          'Невозможно конвертировать ${from.category} в ${to.category}');
    }

    // Конвертируем в базовую единицу
    final baseValue = value * from.toBase;

    // Конвертируем из базовой в целевую
    return baseValue / to.toBase;
  }

  // Конвертирует объект UnitOfMeasure в другую единицу
  static UnitOfMeasure convertUnit({
    required UnitOfMeasure unit,
    required UnitType toType,
  }) {
    final newValue = convert(
      value: unit.value,
      from: unit.type,
      to: toType,
    );

    return UnitOfMeasure(type: toType, value: newValue);
  }

  // Получает UnitType по строковому обозначению
  static UnitType? getUnitType(String symbol) {
    return _symbolToType[symbol.toLowerCase()];
  }

  // Парсит строку с количеством и единицей измерения
  static UnitOfMeasure? parseFromString(String input) {
    input = input.trim().toLowerCase();

    final regex = RegExp(r'^(\d*[.,]?\d+)\s*([а-яa-z]+\.?)');
    final match = regex.firstMatch(input);

    if (match == null) return null;

    final valueStr = match.group(1)!.replaceAll(',', '.');
    final value = double.tryParse(valueStr);
    if (value == null) return null;

    final unitSymbol = match.group(2)!.replaceAll('.', '');
    final unitType = getUnitType(unitSymbol);

    if (unitType == null) return null;

    return UnitOfMeasure(type: unitType, value: value);
  }

  // Конвертирует в метрическую систему для склада
  static double convertToMetric({
    required double quantity,
    required String unitSymbol,
  }) {
    final unitType = getUnitType(unitSymbol);
    if (unitType == null) return quantity;

    final targetType = unitType.category == UnitCategory.weight
        ? UnitType.kilogram
        : UnitType.liter;

    return convert(
      value: quantity,
      from: unitType,
      to: targetType,
    );
  }

  // Конвертирует с использованием данных из листа
  static double convertToMetricWithSheet({
    required double quantity,
    required UnitOfMeasureSheet from,
  }) {
    if (from.category == 'weight') {
      // Для веса конвертируем в кг
      if (from.baseUnit == 'г') {
        return quantity * from.toBase / 1000;
      }
    } else if (from.category == 'volume') {
      // Для объема конвертируем в л
      if (from.baseUnit == 'мл') {
        return quantity * from.toBase / 1000;
      }
    }

    return quantity * from.toBase;
  }

  // Получает целевую единицу для склада
  static String getTargetUnit(String sourceUnit) {
    final unitType = getUnitType(sourceUnit);
    if (unitType == null) return sourceUnit;

    return unitType.category == UnitCategory.weight ? 'кг' : 'л';
  }

  // Конвертирует граммы в килограммы
  static double gramsToKg(double grams) {
    return grams / 1000;
  }

  // Конвертирует килограммы в граммы
  static double kgToGrams(double kg) {
    return kg * 1000;
  }

  // Конвертирует миллилитры в литры
  static double mlToL(double ml) {
    return ml / 1000;
  }

  // Конвертирует литры в миллилитры
  static double lToMl(double l) {
    return l * 1000;
  }
}
