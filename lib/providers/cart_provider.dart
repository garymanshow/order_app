// lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../models/client.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/delivery_condition.dart';
import '../models/price_list_mode.dart';
import '../services/api_service.dart';
import '../services/delivery_conditions_service.dart' as delivery;

class CartProvider with ChangeNotifier {
  Client? _currentClient;
  List<OrderItem>? _allOrders; // Ссылка на все заказы из AuthProvider
  List<Product>? _allProducts;
  DeliveryCondition? _deliveryCondition;
  PriceListMode _priceListMode = PriceListMode.full;

  // Геттеры
  PriceListMode get priceListMode => _priceListMode;
  DeliveryCondition? get deliveryCondition => _deliveryCondition;

  // 🔥 Корзина - это просто заказы текущего клиента с quantity > 0
  List<OrderItem> get cartItems {
    if (_currentClient == null || _allOrders == null) return [];

    return _allOrders!
        .where((order) =>
            order.clientPhone == _currentClient!.phone &&
            order.clientName == _currentClient!.name &&
            order.quantity > 0)
        .toList();
  }

  // Получаем количество для конкретного товара
  int getQuantity(String productId) {
    if (_currentClient == null || _allOrders == null) return 0;

    final order = _allOrders!.firstWhereOrNull((o) =>
        o.clientPhone == _currentClient!.phone &&
        o.clientName == _currentClient!.name &&
        o.priceListId == productId);

    return order?.quantity ?? 0;
  }

  // 🔥 Установка количества - напрямую в заказ
  Future<void> setQuantity(
      String productId, int quantity, int multiplicity) async {
    if (_currentClient == null || _allOrders == null || _allProducts == null)
      return;

    print('🛒 setQuantity: productId=$productId, quantity=$quantity');

    // Ищем индекс существующего заказа
    final existingIndex = _allOrders!.indexWhere((o) =>
        o.clientPhone == _currentClient!.phone &&
        o.clientName == _currentClient!.name &&
        o.priceListId == productId);

    if (quantity <= 0) {
      // Если количество 0 или меньше, удаляем заказ
      if (existingIndex != -1) {
        _allOrders!.removeAt(existingIndex);
        print('   🗑️ Заказ удален');
      }
    } else {
      // Корректируем с учетом кратности
      final adjustedQuantity =
          ((quantity / multiplicity).round() * multiplicity).clamp(0, 999);
      final product = _allProducts!.firstWhere((p) => p.id == productId);

      if (existingIndex != -1) {
        // Обновляем существующий заказ (создаем новый с измененным quantity)
        final oldOrder = _allOrders![existingIndex];
        final updatedOrder = OrderItem(
          status: oldOrder.status,
          productName: oldOrder.productName,
          quantity: adjustedQuantity,
          totalPrice: product.price * adjustedQuantity,
          date: oldOrder.date,
          clientPhone: oldOrder.clientPhone,
          clientName: oldOrder.clientName,
          paymentAmount: oldOrder.paymentAmount,
          paymentDocument: oldOrder.paymentDocument,
          notificationSent: oldOrder.notificationSent,
          priceListId: oldOrder.priceListId,
        );
        _allOrders![existingIndex] = updatedOrder;
        print('   🔄 Заказ обновлен: quantity=$adjustedQuantity');
      } else {
        // Создаем новый заказ
        final newOrder = OrderItem(
          status: 'оформлен',
          productName: product.name,
          quantity: adjustedQuantity,
          totalPrice: product.price * adjustedQuantity,
          date: DateTime.now().toIso8601String(),
          clientPhone: _currentClient!.phone!,
          clientName: _currentClient!.name!,
          priceListId: productId,
        );
        _allOrders!.add(newOrder);
        print('   ✅ Новый заказ создан');
      }
    }

    // Сохраняем изменения локально
    await _saveOrdersToPreferences();
    notifyListeners();
  }

  // Установка режима прайс-листа
  Future<void> setPriceListMode(PriceListMode mode) async {
    _priceListMode = mode;
    await _saveModeToSharedPreferences();
    notifyListeners();
  }

  // Загрузка режима прайс-листа
  Future<void> loadPriceListMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('price_list_mode');
    if (modeString != null) {
      _priceListMode = PriceListModeExtension.fromString(modeString);
    }
  }

  // Установка клиента и данных
  void setClient(
      Client client, List<OrderItem>? allOrders, List<Product>? allProducts) {
    _currentClient = client;
    _allOrders = allOrders;
    _allProducts = allProducts;

    // Обновляем условия доставки
    _updateDeliveryCondition();

    notifyListeners();
  }

  // Обновление ссылок на данные
  void updateData(List<OrderItem>? allOrders, List<Product>? allProducts) {
    _allOrders = allOrders;
    _allProducts = allProducts;
    _updateDeliveryCondition();
    notifyListeners();
  }

  // 🔥 Обновление условий доставки
  void _updateDeliveryCondition() {
    _deliveryCondition = null;
  }

  // 🔥 Получение условий доставки с контекстом (используем getConditionForLocation)
  DeliveryCondition? getDeliveryCondition(BuildContext context) {
    if (_currentClient == null || _currentClient!.city == null) return null;

    final deliveryService = delivery.DeliveryConditionsService();
    return deliveryService.getConditionForLocation(
        _currentClient!.city!, context);
  }

  // 🔥 Получение минимальной суммы заказа для города клиента (используем getMinOrderAmount)
  double getMinOrderAmount(BuildContext context) {
    if (_currentClient == null || _currentClient!.city == null) return 0.0;

    final deliveryService = delivery.DeliveryConditionsService();
    return deliveryService.getMinOrderAmount(_currentClient!.city!, context);
  }

  // 🔥 Получение наценки для клиента (используем getMarkupForCity)
  double getMarkupForClient(BuildContext context) {
    if (_currentClient == null || _currentClient!.city == null) return 0.0;

    final deliveryService = delivery.DeliveryConditionsService();
    return deliveryService.getMarkupForCity(_currentClient!.city!, context);
  }

  // 🔥 Получение скидки клиента
  double getClientDiscount() {
    return _currentClient?.discount ?? 0.0;
  }

  // 🔥 Расчет итоговой цены товара с учетом наценки и скидки
  double calculateFinalPrice(double basePrice, BuildContext context) {
    final markup = getMarkupForClient(context);
    final discount = getClientDiscount();
    return basePrice * (1 + (markup - discount) / 100);
  }

  // 🔥 Проверка минимальной суммы заказа
  bool meetsMinimumOrderAmount(BuildContext context) {
    final cartTotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final minAmount = getMinOrderAmount(context);
    return cartTotal >= minAmount;
  }

  // 🔥 Отправка всех заказов
  Future<bool> submitAllOrders(
    BuildContext context,
    ApiService apiService,
  ) async {
    if (_allOrders == null || _allOrders!.isEmpty) return false;

    try {
      // Получаем город и адрес текущего клиента
      final deliveryCity = _currentClient?.city ?? '';
      final deliveryAddress = _currentClient?.deliveryAddress ?? '';
      final cartTotal =
          cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
      final minAmount = getMinOrderAmount(context);
      final discount = getClientDiscount();

      print('📦 Отправка заказа: сумма=$cartTotal, мин.сумма=$minAmount');

      // Проверяем минимальную сумму заказа
      if (!meetsMinimumOrderAmount(context)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Минимальная сумма заказа ${minAmount.toStringAsFixed(0)}₽'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      // Формируем комментарий к заказу
      String comment = '';
      if (discount > 0) {
        comment = 'Скидка ${discount.toStringAsFixed(0)}%';
      }

      // Группируем заказы по клиентам
      final ordersByClient = <String, List<OrderItem>>{};

      for (var order in _allOrders!) {
        if (order.quantity > 0) {
          final key = '${order.clientPhone}_${order.clientName}';
          ordersByClient.putIfAbsent(key, () => []).add(order);
        }
      }

      // Отправляем заказы для каждого клиента
      for (var orders in ordersByClient.values) {
        if (orders.isEmpty) continue;

        final client = orders.first;
        final items = orders.map((o) => o.toJson()).toList();
        final totalAmount = orders.fold(0.0, (sum, o) => sum + o.totalPrice);

        final result = await apiService.createOrder(
          clientId: client.clientPhone,
          employeeId: 'автомат',
          items: items,
          totalAmount: totalAmount,
          deliveryCity: deliveryCity,
          deliveryAddress: deliveryAddress,
          comment: comment,
        );

        if (result == null) {
          throw Exception('Ошибка отправки заказа для ${client.clientName}');
        }

        // Если заказ успешно отправлен, удаляем его из локального списка
        for (var order in orders) {
          _allOrders!.remove(order);
        }
      }

      // Сохраняем обновленный список заказов
      await _saveOrdersToPreferences();

      print('✅ Все заказы успешно отправлены');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказы успешно отправлены!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return true;
    } catch (e) {
      print('❌ Ошибка отправки заказов: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки заказов: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // Сохранение заказов в SharedPreferences (для офлайн-режима)
  Future<void> _saveOrdersToPreferences() async {
    if (_allOrders == null) return;

    final prefs = await SharedPreferences.getInstance();
    final ordersJson = _allOrders!.map((o) => o.toJson()).toList();
    await prefs.setString('all_orders', jsonEncode(ordersJson));
  }

  Future<void> _saveModeToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_list_mode', _priceListMode.name);
  }

  // Очистка при выходе
  void reset() {
    _currentClient = null;
    _allOrders = null;
    _allProducts = null;
    _deliveryCondition = null;
  }
}
