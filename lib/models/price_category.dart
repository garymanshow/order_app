import 'package:flutter/foundation.dart';
import '../utils/parsing_utils.dart';

class PriceCategory {
  final String id;
  final String name;
  final int packagingQuantity; // Фасовка в таре
  final String packagingName; // Тара
  final double weight; // Вес
  final String unit; // Ед.изм.
  final int wastePercentage; // Издержки (процент)
  final String description;

  PriceCategory({
    required this.id,
    required this.name,
    this.packagingQuantity = 1,
    this.packagingName = '',
    this.weight = 0.0,
    this.unit = 'г',
    this.wastePercentage = 10,
    this.description = '',
  });

  /// 🔥 ОТЛАДКА: Печатаем ключи, которые приходят в метод
  factory PriceCategory.fromJson(Map<String, dynamic> json) {
    // ВРЕМЕННЫЙ ЛОГ ДЛЯ ОТЛАДКИ (убрать после fixes)
    if (json['ID'] != null || json['id'] != null) {
      // Логируем только если это не пустая карта
      debugPrint(
          '🛠 PriceCategory.fromJson: ID=${json['ID'] ?? json['id']}, Name=${json['Наименование'] ?? json['name']}');
    }

    return PriceCategory(
      // ID: проверяем 'ID' (Google Sheets), потом 'id' (Hive)
      id: json['ID']?.toString() ?? json['id']?.toString() ?? '',

      // Name: проверяем 'Наименование' (Google Sheets), потом 'name' (Hive)
      name: json['Наименование']?.toString() ?? json['name']?.toString() ?? '',

      packagingQuantity: ParsingUtils.parseInt(json['Фасовка в таре']) ??
          ParsingUtils.parseInt(json['packagingQuantity']) ??
          1,

      packagingName: json['Тара']?.toString() ??
          json['packagingName']?.toString() ??
          'Транспортный контейнер',

      weight: ParsingUtils.parseDouble(json['Вес']) ??
          ParsingUtils.parseDouble(json['weight']) ??
          0.0,

      unit: json['Ед.изм.']?.toString() ?? json['unit']?.toString() ?? 'г',

      wastePercentage: ParsingUtils.parseInt(json['Издержки']) ??
          ParsingUtils.parseInt(json['wastePercentage']) ??
          10,
      description:
          json['Описание']?.toString() ?? json['description']?.toString() ?? '',
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
      'description': description,
    };
  }
}
