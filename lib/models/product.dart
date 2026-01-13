// lib/models/product.dart
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
  });

  bool get hasImageUrl => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasImageBase64 => imageBase64 != null && imageBase64!.isNotEmpty;
}
