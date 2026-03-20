// lib/models/unit_of_measure.dart
enum UnitSystem { metric, imperial }

enum UnitCategory { weight, volume }

extension UnitCategoryExtension on UnitCategory {
  String get ruName {
    switch (this) {
      case UnitCategory.weight:
        return 'Вес';
      case UnitCategory.volume:
        return 'Объем';
    }
  }
}

enum UnitType {
  // Метрические единицы веса
  gram(UnitCategory.weight, UnitSystem.metric, 'г', 'грамм', 'грамма',
      'граммов', 1.0),
  kilogram(UnitCategory.weight, UnitSystem.metric, 'кг', 'килограмм',
      'килограмма', 'килограммов', 1000.0),
  milligram(UnitCategory.weight, UnitSystem.metric, 'мг', 'миллиграмм',
      'миллиграмма', 'миллиграммов', 0.001),

  // Имперские единицы веса
  pound(UnitCategory.weight, UnitSystem.imperial, 'lb', 'фунт', 'фунта',
      'фунтов', 453.592),
  ounce(UnitCategory.weight, UnitSystem.imperial, 'oz', 'унция', 'унции',
      'унций', 28.3495),

  // Метрические единицы объема
  milliliter(UnitCategory.volume, UnitSystem.metric, 'мл', 'миллилитр',
      'миллилитра', 'миллилитров', 1.0),
  liter(UnitCategory.volume, UnitSystem.metric, 'л', 'литр', 'литра', 'литров',
      1000.0),

  // Имперские единицы объема
  gallon(UnitCategory.volume, UnitSystem.imperial, 'gal', 'галлон', 'галлона',
      'галлонов', 3785.41),
  quart(UnitCategory.volume, UnitSystem.imperial, 'qt', 'кварта', 'кварты',
      'кварт', 946.353),
  pint(UnitCategory.volume, UnitSystem.imperial, 'pt', 'пинта', 'пинты', 'пинт',
      473.176),
  cup(UnitCategory.volume, UnitSystem.imperial, 'cup', 'чашка', 'чашки',
      'чашек', 236.588),
  fluidOunce(UnitCategory.volume, UnitSystem.imperial, 'fl oz', 'жидкая унция',
      'жидкие унции', 'жидких унций', 29.5735),
  tablespoon(UnitCategory.volume, UnitSystem.imperial, 'tbsp', 'столовая ложка',
      'столовые ложки', 'столовых ложек', 14.7868),
  teaspoon(UnitCategory.volume, UnitSystem.imperial, 'tsp', 'чайная ложка',
      'чайные ложки', 'чайных ложек', 4.92892);

  final UnitCategory category;
  final UnitSystem system;
  final String symbol;
  final String ruNameNominative;
  final String ruNameGenitive;
  final String ruNamePlural;
  final double toBaseUnit;

  const UnitType(this.category, this.system, this.symbol, this.ruNameNominative,
      this.ruNameGenitive, this.ruNamePlural, this.toBaseUnit);

  bool get isWeight => category == UnitCategory.weight;
  bool get isVolume => category == UnitCategory.volume;
  bool get isMetric => system == UnitSystem.metric;
  bool get isImperial => system == UnitSystem.imperial;

  String getRuName(double value) {
    int integerPart = value.truncate();

    if (value != integerPart) {
      return ruNameGenitive;
    }

    int lastDigit = integerPart % 10;
    int lastTwoDigits = integerPart % 100;

    if (lastTwoDigits >= 11 && lastTwoDigits <= 19) {
      return ruNamePlural;
    }

    switch (lastDigit) {
      case 1:
        return ruNameNominative;
      case 2:
      case 3:
      case 4:
        return ruNameGenitive;
      default:
        return ruNamePlural;
    }
  }
}

class UnitOfMeasure {
  final UnitType type;
  final double value;

  const UnitOfMeasure({required this.type, required this.value});

  UnitOfMeasure copyWith({UnitType? type, double? value}) {
    return UnitOfMeasure(
      type: type ?? this.type,
      value: value ?? this.value,
    );
  }

  String toRussianString() {
    return '$value ${type.getRuName(value)}';
  }

  @override
  String toString() {
    return '$value ${type.symbol}';
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'value': value,
        'symbol': type.symbol,
      };

  factory UnitOfMeasure.fromJson(Map<String, dynamic> json) {
    return UnitOfMeasure(
      type: UnitType.values.firstWhere((e) => e.name == json['type']),
      value: (json['value'] as num).toDouble(),
    );
  }
}
