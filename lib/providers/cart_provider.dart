// lib/providers/cart_provider.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/user.dart';

class CartProvider with ChangeNotifier {
  final Map<String, int> _cartItems = {};
  final Map<String, int> _temporaryQuantities = {};

  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);
  int getTemporaryQuantity(String productId) =>
      _temporaryQuantities[productId] ?? 0;

  void setTemporaryQuantity(String productId, int quantity) {
    if (quantity < 0) quantity = 0;
    _temporaryQuantities[productId] = quantity;
    notifyListeners();
  }

  void addItem(String productId, int quantity) {
    if (quantity <= 0) return;
    _cartItems.update(productId, (v) => v + quantity, ifAbsent: () => quantity);
    _temporaryQuantities[productId] = _cartItems[productId]!;
    notifyListeners();
  }

  void removeItem(String productId) {
    _cartItems.remove(productId);
    notifyListeners();
  }

  void clearAll() {
    _cartItems.clear();
    _temporaryQuantities.clear();
    notifyListeners();
  }

  void loadFromOrders(List<OrderItem> orders) {
    _cartItems.clear();
    _temporaryQuantities.clear();
    for (var order in orders) {
      // Ищем productId по имени товара (нужен ProductsProvider)
      // Но для упрощения — пока храним имя как ID
      _cartItems[order.productName] = order.quantity;
      _temporaryQuantities[order.productName] = order.quantity;
    }
    notifyListeners();
  }

  // Новый метод: загрузка корзины из OrderItem
  void loadFromOrderItems(List<OrderItem> orders, List<Product> products) {
    _cartItems.clear();
    _temporaryQuantities.clear();

    for (var order in orders) {
      final product =
          products.firstWhereOrNull((p) => p.name == order.productName);
      if (product != null) {
        _cartItems[product.id] = order.quantity;
        _temporaryQuantities[product.id] = order.quantity;
      }
    }
    notifyListeners();
  }

  // Новый метод: получение OrderItem для отправки
  List<OrderItem> getOrderItemsForClient(
      Client client, List<Product> products) {
    final List<OrderItem> items = [];
    _cartItems.forEach((productId, quantity) {
      final product = products.firstWhere((p) => p.id == productId);
      items.add(OrderItem(
        status: 'заказ',
        productName: product.name,
        quantity: quantity,
        totalPrice: product.price * quantity,
        date: '', // будет установлен при отправке
        clientPhone: client.phone,
        clientName: client.name, // или client.address
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
