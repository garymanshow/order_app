// lib/models/product_category.dart
import '../utils/parsing_utils.dart';

class ProductCategory {
  final String id;
  final String name;
  final int packagingQuantity; // Фасовка в таре
  final String packagingName; // Тара (название из склада)
  final double weight;
  final String unit;
  final int wastePercentage; // Процент издержек (10 = 10%)

  ProductCategory({
    required this.id,
    required this.name,
    required this.packagingQuantity,
    required this.packagingName,
    required this.weight,
    required this.unit,
    required this.wastePercentage, // Теперь обязательный параметр
  });

  // 🔥 ИСПРАВЛЕНО: безопасный fromJson
  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      packagingQuantity: ParsingUtils.parseInt(json['packagingQuantity']) ?? 1,
      packagingName: json['packagingName']?.toString() ?? '',
      weight: ParsingUtils.parseDouble(json['weight']) ?? 0.0,
      unit: json['unit']?.toString() ?? 'г',
      wastePercentage: ParsingUtils.parseInt(json['wastePercentage']) ?? 10,
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id ?? '',
      'name': name ?? '',
      'packagingQuantity': packagingQuantity,
      'packagingName': packagingName ?? '',
      'weight': weight,
      'unit': unit ?? 'г',
      'wastePercentage': wastePercentage,
    };
  }

  // Для Google Таблиц
  Map<String, dynamic> toMap() {
    return {
      'ID': id ?? '',
      'Наименование': name ?? '',
      'Фасовка в таре': packagingQuantity.toString(),
      'Тара': packagingName ?? '',
      'Вес': weight.toString(),
      'Ед.изм.': unit ?? 'г',
      'Издержки': wastePercentage.toString(),
    };
  }

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    // Безопасный парсинг с значением по умолчанию
    int parseWastePercentage(String? value) {
      if (value == null || value.isEmpty) return 10;
      final parsed = int.tryParse(value);
      return parsed ?? 10;
    }

    return ProductCategory(
      id: map['ID']?.toString() ?? '',
      name: map['Наименование']?.toString() ?? '',
      packagingQuantity:
          int.tryParse(map['Фасовка в таре']?.toString() ?? '1') ?? 1,
      packagingName: map['Тара']?.toString() ?? '',
      weight: double.tryParse(map['Вес']?.toString() ?? '0') ?? 0.0,
      unit: map['Ед.изм.']?.toString() ?? 'г',
      wastePercentage: parseWastePercentage(map['Издержки']?.toString()),
    );
  }

  // Метод для получения коэффициента издержек
  double getWasteMultiplier() {
    return 1 + (wastePercentage / 100.0);
  }
}
