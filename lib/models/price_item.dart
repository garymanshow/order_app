// lib/models/price_item.dart
import 'ingredient_info.dart';
import '../utils/parsing_utils.dart';

class PriceItem {
  final String id;
  final String name;
  final double price;
  final String category; // Хранится локально для отображения
  final String categoryId; // ID Категории прайса (ключ связи)
  final String unit; // Берется из Категории
  final double weight; // Берется из Категории
  final List<IngredientInfo> ingredients;
  final Map<String, dynamic> nutrition;
  final String? photoUrl;
  final int multiplicity;
  final String? description;

  PriceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.categoryId,
    required this.unit,
    this.weight = 0.0,
    this.ingredients = const [],
    this.nutrition = const {},
    this.photoUrl,
    this.multiplicity = 1,
    this.description,
  });

  // 🔥 JSON (для локального кэша Hive/SharedPrefs)
  factory PriceItem.fromJson(Map<String, dynamic> json) {
    final ingredientsList = json['ingredients'] as List?;
    final ingredients = ingredientsList
            ?.map((i) => IngredientInfo.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];

    return PriceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: ParsingUtils.parseDouble(json['price']) ?? 0.0,
      category: json['category']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'шт',
      weight: ParsingUtils.parseDouble(json['weight']) ?? 0.0,
      ingredients: ingredients,
      nutrition: json['nutrition'] as Map<String, dynamic>? ?? {},
      photoUrl: json['photoUrl']?.toString(),
      multiplicity: ParsingUtils.parseInt(json['multiplicity']) ?? 1,
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'categoryId': categoryId,
      'unit': unit,
      'weight': weight,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'nutrition': nutrition,
      'photoUrl': photoUrl,
      'multiplicity': multiplicity,
      'description': description,
    };
  }

  // 🔥 GOOGLE SHEETS MAP (Строго по колонкам листа)
  // Колонки: ID, ID Категории прайса, Название, Цена, Кратность, Фото, Описание
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'ID Категории прайса': categoryId, // 👈 Сохраняем связь
      'Название': name,
      'Цена': price.toString(),
      'Кратность': multiplicity.toString(),
      'Фото': photoUrl ?? '',
      'Описание': description ?? '',
      // 'Категория', 'Ед.изм.', 'Вес' - НЕ отправляем, их нет в листе
    };
  }

  // 👇 ЧТЕНИЕ ИЗ ЛИСТА GOOGLE SHEETS
  factory PriceItem.fromMap(Map<String, dynamic> map) {
    return PriceItem(
      id: map['ID']?.toString() ?? '',
      name: map['Название']?.toString() ?? '',
      price: double.tryParse(map['Цена']?.toString() ?? '0') ?? 0.0,
      // Категория (имя) - в листе её нет, подтянется позже по ID
      category: '',
      categoryId: map['ID Категории прайса']?.toString().trim() ?? '',
      unit:
          map['Ед.изм.']?.toString() ?? 'шт', // На случай, если всё же появится
      weight: double.tryParse(map['Вес']?.toString() ?? '0') ?? 0.0,
      photoUrl: map['Фото']?.toString().isNotEmpty == true
          ? map['Фото']?.toString()
          : null,
      multiplicity: int.tryParse(map['Кратность']?.toString() ?? '1') ?? 1,
      description: map['Описание']?.toString().isNotEmpty == true
          ? map['Описание']?.toString()
          : null,
    );
  }
}
