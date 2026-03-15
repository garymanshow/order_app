// lib/models/price_category.dart
import '../utils/parsing_utils.dart';

class PriceCategory {
  final String id;
  final String name;
  final int packagingQuantity; // Фасовка в таре
  final String packagingName; // Тара
  final double weight; // Вес
  final String unit; // Ед.изм.
  final int wastePercentage; // Издержки (процент)

  PriceCategory({
    required this.id,
    required this.name,
    required this.packagingQuantity,
    required this.packagingName,
    required this.weight,
    required this.unit,
    required this.wastePercentage,
  });

  factory PriceCategory.fromJson(Map<String, dynamic> json) {
    return PriceCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      packagingQuantity: ParsingUtils.parseInt(json['packagingQuantity']) ?? 1,
      packagingName:
          json['packagingName']?.toString() ?? 'Транспортный контейнер',
      weight: ParsingUtils.parseDouble(json['weight']) ?? 0.0,
      unit: json['unit']?.toString() ?? 'г',
      wastePercentage: ParsingUtils.parseInt(json['wastePercentage']) ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'packagingQuantity': packagingQuantity,
      'packagingName': packagingName,
      'weight': weight,
      'unit': unit,
      'wastePercentage': wastePercentage,
    };
  }

  // Для совместимости с Google Sheets
  factory PriceCategory.fromMap(Map<String, dynamic> map) {
    return PriceCategory(
      id: map['ID']?.toString() ?? '',
      name: map['Наименование']?.toString() ?? '',
      packagingQuantity:
          int.tryParse(map['Фасовка в таре']?.toString() ?? '1') ?? 1,
      packagingName: map['Тара']?.toString() ?? 'Транспортный контейнер',
      weight: double.tryParse(map['Вес']?.toString() ?? '0') ?? 0.0,
      unit: map['Ед.изм.']?.toString() ?? 'г',
      wastePercentage: int.tryParse(map['Издержки']?.toString() ?? '10') ?? 10,
    );
  }
}
