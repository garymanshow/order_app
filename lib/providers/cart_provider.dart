// lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../services/google_sheets_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ← ДОБАВЬТЕ ИМПОРТ

class CartProvider with ChangeNotifier {
  late final GoogleSheetsService
      _sheetService; // ← теперь будет инициализировано
  final Map<String, int> _cartItems = {};
  Client? _client;

  // 🔥 КОНСТРУКТОР ДЛЯ ИНИЦИАЛИЗАЦИИ
  CartProvider() {
    _sheetService = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
  }

  // ЕДИНСТВЕННЫЙ источник правды
  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);

  // Получаем количество напрямую из _cartItems
  int getQuantity(String productId) => _cartItems[productId] ?? 0;

  // 🔥 НОВЫЙ ИСПРАВЛЕННЫЙ МЕТОД для восстановления корзины
  void restoreCartFromOrders(List<OrderItem> orders, List<Product> products) {
    _cartItems.clear();

    final activeOrders =
        orders.where((order) => order.status == 'оформлен').toList();

    print(
        '🛒 Активных заказов (оформлен) cart_provider : ${activeOrders.length}');

    for (var order in activeOrders) {
      if (order.priceListId.isNotEmpty) {
        // 🔥 ИСПОЛЬЗУЕМ ID НАПРЯМУЮ
        _cartItems[order.priceListId] = order.quantity;
        print('✅ Заказ по ID: ${order.priceListId} = ${order.quantity}');
      } else {
        // Fallback: поиск по имени (для старых данных без ID)
        final product = products.firstWhere(
          (p) => p.name == order.productName,
          orElse: () => Product(
            id: order.productName,
            name: order.productName,
            price: 0.0,
            multiplicity: 1,
            composition: '',
            weight: '',
            nutrition: '',
            storage: '',
            packaging: '',
            categoryName: '',
          ),
        );
        _cartItems[product.id] = order.quantity;
        print('⚠️ Fallback по имени: ${order.productName} = ${order.quantity}');
      }
    }

    _saveToSharedPreferences();
    notifyListeners();
  }

  void _saveToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCartKey();
    final json = jsonEncode(_cartItems);
    await prefs.setString(key, json);
  }

  Future<void> _loadFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCartKey();
    final json = prefs.getString(key);
    if (json != null) {
      final Map<String, dynamic> map = jsonDecode(json);
      _cartItems.clear();
      map.forEach((k, v) {
        _cartItems[k] = v as int;
      });
      notifyListeners();
    }
  }

  String _getCartKey() {
    // Проверяем сам объект
    if (_client == null) {
      print('⚠️ _client is null!');
      return 'cart_unknown_unknown';
    }

    // Безопасно получаем имя и телефон
    final name = (_client!.name ?? 'unknown').replaceAll(RegExp(r'\s+'), '_');
    final phone = _client!.phone ?? 'unknown';
    final key = 'cart_${phone}_$name';
    print('🔑 Cart key: $key');
    return key;
  }

  // Основной метод изменения количества
  Future<void> setQuantity(String productId, int quantity, int multiplicity,
      List<Product> products) async {
    print('🛒 setQuantity: productId="$productId", quantity=$quantity');
    if (quantity <= 0) {
      // Удаляем товар из корзины
      _cartItems.remove(productId);
    } else {
      if (multiplicity != 0) {
        quantity = ((quantity ~/ multiplicity) + 1) * multiplicity;
      }
      _cartItems[productId] = quantity;
    }
    _saveToSharedPreferences();
    notifyListeners();
  }

  Future<void> addItem(
      String productId, int quantity, List<Product> products) async {
    if (quantity <= 0) return;
    final currentQty = _cartItems[productId] ?? 0;
    final newQty = currentQty + quantity;
    await setQuantity(productId, newQty, 1, products); // используем общий метод
  }

  Future<void> removeItem(String productId, List<Product> products) async {
    _cartItems.remove(productId);
    _saveToSharedPreferences();
    notifyListeners();
  }

  void reset() {
    _client = null;
    clearAll();
  }

  void clearAll() {
    _cartItems.clear();
    _clearFromSharedPreferences();
    notifyListeners();
  }

  void setClient(Client client) {
    _client = client;
    _cartItems.clear(); // ← ОЧИЩАЕМ текущую корзину
    _loadFromSharedPreferences();
  }

  Future<void> _clearFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getCartKey());
  }

  Future<void> submitOrder(List<Product> products) async {
    print('📤 Отправка заказа...');

    // 🔥 ИНИЦИАЛИЗИРУЕМ СЕРВИС ПЕРЕД ИСПОЛЬЗОВАНИЕМ
    await _sheetService.init();

    String formattedPhone = _client!.phone ?? '';
    if (formattedPhone.isNotEmpty && !formattedPhone.startsWith('+')) {
      formattedPhone = '+$formattedPhone';
    }

    final now = DateTime.now();
    final formattedDate = '${now.day}.${now.month}.${now.year}';

    // 🔥 Сначала удаляем старые заказы
    await _sheetService.delete(
      sheetName: 'Заказы',
      filters: [
        {'column': 'Статус', 'value': 'оформлен'},
        {'column': 'Телефон', 'value': formattedPhone},
        {'column': 'Клиент', 'value': _client!.name ?? ''},
      ],
    );

    // Затем добавляем новые
    final items = getOrderItemsForClient(products);
    final rows = items
        .map((item) => [
              'оформлен',
              item.productName,
              item.quantity,
              item.totalPrice,
              formattedDate,
              "'$formattedPhone",
              _client!.name ?? '',
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
      final product = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product(id: '', name: '', price: 0, multiplicity: 1),
      );
      items.add(OrderItem(
        status: 'оформлен',
        productName: product.name,
        quantity: quantity,
        totalPrice: product.price * quantity,
        date: '',
        clientPhone: _client!.phone ?? '',
        clientName: _client!.name ?? '',
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
