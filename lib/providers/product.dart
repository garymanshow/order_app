class Product {
  final String id;
  final String name;
  final String imageUrl;
  final double price;
  final int multiplicity; // Кратность выбора

  Product({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.multiplicity,
  });
}
