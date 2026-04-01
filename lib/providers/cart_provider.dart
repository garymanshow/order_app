// lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/delivery_condition.dart'; // ✅ Добавлен импорт
import '../models/price_list_mode.dart';
import '../services/api_service.dart';
import '../services/delivery_conditions_service.dart' as delivery;
import '../services/sync_service.dart';

class CartProvider with ChangeNotifier {
  Client? _currentClient;
  List<OrderItem>? _allOrders; // Ссылка на все заказы из AuthProvider
  List<Product>? _allProducts;
  DeliveryCondition? _deliveryCondition;
  PriceListMode _priceListMode = PriceListMode.full;
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;

  // Геттеры
  PriceListMode get priceListMode => _priceListMode;
  DeliveryCondition? get deliveryCondition => _deliveryCondition;
  bool get isInitialized => _isInitialized;

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
        // Обновляем существующий заказ
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
          date: DateTime.now().toUtc().toIso8601String(),
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

  // 🔥 Очистка корзины
  void clearCart() {
    if (_currentClient == null || _allOrders == null) return;

    _allOrders!.removeWhere((order) =>
        order.clientPhone == _currentClient!.phone &&
        order.clientName == _currentClient!.name &&
        order.quantity > 0);

    _saveOrdersToPreferences();
    notifyListeners();
    print('🗑️ Корзина очищена');
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
    _isInitialized = true;
    _updateDeliveryCondition();
    notifyListeners();
  }

  // Очистка при выходе
  void reset() {
    _currentClient = null;
    _allOrders = null;
    _allProducts = null;
    _deliveryCondition = null;
    _isInitialized = false;
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

  // 🔥 Получение условий доставки с контекстом
  DeliveryCondition? getDeliveryCondition(BuildContext context) {
    if (_currentClient == null || _currentClient!.city == null) return null;

    final deliveryService = delivery.DeliveryConditionsService();
    return deliveryService.getConditionForLocation(
        _currentClient!.city!, context);
  }

  // 🔥 Получение минимальной суммы заказа для города клиента
  double getMinOrderAmount(BuildContext context) {
    if (_currentClient == null || _currentClient!.city == null) return 0.0;

    final deliveryService = delivery.DeliveryConditionsService();
    return deliveryService.getMinOrderAmount(_currentClient!.city!, context);
  }

  // 🔥 Получение наценки для клиента
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

  // 🔥 Отправка всех заказов с возможностью очистки старых
  Future<bool> submitAllOrders(
    BuildContext context,
    ApiService apiService, {
    String? deleteStatus, // Добавлен параметр
  }) async {
    // ✅ Исправлено: используем геттер cartItems вместо переменной _cartItems
    if (cartItems.isEmpty) return false;

    try {
      final deliveryCity = _currentClient?.city ?? '';
      final deliveryAddress = _currentClient?.deliveryAddress ?? '';
      final minAmount = getMinOrderAmount(context);
      final discount = getClientDiscount();
      String comment =
          discount > 0 ? 'Скидка ${discount.toStringAsFixed(0)}%' : '';

      // Проверка минимальной суммы
      if (!meetsMinimumOrderAmount(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Минимальная сумма заказа ${minAmount.toStringAsFixed(0)}₽'),
              backgroundColor: Colors.orange),
        );
        return false;
      }

      // Группировка по клиентам
      final ordersByClient = <String, List<OrderItem>>{};

      // ✅ Исправлено: используем геттер cartItems
      for (var item in cartItems) {
        if (item.quantity > 0) {
          final key = '${item.clientPhone}_${item.clientName}';
          ordersByClient.putIfAbsent(key, () => []).add(item);
        }
      }

      bool allSuccess = true;

      for (var entry in ordersByClient.entries) {
        final clientOrders = entry.value;
        final client = clientOrders.first;
        final totalAmount =
            clientOrders.fold(0.0, (sum, o) => sum + o.totalPrice);
        final items = clientOrders.map((o) => o.toJson()).toList();

        // 🔥 ШАГ 1: Удаление старых заказов (если передан статус)
        if (deleteStatus != null && deleteStatus.isNotEmpty) {
          print(
              '🗑 Удаление старых заказов для ${client.clientName} (статус: $deleteStatus)');
          final deleted = await apiService.deleteOrder(
            clientPhone: client.clientPhone,
            clientName: client.clientName,
            status: deleteStatus,
          );
          if (!deleted) {
            print('⚠️ Не удалось удалить старые заказы (продолжаем создание)');
          }
        }

        // 🔥 ШАГ 2: Создание новых
        print('📤 Создание новых заказов для ${client.clientName}');
        final result = await apiService.createOrder(
          clientId: client.clientPhone,
          employeeId: 'автомат',
          items: items,
          totalAmount: totalAmount,
          deliveryCity: deliveryCity,
          deliveryAddress: deliveryAddress,
          comment: comment,
        );

        if (!result) {
          allSuccess = false;
        }
      }

      if (allSuccess) {
        // ✅ Исправлено: очищаем через существующий метод clearCart
        clearCart();

        // ✅ Исправлено: используем существующий метод сохранения
        await _saveOrdersToPreferences();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Заказы успешно синхронизированы!'),
                backgroundColor: Colors.green),
          );
        }
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Часть заказов не удалось синхронизировать'),
                backgroundColor: Colors.orange),
          );
        }
        return false;
      }
    } catch (e) {
      print('❌ Ошибка отправки заказов: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
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

  /// Создание заказа с поддержкой офлайн-режима
  Future<bool> submitOrderOffline({
    required BuildContext context,
    required String clientId,
    required String employeeId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? deliveryCity,
    String? deliveryAddress,
    String? comment,
  }) async {
    final syncService = Provider.of<SyncService>(context, listen: false);

    // Проверяем интернет
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      // Нет интернета — сохраняем в очередь
      await syncService.queueOrderCreation(
        clientId: clientId,
        employeeId: employeeId,
        items: items,
        totalAmount: totalAmount,
        deliveryCity: deliveryCity,
        deliveryAddress: deliveryAddress,
        comment: comment,
      );

      // Очищаем корзину
      clearCart();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '📱 Заказ сохранён локально и будет отправлен при появлении интернета'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return true;
    } else {
      // Есть интернет — отправляем сразу
      final success = await _apiService.createOrder(
        clientId: clientId,
        employeeId: employeeId,
        items: items,
        totalAmount: totalAmount,
        deliveryCity: deliveryCity,
        deliveryAddress: deliveryAddress,
        comment: comment,
      );

      if (success) {
        clearCart();
      }
      return success;
    }
  }

  Future<void> _saveModeToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_list_mode', _priceListMode.name);
  }
}
