// lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/delivery_condition.dart'; // ← ДОБАВЛЕН ИМПОРТ

class CartProvider with ChangeNotifier {
  final Map<String, int> _cartItems = {};
  Client? _client;
  DeliveryCondition? _deliveryCondition; // ← ДОБАВЛЕНО

  // ЕДИНСТВЕННЫЙ источник правды
  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);

  // Получаем количество напрямую из _cartItems
  int getQuantity(String productId) => _cartItems[productId] ?? 0;

  // 🔥 НОВЫЙ МЕТОД для установки условий доставки
  void setDeliveryCondition(DeliveryCondition? condition) {
    _deliveryCondition = condition;
    notifyListeners();
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД для восстановления корзины
  void restoreCartFromOrders(List<OrderItem> orders, List<Product> products) {
    _cartItems.clear();

    final activeOrders =
        orders.where((order) => order.status == 'оформлен').toList();

    print(
        '🛒 Активных заказов (оформлен) cart_provider : ${activeOrders.length}');

    for (var order in activeOrders) {
      if (order.priceListId.isNotEmpty) {
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
    if (_client == null) {
      print('⚠️ _client is null!');
      return 'cart_unknown_unknown';
    }

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
    await setQuantity(productId, newQty, 1, products);
  }

  Future<void> removeItem(String productId, List<Product> products) async {
    _cartItems.remove(productId);
    _saveToSharedPreferences();
    notifyListeners();
  }

  void reset() {
    _client = null;
    _deliveryCondition = null; // ← ОЧИЩАЕМ
    clearAll();
  }

  void clearAll() {
    _cartItems.clear();
    _clearFromSharedPreferences();
    notifyListeners();
  }

  void setClient(Client client) {
    _client = client;
    _cartItems.clear();
    _loadFromSharedPreferences();
  }

  Future<void> _clearFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getCartKey());
  }

  // 🔥 УДАЛЕН МЕТОД submitOrder - он должен быть в ApiService
  // Все операции с данными идут через Apps Script!

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
        priceListId: productId,
      ));
    });
    return items;
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД getTotal с поддержкой наценки
  double getTotal(List<Product> products, double discount) {
    double total = 0;
    _cartItems.forEach((productId, quantity) {
      final product = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product(id: '', name: '', price: 0, multiplicity: 1),
      );
      total += product.price * quantity;
    });

    // Применяем скидку клиента
    total = total * (1 - discount);

    // Применяем скрытую наценку за доставку
    if (_deliveryCondition?.hiddenMarkup != null) {
      total = total * (1 + _deliveryCondition!.hiddenMarkup! / 100);
    }

    return total;
  }
}
