// lib/utils/product_name_formatter.dart
import '../models/product.dart';
import '../models/product_category.dart';

class ProductNameFormatter {
  static String format(Product product, ProductCategory category) {
    // Если категория не указана, возвращаем название как есть
    if (category.name.isEmpty) {
      return product.name;
    }

    // Приводим к нижнему регистру для сравнения
    final productName = product.name.toLowerCase().trim();
    final categoryName = category.name.toLowerCase().trim();

    // Проверяем, содержит ли название продукта название категории
    if (productName.contains(categoryName)) {
      return product.name; // оставляем как есть
    }

    // Добавляем категорию спереди
    return '${category.name} ${product.name}';
  }

  // Для случаев, когда категория неизвестна
  static String formatWithCategoryName(
      String productName, String categoryName) {
    if (categoryName.isEmpty) return productName;

    final prodName = productName.toLowerCase().trim();
    final catName = categoryName.toLowerCase().trim();

    if (prodName.contains(catName)) {
      return productName;
    }

    return '$categoryName $productName';
  }
}
