// lib/models/price_item.dart
import 'ingredient_info.dart';
import '../utils/parsing_utils.dart';

class PriceItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final String unit;
  final double weight;
  final List<IngredientInfo> ingredients;
  final Map<String, dynamic> nutrition;
  final String? photoUrl; // ← ДОБАВЛЕНО
  final int multiplicity; // ← ДОБАВЛЕНО
  final String? description;

  PriceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.unit,
    this.weight = 0.0,
    this.ingredients = const [],
    this.nutrition = const {},
    this.photoUrl, // ← ДОБАВЛЕНО
    this.multiplicity = 1, // ← ДОБАВЛЕНО (по умолчанию 1)
    this.description,
  });

  factory PriceItem.fromJson(Map<String, dynamic> json) {
    final ingredientsList = json['ingredients'] as List?;
    final ingredients = ingredientsList
            ?.map((i) => IngredientInfo.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];

    return PriceItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: ParsingUtils.parseDouble(json['price']) ?? 0.0,
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? 'шт',
      weight: ParsingUtils.parseDouble(json['weight']) ?? 0.0,
      ingredients: ingredients,
      nutrition: json['nutrition'] as Map<String, dynamic>? ?? {},
      photoUrl: json['photoUrl'] as String?,
      multiplicity: ParsingUtils.parseInt(json['multiplicity']) ?? 1,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'unit': unit,
      'weight': weight,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'nutrition': nutrition,
      'photoUrl': photoUrl,
      'multiplicity': multiplicity,
      'description': description,
    };
  }

  // Для Google Таблиц (если нужно)
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Наименование': name,
      'Цена': price.toString(),
      'Категория': category,
      'Ед.изм.': unit,
      'Вес': weight.toString(),
      'Фото URL': photoUrl ?? '',
      'Кратность': multiplicity.toString(),
      'Описание': description.toString(),
    };
  }

  factory PriceItem.fromMap(Map<String, dynamic> map) {
    return PriceItem(
      id: map['ID']?.toString() ?? '',
      name: map['Наименование']?.toString() ?? '',
      price: double.tryParse(map['Цена']?.toString() ?? '0') ?? 0.0,
      category: map['Категория']?.toString() ?? '',
      unit: map['Ед.изм.']?.toString() ?? 'шт',
      weight: double.tryParse(map['Вес']?.toString() ?? '0') ?? 0.0,
      photoUrl: map['Фото URL']?.toString().isNotEmpty == true
          ? map['Фото URL']?.toString()
          : null, // ← ДОБАВЛЕНО
      multiplicity:
          int.tryParse(map['Кратность']?.toString() ?? '1') ?? 1, // ← ДОБАВЛЕНО
      description: map['Описание']?.toString().isNotEmpty == true
          ? map['Описание']?.toString()
          : null, // ← ДОБАВЬТЕ СЮДА
    );
  }
}
