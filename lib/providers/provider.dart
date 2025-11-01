import 'package:flutter/material.dart';
import '../models/product.dart';

class CartProvider with ChangeNotifier {
  Map<String, int> _cartItems = {}; // id продукта -> количество

  Map<String, int> get cartItems => {..._cartItems};

  void addItem(String productId, int quantity) {
    if (_cartItems.containsKey(productId)) {
      _cartItems.update(productId, (value) => value + quantity);
    } else {
      _cartItems.putIfAbsent(productId, () => quantity);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _cartItems.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  double getTotal(List<Product> products, double discount) {
    double total = 0;
    _cartItems.forEach((productId, quantity) {
      final product = products.firstWhere((p) => p.id == productId);
      total += product.price * quantity;
    });
    return total * (1 - discount); // Применяем скидку
  }
}
