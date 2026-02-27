// lib/models/product.dart
import '../utils/parsing_utils.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final int multiplicity;
  final String categoryId;
  final String? imageUrl;
  final String? imageBase64;

  // Добавляем поле для отформатированного названия
  final String displayName;

  // Дополнительные поля
  final String composition;
  final String weight;
  final String nutrition;
  final String storage;
  final String packaging;
  final String categoryName;
  final int wastePercentage;

  // 🔥 ИСПРАВЛЕНО: добавляем displayName в конструктор
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.multiplicity,
    required this.categoryId,
    this.imageUrl,
    this.imageBase64,
    this.composition = '',
    this.weight = '',
    this.nutrition = '',
    this.storage = '',
    this.packaging = '',
    this.categoryName = '',
    this.wastePercentage = 10,
    String? displayName, // ← добавляем опциональный параметр
  }) : displayName = displayName ?? name; // ← если не передан, используем name

  // Геттер для пути к изображению
  String get assetPath => 'assets/images/products/$id.webp';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'price': price,
      'multiplicity': multiplicity,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'composition': composition,
      'weight': weight,
      'nutrition': nutrition,
      'storage': storage,
      'packaging': packaging,
      'categoryName': categoryName,
      'wastePercentage': wastePercentage,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: ParsingUtils.parseDouble(json['price']) ?? 0.0,
      multiplicity: ParsingUtils.parseInt(json['multiplicity']) ?? 1,
      categoryId: json['categoryId']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      imageBase64: json['imageBase64']?.toString(),
      composition: json['composition']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      nutrition: json['nutrition']?.toString() ?? '',
      storage: json['storage']?.toString() ?? '',
      packaging: json['packaging']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      wastePercentage: ParsingUtils.parseInt(json['wastePercentage']) ?? 10,
      displayName:
          json['displayName']?.toString(), // ← восстанавливаем displayName
    );
  }

  // 🔥 ИСПРАВЛЕНО: fromMap с форматированием названия
  factory Product.fromMap(Map<String, dynamic> map) {
    final id = map['ID']?.toString() ?? '';
    final name = map['Название']?.toString() ?? '';
    final categoryId = map['ID Категории прайса']?.toString() ?? '';
    final categoryName = map['Категория']?.toString() ?? '';

    // Форматируем название
    final displayName = _formatProductName(name, categoryName);

    return Product(
      id: id,
      name: name,
      price: double.tryParse(map['Цена']?.toString() ?? '0') ?? 0.0,
      multiplicity: int.tryParse(map['Кратность']?.toString() ?? '1') ?? 1,
      categoryId: categoryId,
      imageUrl: map['Фото']?.toString(),
      imageBase64: map['Фото_base64']?.toString(),
      composition: map['Состав']?.toString() ?? '',
      weight: map['Вес']?.toString() ?? '',
      nutrition: map['Пищевая ценность']?.toString() ?? '',
      storage: map['Условия хранения']?.toString() ?? '',
      packaging: map['Упаковка']?.toString() ?? '',
      categoryName: categoryName,
      wastePercentage: _parseWastePercentage(map['Издержки']?.toString()),
      displayName: displayName, // ← передаем отформатированное
    );
  }

  // 🔥 Функция форматирования названия
  static String _formatProductName(String productName, String categoryName) {
    if (categoryName.isEmpty) return productName;

    final prodName = productName.toLowerCase().trim();
    final catName = categoryName.toLowerCase().trim();

    // Если название уже содержит категорию - оставляем как есть
    if (prodName.contains(catName)) {
      return productName;
    }

    // Иначе добавляем категорию спереди
    return '$categoryName $productName';
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Название': name,
      'Цена': price.toString(),
      'Кратность': multiplicity.toString(),
      'ID Категории прайса': categoryId,
      'Фото': imageUrl ?? '',
      'Фото_base64': imageBase64 ?? '',
      'Состав': composition,
      'Вес': weight,
      'Пищевая ценность': nutrition,
      'Условия хранения': storage,
      'Упаковка': packaging,
      'Категория': categoryName,
      'Издержки': wastePercentage.toString(),
    };
  }

  static int _parseWastePercentage(String? value) {
    if (value == null || value.isEmpty) return 10;
    final parsed = int.tryParse(value);
    return parsed ?? 10;
  }
}
