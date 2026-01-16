// lib/providers/products_provider.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/product.dart';
import '../services/google_sheets_service.dart';

class ProductsProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Загружает прайс-лист с учётом кэша
  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
      await service.init();

      // 1. Получаем дату последнего обновления на сервере
      final serverTime = await service.getLastPriceUpdateTime();

      // 2. Получаем дату сохранения кэша
      final cacheTimeStr = prefs.getString('price_list_timestamp');
      final cacheTime = cacheTimeStr != null
          ? DateTime.tryParse(cacheTimeStr) ?? DateTime(1970)
          : DateTime(1970);

      // 3. Решаем, что делать
      if (serverTime.isAfter(cacheTime)) {
        // Сервер новее — загружаем свежие данные
        await _loadFromNetwork(service, prefs);
      } else {
        // Кэш актуален — используем его
        await _loadFromCache(prefs);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    print('✅ Загружено товаров: ${_products.length}');
  }

  Future<void> _loadFromNetwork(
      GoogleSheetsService service, SharedPreferences prefs) async {
    final rawData = await service.read(sheetName: 'Прайс-лист');
    _products = rawData.map((row) {
      return Product(
        id: row['Название']?.toString() ?? '',
        name: row['Название']?.toString() ?? '',
        price: double.tryParse(row['Цена']?.toString() ?? '0') ?? 0.0,
        multiplicity: int.tryParse(row['Кратность']?.toString() ?? '1') ?? 1,
      );
    }).toList();

    // Сохраняем в кэш
    final json = jsonEncode(_products.map((p) => p.toJson()).toList());
    await prefs.setString('price_list_cache', json);
    await prefs.setString(
        'price_list_timestamp', DateTime.now().toIso8601String());
  }

  Future<void> _loadFromCache(SharedPreferences prefs) async {
    final json = prefs.getString('price_list_cache');
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _products = list.map((item) {
        final map = item as Map<String, dynamic>;
        return Product(
          id: map['id'],
          name: map['name'],
          price: map['price'],
          multiplicity: map['multiplicity'],
        );
      }).toList();
    } else {
      // Если кэш пуст — загружаем с сети
      final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
      await service.init();
      await _loadFromNetwork(service, prefs);
    }
  }
}
