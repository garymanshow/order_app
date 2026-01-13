// lib/providers/products_provider.dart
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/sheet_all_api_service.dart';

class ProductsProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProducts() async {
    print('🔄 ProductsProvider.loadProducts() вызван');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📋 Создаем SheetAllApiService...');
      final service = SheetAllApiService();
      print('📋 Запрашиваем прайс-лист из Google Sheets...');
      final rawData = await service.read(sheetName: 'Прайс-лист');
      print('✅ Получено ${rawData.length} записей прайса');
      _products = rawData.map((item) {
        final row = item as Map<String, dynamic>;
        final name = row['Название']?.toString() ?? '';
        final price = double.tryParse(row['Цена']?.toString() ?? '0') ?? 0.0;
        print('📦 Товар: "$name", Цена: $price');
        return Product(
          id: name,
          name: name,
          price: price,
          multiplicity: int.tryParse(row['Кратность']?.toString() ?? '1') ?? 1,
        );
      }).toList();
      print('✅ Прайс загружен: ${_products.length} товаров');
    } catch (e, stackTrace) {
      print('❌ Ошибка загрузки прайса: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🔄 ProductsProvider загрузка завершена');
    }
  }
}
