// lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../models/client.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/delivery_condition.dart';
import '../models/price_list_mode.dart';
import '../models/client_data.dart';
import '../services/api_service.dart';

class CartProvider with ChangeNotifier {
  final Map<String, int> _cartItems = {};
  Client? _client;
  DeliveryCondition? _deliveryCondition;
  PriceListMode _priceListMode = PriceListMode.full;

  // ЕДИНСТВЕННЫЙ источник правды
  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);
  PriceListMode get priceListMode => _priceListMode;

  // 🔥 ДОБАВЛЕН ГЕТТЕР ДЛЯ ДОСТУПА К УСЛОВИЯМ ДОСТАВКИ
  DeliveryCondition? get deliveryCondition => _deliveryCondition;

  // Получаем количество напрямую из _cartItems
  int getQuantity(String productId) => _cartItems[productId] ?? 0;

  // 🔥 НОВЫЙ МЕТОД для установки режима прайс-листа
  Future<void> setPriceListMode(PriceListMode mode) async {
    _priceListMode = mode;
    await _saveModeToSharedPreferences();
    notifyListeners();
  }

  // 🔥 НОВЫЙ МЕТОД для загрузки режима
  Future<void> loadPriceListMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('price_list_mode');
    if (modeString != null) {
      _priceListMode = PriceListModeExtension.fromString(modeString);
    }
  }

  // 🔥 НОВЫЙ МЕТОД для восстановления корзины и режима
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

  // 🔥 НОВЫЙ МЕТОД сохранения режима
  Future<void> _saveModeToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_list_mode', _priceListMode.name);
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
    _deliveryCondition = null;
    clearAll();
  }

  void clearAll() {
    _cartItems.clear();
    _clearFromSharedPreferences();
    notifyListeners();
  }

  void setClient(Client client) {
    _client = client;

    // 🔥 ИСПРАВЛЕНО: безопасное получение условий доставки
    _deliveryCondition = null;
    if (clientData != null && client.city != null) {
      final deliveryConditions = clientData!.deliveryConditions;
      _deliveryCondition = deliveryConditions
          .firstWhereOrNull((cond) => cond.location == client.city);
    }

    _cartItems.clear();
    _loadFromSharedPreferences();
    loadPriceListMode();
  }

  // 🔥 ДОБАВЛЕНО: ссылка на ClientData для получения условий доставки
  ClientData? clientData;
  void setClientData(ClientData? data) {
    clientData = data;
    if (_client != null && _client!.city != null) {
      // Обновляем условия доставки при изменении данных
      if (clientData != null) {
        final deliveryConditions = clientData!.deliveryConditions;
        _deliveryCondition = deliveryConditions
            .firstWhereOrNull((cond) => cond.location == _client!.city);
      }
    }
  }

  Future<void> _clearFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getCartKey());
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД ОТПРАВКИ ЗАКАЗА
  Future<bool> submitOrder(
      List<Product> products, ApiService apiService) async {
    // 🔒 Проверка наличия клиента
    if (_client == null || _client!.phone == null || _client!.phone!.isEmpty) {
      print('❌ Нет авторизованного клиента для оформления заказа');
      return false;
    }

    print('📤 Отправка заказа...');

    // Получаем заказы для клиента
    final orders = getOrderItemsForClient(products);

    // Проверяем минимальную сумму заказа
    final clientDiscount = (_client?.discount ?? 0.0) / 100;
    final total = getTotal(products, clientDiscount);

    if (!meetsMinimumOrderAmount(total)) {
      print(
          '❌ Заказ не соответствует минимальной сумме (${_deliveryCondition?.deliveryAmount ?? 0} ₽)');
      return false;
    }

    // 🔥 ПРАВИЛЬНЫЙ ФОРМАТ ДЛЯ СЕРВЕРА
    final items = orders.map((order) {
      return {
        'status': order.status,
        'productName': order.productName,
        'quantity': order.quantity,
        'totalPrice': order.totalPrice,
        'date': order.date,
        'clientPhone': order.clientPhone,
        'clientName': order.clientName,
        'priceListId': order.priceListId,
      };
    }).toList();

    // Отправляем заказ через ApiService.createOrder
    try {
      final result = await apiService.createOrder(
        clientId: _client!.phone!,
        employeeId: 'автомат',
        items: items,
        totalAmount: total,
        deliveryCity: _deliveryCondition?.location ?? _client!.city,
        deliveryAddress: _client!.deliveryAddress ?? '',
        comment: '',
      );

      final success = result?['success'] == true;

      if (success) {
        print('✅ Заказ отправлен успешно');
        clearAll(); // Очищаем корзину после успешной отправки
      } else {
        final message = result?['message'] ?? 'Неизвестная ошибка сервера';
        print('❌ Ошибка отправки заказа: $message');
      }

      return success;
    } catch (e) {
      print('❌ Исключение при отправке заказа: $e');
      return false;
    }
  }

  List<OrderItem> getOrderItemsForClient(List<Product> products) {
    final List<OrderItem> items = [];
    _cartItems.forEach((productId, quantity) {
      if (quantity > 0) {
        final product = products.firstWhere(
          (p) => p.id == productId,
          orElse: () => Product(id: '', name: '', price: 0, multiplicity: 1),
        );
        items.add(OrderItem(
          status: 'оформлен',
          productName: product.name,
          quantity: quantity,
          totalPrice: product.price * quantity,
          date: DateTime.now().toIso8601String().split('T')[0],
          clientPhone: _client?.phone ?? '',
          clientName: _client?.name ?? '',
          priceListId: productId,
        ));
      }
    });
    return items;
  }

  // 🔥 УПРОЩЕННЫЙ И ПРАВИЛЬНЫЙ РАСЧЕТ С ЧИСТОЙ МАРЖОЙ
  double getTotal(List<Product> products, double clientDiscount) {
    double total = 0;
    _cartItems.forEach((productId, quantity) {
      if (quantity > 0) {
        final product = products.firstWhere(
          (p) => p.id == productId,
          orElse: () => Product(id: '', name: '', price: 0, multiplicity: 1),
        );
        total += product.price * quantity;
      }
    });

    // Чистая маржа = Наценка доставки - Скидка клиента
    final deliveryMarkup = _deliveryCondition?.hiddenMarkup ?? 0.0;
    final netMarkup = deliveryMarkup - (clientDiscount * 100);

    return total * (1 + netMarkup / 100);
  }

  // 🔥 НОВЫЙ МЕТОД проверки минимальной суммы заказа
  bool meetsMinimumOrderAmount(double total) {
    final minAmount = _deliveryCondition?.deliveryAmount ?? 0.0;
    return total >= minAmount;
  }
}
