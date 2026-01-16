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
      'price': price,
      'multiplicity': multiplicity,
    };
  }

  // конструктор fromJson (для восстановления из кэша)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      price: (json['price'] as num).toDouble(),
      multiplicity: json['multiplicity'] as int,
    );
  }
}
