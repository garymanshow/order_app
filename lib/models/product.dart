// lib/models/product.dart
class Product {
  final String id;
  final String name;
  final String? imageUrl; // ← nullable
  final String? imageBase64; // ← nullable
  final String composition;
  final String weight;
  final double price;
  final String nutrition;
  final String storage;
  final String packaging;
  final int multiplicity;
  final String categoryName;

  Product({
    required this.id,
    required this.name,
    this.imageUrl, // ← НЕ required!
    this.imageBase64,
    this.composition = '',
    this.weight = '',
    this.price = 0.0,
    this.nutrition = '',
    this.storage = '',
    this.packaging = '',
    this.multiplicity = 1,
    this.categoryName = '',
  });

  // Геттеры для удобства
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
    };
  }

  // Конструктор fromJson (для восстановления из кэша)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
      imageBase64: json['imageBase64'] as String?,
      composition: json['composition'] as String? ?? '',
      weight: json['weight'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      nutrition: json['nutrition'] as String? ?? '',
      storage: json['storage'] as String? ?? '',
      packaging: json['packaging'] as String? ?? '',
      multiplicity: json['multiplicity'] as int? ?? 1,
      categoryName: json['categoryName'] as String? ?? '',
    );
  }

  // 🔥 КОНСТРУКТОР fromMap для Google Таблиц
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
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
      categoryName: map['Категория']?.toString() ?? '',
    );
  }
}
