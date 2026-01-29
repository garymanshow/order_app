// lib/models/nutrition.dart
class Nutrition {
  final String? priceListId;
  final String? calories;
  final String? proteins;
  final String? fats;
  final String? carbohydrates;

  Nutrition({
    this.priceListId,
    this.calories,
    this.proteins,
    this.fats,
    this.carbohydrates,
  });

  factory Nutrition.fromMap(Map<String, dynamic> map) {
    return Nutrition(
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
