// lib/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../models/product.dart';

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
