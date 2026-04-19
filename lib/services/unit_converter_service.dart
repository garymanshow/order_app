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

  // === РАБОТА СО ВРЕМЕНЕМ И СРОКАМИ ГОДНОСТИ ===

  /// Конвертирует значение времени в дни (базовая единица для хранения)
  /// Поддерживает: часы, дни, недели, месяцы, годы
  static double convertTimeToDays(double value, String unitSymbol) {
    final lowerSymbol = unitSymbol.toLowerCase();

    // Маппинг коэффициентов к дням
    // Можно вынести в UnitOfMeasureSheet, если добавить их в таблицу
    final Map<String, double> timeFactors = {
      'ч': 1 / 24, // час
      'час': 1 / 24,
      'hour': 1 / 24,
      'д': 1, // день
      'дн': 1,
      'день': 1,
      'day': 1,
      'сут': 1,
      'нед': 7, // неделя
      'неделя': 7,
      'week': 7,
      'мес': 30, // месяц (усредненно)
      'месяц': 30,
      'month': 30,
      'г': 365, // год
      'год': 365,
      'year': 365,
    };

    final factor = timeFactors[lowerSymbol] ?? 1.0;
    return value * factor;
  }

  /// Проверяет срок годности и возвращает статус
  /// Возвращает: normal, warning, expired
  static ShelfLifeStatus checkShelfLife({
    required DateTime productionDate,
    required double shelfLifeValue,
    required String shelfLifeUnit,
  }) {
    // 1. Конвертируем срок годности в дни
    final shelfLifeInDays = convertTimeToDays(shelfLifeValue, shelfLifeUnit);

    // 2. Вычисляем дату истечения срока
    final expirationDate =
        productionDate.add(Duration(days: shelfLifeInDays.round()));

    // 3. Сравниваем с текущей датой
    final now = DateTime.now();
    final difference = expirationDate.difference(now);

    if (difference.isNegative) {
      return ShelfLifeStatus.expired;
    } else if (difference.inDays <= 3) {
      // Предупреждение, если осталось меньше 3 дней
      return ShelfLifeStatus.warning;
    } else {
      return ShelfLifeStatus.normal;
    }
  }

  /// Форматирует оставшееся время в читаемый вид (например, "2 дня", "3 месяца")
  static String formatRemainingTime(DateTime expirationDate) {
    final now = DateTime.now();
    final difference = expirationDate.difference(now);

    if (difference.isNegative) return 'Истек';

    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months мес.';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} дн.';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} час.';
    } else {
      return 'Меньше часа';
    }
  }
}

/// Enum для статуса срока годности
enum ShelfLifeStatus {
  normal, // Зеленый
  warning, // Оранжевый
  expired, // Красный
}
