// lib/models/ingredient.dart
class Ingredient {
  final String? priceListId;
  final String? ingredient;
  final String? quantity;
  final String? unit;

  Ingredient({
    this.priceListId,
    this.ingredient,
    this.quantity,
    this.unit,
  });

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      priceListId: map['ID Прайс-лист']?.toString().isNotEmpty == true
          ? map['ID Прайс-лист']?.toString()
          : null,
      ingredient: map['Ингредиент']?.toString().isNotEmpty == true
          ? map['Ингредиент']?.toString()
          : null,
      quantity: map['Количество']?.toString().isNotEmpty == true
          ? map['Количество']?.toString()
          : null,
      unit: map['Ед.изм.']?.toString().isNotEmpty == true
          ? map['Ед.изм.']?.toString()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID Прайс-лист': priceListId ?? '',
      'Ингредиент': ingredient ?? '',
      'Количество': quantity ?? '',
      'Ед.изм.': unit ?? '',
    };
  }
}
