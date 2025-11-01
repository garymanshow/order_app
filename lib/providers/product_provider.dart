// lib/providers/products_provider.dart
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/google_sheets_service.dart';

class ProductsProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProducts() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await GoogleSheetsService().fetchProducts();
    } catch (e) {
      _error = 'Не удалось загрузить товары: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Безопасный поиск без firstWhere
  Product? getProductById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }
}
