// lib/models/delivery_condition.dart
import '../utils/parsing_utils.dart';

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
      hiddenMarkup: ParsingUtils.parseMarkup(map['Транпортные']?.toString()),
    );
  }

  factory DeliveryCondition.fromJson(Map<String, dynamic> json) {
    return DeliveryCondition(
      location: json['location'] as String,
      deliveryAmount: ParsingUtils.parseDouble(json['deliveryAmount']) ?? 0.00,
      hiddenMarkup: ParsingUtils.parseDouble(json['hiddenMarkup']) ?? 0.00,
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
}
