// lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/google_sheets_service.dart'; // ← новый сервис

class CartProvider with ChangeNotifier {
  final Map<String, int> _cartItems = {};
  final Map<String, int> _temporaryQuantities = {};

  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);
  int getTemporaryQuantity(String productId) =>
      _temporaryQuantities[productId] ?? 0;

  late GoogleSheetsService _sheetService;
  Client? _client;

  void initialize(GoogleSheetsService service, Client client) {
    _sheetService = service;
    _client = client;
    _loadFromSharedPreferences();
  }

  // Сохраняет корзину в shared_preferences
  void _saveToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCartKey();
    final json = jsonEncode(_cartItems);
    await prefs.setString(key, json);
  }

  // Загружает корзину из shared_preferences
  void _loadFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCartKey();
    final json = prefs.getString(key);
    if (json != null) {
      final Map<String, dynamic> map = jsonDecode(json);
      _cartItems.clear();
      _temporaryQuantities.clear();
      map.forEach((k, v) {
        _cartItems[k] = v as int;
        _temporaryQuantities[k] = v as int;
      });
      notifyListeners();
    }
  }

  String _getCartKey() {
    if (_client == null) {
      throw Exception('CartProvider не инициализирован');
    }
    // Уникальный ключ: телефон + имя (нормализованное)
    final normalizedClientName = _client!.name.replaceAll(RegExp(r'\s+'), '_');
    return 'cart_${_client!.phone}_$normalizedClientName';
  }

  void setTemporaryQuantity(String productId, int quantity) {
    if (quantity < 0) quantity = 0;
    _temporaryQuantities[productId] = quantity;

    // Синхронизируем с основной корзиной и сохраняем
    _cartItems[productId] = quantity;
    _saveToSharedPreferences(); // ← добавлено!

    notifyListeners();
  }

  Future<void> addItem(
      String productId, int quantity, List<Product> products) async {
    if (quantity <= 0) return;
    final currentQty = _cartItems[productId] ?? 0;
    final newQty = currentQty + quantity;
    _cartItems[productId] = newQty;
    _temporaryQuantities[productId] = newQty;
    _saveToSharedPreferences(); // ← сохраняем локально
    notifyListeners();
  }

  Future<void> setQuantity(String productId, int quantity, int multiplicity,
      List<Product> products) async {
    if (quantity < 0) quantity = 0;
    if (quantity > 0 && quantity % multiplicity != 0) {
      quantity = ((quantity ~/ multiplicity) + 1) * multiplicity;
    }
    _cartItems[productId] = quantity;
    _temporaryQuantities[productId] = quantity; // ← убедитесь, что есть
    _saveToSharedPreferences();
    notifyListeners();
  }

  Future<void> removeItem(String productId, List<Product> products) async {
    _cartItems.remove(productId);
    _temporaryQuantities.remove(productId);
    _saveToSharedPreferences(); // ← сохраняем локально
    notifyListeners();
  }

  void reset() {
    _client = null;
    clearAll(); // теперь безопасно
  }

  void clearAll() {
    _cartItems.clear();
    _temporaryQuantities.clear();
    _clearFromSharedPreferences();
    notifyListeners();
  }

  Future<void> _clearFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getCartKey());
  }

  // Отправка заказа в Google Таблицу
  Future<void> submitOrder(List<Product> products) async {
    print('📤 Отправка заказа...');

    // Убедимся, что телефон начинается с '+'
    String formattedPhone = _client!.phone;
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+$formattedPhone';
    }

    final now = DateTime.now();
    final formattedDate = '${now.day}.${now.month}.${now.year}';

    final items = getOrderItemsForClient(products);
    final rows = items
        .map((item) => [
              'оформлен',
              item.productName,
              item.quantity,
              item.totalPrice,
              formattedDate,
              formattedPhone, // ← всегда с '+'
              _client!.name,
              0,
            ])
        .toList();

    try {
      await _sheetService.create(sheetName: 'Заказы', records: rows);
      print('✅ Заказ отправлен успешно');
      clearAll();
    } catch (e) {
      print('❌ Ошибка отправки заказа: $e');
      rethrow;
    }
  }

  List<OrderItem> getOrderItemsForClient(List<Product> products) {
    final List<OrderItem> items = [];
    _cartItems.forEach((productId, quantity) {
      final product = products.firstWhere((p) => p.id == productId);
      items.add(OrderItem(
        status: 'оформлен', // ← теперь всегда "оформлен"
        productName: product.name,
        quantity: quantity,
        totalPrice: product.price * quantity,
        date: '',
        clientPhone: _client!.phone,
        clientName: _client!.name,
      ));
    });
    return items;
  }

  double getTotal(List<Product> products, double discount) {
    double total = 0;
    _cartItems.forEach((productId, quantity) {
      final product = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product(id: '', name: '', price: 0, multiplicity: 1),
      );
      total += product.price * quantity;
    });
    return total * (1 - discount);
  }
}
