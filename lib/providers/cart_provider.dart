// lib/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/sheet_all_api_service.dart';

class CartProvider with ChangeNotifier {
  // Хранит актуальное количество товаров в корзине
  final Map<String, int> _cartItems = {};
  // Хранит временное количество (для UI)
  final Map<String, int> _temporaryQuantities = {};

  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);
  int getTemporaryQuantity(String productId) =>
      _temporaryQuantities[productId] ?? 0;

  void setTemporaryQuantity(String productId, int quantity) {
    if (quantity < 0) quantity = 0;
    _temporaryQuantities[productId] = quantity;
    notifyListeners();
  }

  late SheetAllApiService _sheetService;
  late Client _client;

  void initialize(SheetAllApiService service, Client client) {
    _sheetService = service;
    _client = client;
  }

  // Загрузка заказов клиента в корзину при инициализации
  Future<void> loadFromOrders(List<Product> products) async {
    final orders = await _sheetService.read(sheetName: 'Заказы', filters: [
      {'column': 'Телефон', 'value': _client.phone},
      {'column': 'Клиент', 'value': _client.name},
      {'column': 'Статус', 'value': 'заказ'}
    ]);

    _cartItems.clear();
    _temporaryQuantities.clear();

    for (var order in orders) {
      final product = products.firstWhere(
        (p) => p.name == (order as Map)['Название'],
        orElse: () => Product(
            id: '', name: 'Товар недоступен', price: 0, multiplicity: 1),
      );
      if (product != null) {
        final quantity = (order['Количество'] as int?) ?? 0;
        _cartItems[product.id] = quantity;
        _temporaryQuantities[product.id] = quantity;
      }
    }

    //notifyListeners();
  }

  Future<void> addItem(
      String productId, int quantity, List<Product> products) async {
    if (quantity <= 0) return;

    final currentQty = _cartItems[productId] ?? 0;
    final newQty = currentQty + quantity;
    _cartItems[productId] = newQty;
    _temporaryQuantities[productId] = newQty;

    final product = products.firstWhere((p) => p.id == productId);
    await _saveToSheet(product, newQty);

    notifyListeners();
  }

  Future<void> setQuantity(String productId, int quantity, int multiplicity,
      List<Product> products) async {
    if (quantity < 0) quantity = 0;
    if (quantity > 0 && quantity % multiplicity != 0) {
      quantity = ((quantity ~/ multiplicity) + 1) * multiplicity;
    }

    _cartItems[productId] = quantity;
    _temporaryQuantities[productId] = quantity;

    final product = products.firstWhere((p) => p.id == productId);
    if (quantity == 0) {
      await _deleteFromSheet(product);
    } else {
      await _saveToSheet(product, quantity);
    }

    notifyListeners();
  }

  Future<void> removeItem(String productId, List<Product> products) async {
    final product = products.firstWhere((p) => p.id == productId);
    await _deleteFromSheet(product);

    _cartItems.remove(productId);
    _temporaryQuantities.remove(productId);
    notifyListeners();
  }

  Future<void> _saveToSheet(Product product, int quantity) async {
    await _sheetService.delete(sheetName: 'Заказы', filters: [
      {'column': 'Телефон', 'value': _client.phone},
      {'column': 'Название', 'value': product.name},
      {'column': 'Клиент', 'value': _client.name},
      {'column': 'Статус', 'value': 'заказ'}
    ]);

    if (quantity > 0) {
      await _sheetService.create(
        sheetName: 'Заказы',
        data: [
          [
            'заказ',
            product.name,
            quantity,
            product.price * quantity,
            '',
            _client.phone,
            _client.name,
          ]
        ],
      );
    }
  }

  Future<void> _deleteFromSheet(Product product) async {
    await _sheetService.delete(sheetName: 'Заказы', filters: [
      {'column': 'Телефон', 'value': _client.phone},
      {'column': 'Название', 'value': product.name},
      {'column': 'Клиент', 'value': _client.name},
      {'column': 'Статус', 'value': 'заказ'}
    ]);
  }

  void clearAll() {
    _cartItems.clear();
    _temporaryQuantities.clear();
    notifyListeners();
  }

  List<OrderItem> getOrderItemsForClient(List<Product> products) {
    final List<OrderItem> items = [];
    _cartItems.forEach((productId, quantity) {
      final product = products.firstWhere((p) => p.id == productId);
      items.add(OrderItem(
        status: 'заказ',
        productName: product.name,
        quantity: quantity,
        totalPrice: product.price * quantity,
        date: '',
        clientPhone: _client.phone,
        clientName: _client.name,
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
