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
import '../models/delivery_condition.dart';
import '../models/price_list_mode.dart';
import '../services/api_service.dart';
import '../services/delivery_conditions_service.dart' as delivery;
import '../services/sync_service.dart';
import 'auth_provider.dart';

class CartProvider with ChangeNotifier {
  Client? _currentClient;
  List<OrderItem>? _allOrders;
  List<Product>? _allProducts;
  DeliveryCondition? _deliveryCondition;
  PriceListMode _priceListMode = PriceListMode.full;
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;
  AuthProvider? _auth;

  // Геттеры
  PriceListMode get priceListMode => _priceListMode;
  DeliveryCondition? get deliveryCondition => _deliveryCondition;
  bool get isInitialized => _isInitialized;

  // Геттер для доступа к сырым заказам извне
  List<OrderItem>? get allOrders => _allOrders;

  // 🔥 Корзина
  List<OrderItem> get cartItems {
    if (_currentClient == null || _allOrders == null) return [];

    return _allOrders!
        .where((o) =>
            o.clientPhone == _currentClient!.phone &&
            o.clientName == _currentClient!.name &&
            o.quantity > 0)
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
    if (_currentClient == null || _allOrders == null || _allProducts == null) {
      return;
    }

    final adjustedQuantity =
        ((quantity / multiplicity).round() * multiplicity).clamp(0, 999);
    final product = _allProducts!.firstWhere((p) => p.id == productId);

    final existingIndex = _allOrders!.indexWhere((o) =>
        o.clientPhone == _currentClient!.phone &&
        o.clientName == _currentClient!.name &&
        o.priceListId == productId);

    if (adjustedQuantity <= 0) {
      if (existingIndex != -1) {
        _allOrders!.removeAt(existingIndex);
      }
    } else if (existingIndex != -1) {
      // 🔥 Меняем свойства СУЩЕСТВУЮЩЕГО объекта (не создаем new OrderItem)
      final orderToUpdate = _allOrders![existingIndex];
      orderToUpdate.quantity = adjustedQuantity;
      orderToUpdate.totalPrice = product.price * adjustedQuantity;
      orderToUpdate.status = '';
    } else {
      final newOrder = OrderItem(
        status: '',
        productName: product.name,
        quantity: adjustedQuantity,
        totalPrice: product.price * adjustedQuantity,
        date: '',
        clientPhone: _currentClient!.phone!,
        clientName: _currentClient!.name!,
        priceListId: productId,
      );
      _allOrders!.add(newOrder);
    }

    await _saveOrdersToPreferences();
    notifyListeners();
  }

  void setAuthProvider(AuthProvider auth) {
    _auth = auth;
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

  // 🔥 НОВЫЙ ПОДХОД: Просто грузим корзину нужного клиента из глобального списка
  void loadCartForClient(
      Client client, List<OrderItem> globalOrders, List<Product> allProducts) {
    _currentClient = client;
    _allProducts = allProducts;

    // Берем из ГЛОБАЛЬНОГО списка ТОЛЬКО товары этого клиента
    _allOrders = globalOrders
        .where(
            (o) => o.clientPhone == client.phone && o.clientName == client.name)
        .toList();

    _isInitialized = true;
    _updateDeliveryCondition();
    notifyListeners();
  }

  // 🔥 ТОЧЕЧНАЯ ОЧИСТКА: Обнуляем количество по ссылке
  void clearClientsCart(List<String> successClientKeys) {
    if (_allOrders == null) return;

    for (var order in _allOrders!) {
      if (order.quantity <= 0) continue;

      final key = '${order.clientPhone}_${order.clientName}';
      if (successClientKeys.contains(key)) {
        // Меняем свойства СУЩЕСТВУЮЩЕГО объекта по ссылке
        order.quantity = 0;
        order.totalPrice = 0.0;
      }
    }

    _saveOrdersToPreferences();
    notifyListeners();
    print('🗑️ Обнулены корзины для: ${successClientKeys.join(', ')}');
  }

  // Очистка при выходе
  void reset() {
    _currentClient = null;
    _deliveryCondition = null;
    _isInitialized = false;
    notifyListeners();
  }

  // 🔥 Жесткий сброс: ТОЛЬКО при логауте (выходе из аккаунта)
  void hardReset() {
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
    List<OrderItem>? overrideOrders,
  }) async {
    final ordersToProcess = overrideOrders ?? cartItems;

    if (ordersToProcess.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет заказов для отправки')),
        );
      }
      return false;
    }

    try {
      final deliveryCity = _currentClient?.city ?? '';
      final deliveryAddress = _currentClient?.deliveryAddress ?? '';
      final discount = getClientDiscount();
      String comment =
          discount > 0 ? 'Скидка ${discount.toStringAsFixed(0)}%' : '';

      final ordersByClient = <String, List<OrderItem>>{};

      for (var item in ordersToProcess) {
        if (item.quantity > 0) {
          final key = '${item.clientPhone}_${item.clientName}';
          ordersByClient.putIfAbsent(key, () => []).add(item);
        }
      }

      final successClientKeys = <String>[];
      final failedClients = <String>[];
      bool hasValidationErrors = false;

      for (var entry in ordersByClient.entries) {
        final clientOrders = entry.value;
        final clientName = clientOrders.first.clientName;
        final totalAmount =
            clientOrders.fold(0.0, (sum, o) => sum + o.totalPrice);
        final minAmount = getMinOrderAmount(context);

        if (totalAmount < minAmount && minAmount > 0) {
          failedClients.add(
              '$clientName (сумма ${totalAmount.toStringAsFixed(0)}₽ < минималки ${minAmount.toStringAsFixed(0)}₽)');
          hasValidationErrors = true;
        }
      }

      if (hasValidationErrors) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Не отправлены: ${failedClients.join(", ")}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      final validOrders = Map.fromEntries(ordersByClient.entries.where(
          (entry) => !failedClients
              .any((f) => f.startsWith(entry.value.first.clientName))));

      if (validOrders.isEmpty) return false;

      bool allNetworkSuccess = true;

      for (var entry in validOrders.entries) {
        final clientOrders = entry.value;
        final client = clientOrders.first;
        final totalAmount =
            clientOrders.fold(0.0, (sum, o) => sum + o.totalPrice);

        final now = DateTime.now().toUtc().toIso8601String();
        final items = clientOrders.map((o) {
          final json = o.toJson();
          json['date'] = now;
          return json;
        }).toList();

        final result = await apiService.createOrder(
          clientId: client.clientPhone,
          employeeId: 'автомат',
          items: items,
          totalAmount: totalAmount,
          deliveryCity: deliveryCity,
          deliveryAddress: deliveryAddress,
          comment: comment,
        );

        if (result) {
          successClientKeys.add(entry.key);
        } else {
          allNetworkSuccess = false;
        }
      }

      if (successClientKeys.isNotEmpty) {
        clearClientsCart(successClientKeys);

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Успешно отправлено заказов: ${successClientKeys.length}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      return allNetworkSuccess;
    } catch (e) {
      print('❌ Ошибка отправки заказов: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

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

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.isEmpty ||
        connectivityResult.contains(ConnectivityResult.none);

    if (isOffline) {
      await syncService.queueOrderCreation(
        clientId: clientId,
        employeeId: employeeId,
        items: items,
        totalAmount: totalAmount,
        deliveryCity: deliveryCity,
        deliveryAddress: deliveryAddress,
        comment: comment,
      );

      if (_currentClient != null) {
        clearClientsCart(['${_currentClient!.phone}_${_currentClient!.name}']);
      }

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
      final success = await _apiService.createOrder(
        clientId: clientId,
        employeeId: employeeId,
        items: items,
        totalAmount: totalAmount,
        deliveryCity: deliveryCity,
        deliveryAddress: deliveryAddress,
        comment: comment,
      );

      if (success && _currentClient != null) {
        clearClientsCart(['${_currentClient!.phone}_${_currentClient!.name}']);
      }
      return success;
    }
  }

  Future<void> _saveModeToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_list_mode', _priceListMode.name);
  }

  void forceUpdateAllOrdersForSubmission(
      List<OrderItem> allOrders, Client? client) {
    _allOrders = allOrders;
    if (client != null) {
      _currentClient = client;
    }
    notifyListeners();
  }
}
