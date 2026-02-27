// lib/models/nutrition_info.dart
class NutritionInfo {
  //Энергетическая ценность (КЖБУ)
  final String? priceListId;
  final String? calories;
  final String? proteins;
  final String? fats;
  final String? carbohydrates;

  NutritionInfo({
    this.priceListId,
    this.calories,
    this.proteins,
    this.fats,
    this.carbohydrates,
  });

  // 🔥 fromMap для Google Таблиц
  factory NutritionInfo.fromMap(Map<String, dynamic> map) {
    return NutritionInfo(
      priceListId: map['ID Прайс-лист']?.toString().isNotEmpty == true
          ? map['ID Прайс-лист']?.toString()
          : null,
      calories: map['Калории']?.toString().isNotEmpty == true
          ? map['Калории']?.toString()
          : null,
      proteins: map['Белки']?.toString().isNotEmpty == true
          ? map['Белки']?.toString()
          : null,
      fats: map['Жиры']?.toString().isNotEmpty == true
          ? map['Жиры']?.toString()
          : null,
      carbohydrates: map['Углеводы']?.toString().isNotEmpty == true
          ? map['Углеводы']?.toString()
          : null,
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный fromJson
  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      priceListId: json['priceListId']?.toString(),
      calories: json['calories']?.toString(),
      proteins: json['proteins']?.toString(),
      fats: json['fats']?.toString(),
      carbohydrates: json['carbohydrates']?.toString(),
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toJson
  Map<String, dynamic> toJson() {
    return {
      'priceListId': priceListId,
      'calories': calories,
      'proteins': proteins,
      'fats': fats,
      'carbohydrates': carbohydrates,
    };
  }
  // Здесь всё нормально, так как все поля опциональные и могут быть null

  // toMap для Google Таблиц (если нужно)
  Map<String, dynamic> toMap() {
    return {
      'ID Прайс-лист': priceListId ?? '',
      'Калории': calories ?? '',
      'Белки': proteins ?? '',
      'Жиры': fats ?? '',
      'Углеводы': carbohydrates ?? '',
    };
  }
}
