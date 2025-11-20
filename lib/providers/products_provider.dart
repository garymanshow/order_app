// lib/providers/products_provider.dart
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import '../models/product.dart';
import '../services/google_sheets_service.dart';

class ProductsProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Загружает товары, если они ещё не загружены
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

  // Возвращает Future<List<Product>> — для использования в FutureBuilder
  Future<List<Product>> loadProductsFuture() async {
    if (_products.isEmpty && !_isLoading) {
      await loadProducts();
    }
    return _products;
  }

  // Безопасный поиск товара по ID
  Product? getProductById(String id) {
    return _products.firstWhereOrNull((p) => p.id == id);
  }
}
