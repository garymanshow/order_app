// lib/models/ingredient_info.dart
import '../utils/parsing_utils.dart';

class IngredientInfo {
  final String name;
  final double quantity;
  final String unit;

  IngredientInfo({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory IngredientInfo.fromJson(Map<String, dynamic> json) {
    return IngredientInfo(
      name: json['name'] as String? ?? '',
      quantity: ParsingUtils.parseDouble(json['quantity']) ?? 0.0,
      unit: json['unit'] as String? ?? 'г',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory IngredientInfo.fromMap(Map<String, dynamic> map) {
    return IngredientInfo(
      name: map['name']?.toString() ?? '',
      quantity: double.tryParse(map['quantity']?.toString() ?? '0') ?? 0.0,
      unit: map['unit']?.toString() ?? 'г',
    );
  }
}
