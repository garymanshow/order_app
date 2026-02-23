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

  // 🔥 ИСПРАВЛЕНО: безопасный fromJson
  factory IngredientInfo.fromJson(Map<String, dynamic> json) {
    return IngredientInfo(
      name: json['name']?.toString() ?? '',
      quantity: ParsingUtils.parseDouble(json['quantity']) ?? 0.0,
      unit: json['unit']?.toString() ?? 'г',
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toJson
  Map<String, dynamic> toJson() {
    return {
      'name': name ?? '',
      'quantity': quantity,
      'unit': unit ?? 'г',
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
