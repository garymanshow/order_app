// lib/models/nutrition_info.dart

class NutritionInfo {
  final String? id; // Уникальный ID записи (опционально)
  final String? priceListId; // ID сущности (Товар или Категория)
  final String? level; // Уровень: "Категории прайса" или "Прайс-лист"

  final String? calories;
  final String? proteins;
  final String? fats;
  final String? carbohydrates;

  NutritionInfo({
    this.id,
    this.priceListId,
    this.level,
    this.calories,
    this.proteins,
    this.fats,
    this.carbohydrates,
  });

  // Парсинг из Google Sheets
  factory NutritionInfo.fromMap(Map<String, dynamic> map) {
    return NutritionInfo(
      id: map['ID']?.toString(),
      priceListId: map['ID сущности']?.toString().isNotEmpty == true
          ? map['ID сущности']?.toString()
          : null,
      level: map['Лист']?.toString().isNotEmpty == true
          ? map['Лист']?.toString()
          : 'Прайс-лист',
      calories: map['Калории']?.toString(),
      proteins: map['Белки']?.toString(),
      fats: map['Жиры']?.toString(),
      carbohydrates: map['Углеводы']?.toString(),
    );
  }

  // Парсинг из JSON (Hive/API)
  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      id: json['id']?.toString(),
      // Поддержка обоих вариантов ключа для надежности
      priceListId:
          json['priceListId']?.toString() ?? json['ID сущности']?.toString(),
      level: json['level']?.toString() ?? 'Прайс-лист',
      calories: json['calories']?.toString(),
      proteins: json['proteins']?.toString(),
      fats: json['fats']?.toString(),
      carbohydrates: json['carbohydrates']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'priceListId': priceListId,
      'level': level,
      'calories': calories,
      'proteins': proteins,
      'fats': fats,
      'carbohydrates': carbohydrates,
    };
  }
}
