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
import '../models/client_data.dart';
import '../services/api_service.dart';

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

  void _updateDeliveryCondition() {
    // Здесь логика определения условий доставки
    _deliveryCondition = null;
  }

  // 🔥 Отправка всех заказов
  Future<bool> submitAllOrders(ApiService apiService) async {
    if (_allOrders == null || _allOrders!.isEmpty) return false;

    try {
      // Группируем заказы по клиентам
      final ordersByClient = <String, List<OrderItem>>{};

      for (var order in _allOrders!) {
        if (order.quantity > 0) {
          // Отправляем только с quantity > 0
          final key = '${order.clientPhone}_${order.clientName}';
          ordersByClient.putIfAbsent(key, () => []).add(order);
        }
      }

      // Отправляем заказы для каждого клиента
      for (var orders in ordersByClient.values) {
        if (orders.isEmpty) continue;

        final client = orders.first;
        final items = orders.map((o) => o.toJson()).toList();

        await apiService.createOrder(
          clientId: client.clientPhone,
          employeeId: 'автомат',
          items: items,
          totalAmount: orders.fold(0.0, (sum, o) => sum + o.totalPrice),
          deliveryCity: '', // TODO: добавить город доставки
          deliveryAddress: '', // TODO: добавить адрес
          comment: '',
        );
      }

      print('✅ Все заказы успешно отправлены');
      return true;
    } catch (e) {
      print('❌ Ошибка отправки заказов: $e');
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
