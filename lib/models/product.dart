// lib/models/product.dart
class Product {
  final String id;
  final String name;
  final String? imageUrl;
  final String? imageBase64;
  final double price;
  final int multiplicity;

  Product({
    required this.id,
    required this.name,
    this.imageUrl,
    this.imageBase64,
    required this.price,
    required this.multiplicity,
  });

  bool get hasImageUrl => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasImageBase64 => imageBase64 != null && imageBase64!.isNotEmpty;
}
