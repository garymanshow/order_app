// lib/models/delivery_condition.dart
//Условия доставки
class DeliveryCondition {
  final String location; // Пункт доставки (город, поселок и т.д.)
  final double deliveryAmount; // Сумма доставки
  final double? hiddenMarkup; // Скрытая наценка в процентах (например, 10.0)

  DeliveryCondition({
    required this.location,
    required this.deliveryAmount,
    this.hiddenMarkup,
  });

  factory DeliveryCondition.fromMap(Map<String, dynamic> map) {
    return DeliveryCondition(
      location: map['Пункт']?.toString() ?? '',
      deliveryAmount:
          double.tryParse(map['Сумма доставки']?.toString() ?? '0') ?? 0.0,
      hiddenMarkup: _parseMarkup(map['Транпортные']?.toString()),
    );
  }

  factory DeliveryCondition.fromJson(Map<String, dynamic> json) {
    return DeliveryCondition(
      location: json['location'] as String,
      deliveryAmount: json['deliveryAmount'] as double,
      hiddenMarkup: json['hiddenMarkup'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'deliveryAmount': deliveryAmount,
      'hiddenMarkup': hiddenMarkup,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'Пункт': location,
      'Сумма доставки': deliveryAmount.toString(),
      'Транпортные':
          hiddenMarkup != null ? '${hiddenMarkup!.toStringAsFixed(0)}%' : '',
    };
  }

  // Вспомогательный метод для расчета цены с наценкой
  double applyHiddenMarkup(double originalPrice) {
    if (hiddenMarkup == null || hiddenMarkup! <= 0) {
      return originalPrice;
    }
    return originalPrice * (1 + hiddenMarkup! / 100);
  }

  // Парсинг наценки из строки типа "10%"
  static double? _parseMarkup(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.endsWith('%')) {
      final numberStr = trimmed.substring(0, trimmed.length - 1).trim();
      return double.tryParse(numberStr);
    }

    return double.tryParse(trimmed);
  }
}
