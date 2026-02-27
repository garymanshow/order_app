// lib/models/product.dart
import '../utils/parsing_utils.dart';

class Product {
  final String id;
  final String name;
  final String? imageUrl;
  final String? imageBase64;
  final String composition;
  final String weight;
  final double price;
  final String nutrition;
  final String storage;
  final String packaging;
  final int multiplicity;
  final String categoryName;
  final String _categoryId;
  final int wastePercentage;

  Product({
    required this.id,
    required this.name,
    this.imageUrl,
    this.imageBase64,
    this.composition = '',
    this.weight = '',
    this.price = 0.0,
    this.nutrition = '',
    this.storage = '',
    this.packaging = '',
    this.multiplicity = 1,
    this.categoryName = '',
    String categoryId = '',
    this.wastePercentage = 10,
  }) : _categoryId = categoryId;

  String get categoryId => _categoryId;

  double getWasteMultiplier() {
    return 1 + (wastePercentage / 100.0);
  }

  bool get hasImageUrl => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasImageBase64 => imageBase64 != null && imageBase64!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'composition': composition,
      'weight': weight,
      'price': price,
      'nutrition': nutrition,
      'storage': storage,
      'packaging': packaging,
      'multiplicity': multiplicity,
      'categoryName': categoryName,
      'categoryId': _categoryId,
      'wastePercentage': wastePercentage,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      imageBase64: json['imageBase64']?.toString(),
      composition: json['composition']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      price: ParsingUtils.parseDouble(json['price']) ?? 0.0,
      nutrition: json['nutrition']?.toString() ?? '',
      storage: json['storage']?.toString() ?? '',
      packaging: json['packaging']?.toString() ?? '',
      multiplicity: ParsingUtils.parseInt(json['multiplicity']) ?? 1,
      categoryName: json['categoryName']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      wastePercentage: ParsingUtils.parseInt(json['wastePercentage']) ?? 10,
    );
  }

  // 🔥 ИСПРАВЛЕНО: fromMap для данных из Google Sheets (с русскими ключами)
  factory Product.fromMap(Map<String, dynamic> map) {
    print('🔄 Product.fromMap START');
    print('   - Все ключи: ${map.keys}');
    print('   - Название: ${map['Название']}');
    print('   - ID: ${map['ID']}');
    print('   - Цена: ${map['Цена']}');
    print('   - Кратность: ${map['Кратность']}');
    print('   - ID Категории прайса: ${map['ID Категории прайса']}');

    final product = Product(
      id: map['ID']?.toString() ?? '',
      name: map['Название']?.toString() ?? '',
      imageUrl: map['Фото']?.toString(),
      imageBase64: map['Фото_base64']?.toString(),
      composition: map['Состав']?.toString() ?? '',
      weight: map['Вес']?.toString() ?? '',
      price: double.tryParse(map['Цена']?.toString() ?? '0') ?? 0.0,
      nutrition: map['Пищевая ценность']?.toString() ?? '',
      storage: map['Условия хранения']?.toString() ?? '',
      packaging: map['Упаковка']?.toString() ?? '',
      multiplicity: int.tryParse(map['Кратность']?.toString() ?? '1') ?? 1,
      categoryName: '', // пока нет в таблице
      categoryId: map['ID Категории прайса']?.toString() ?? '',
      wastePercentage: 10,
    );

    print('   ✅ Создан продукт: ${product.name} - ${product.price}');
    print('🔄 Product.fromMap END');

    return product;
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'ID Категории прайса': _categoryId,
      'Название': name,
      'Цена': price.toString(),
      'Кратность': multiplicity.toString(),
      'Фото': imageUrl ?? '',
      'Описание': '', // пока нет в модели
    };
  }
}
