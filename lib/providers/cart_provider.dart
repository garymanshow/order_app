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

  // ==========================================
  // ФИЛЬТРЫ
  // ==========================================

  List<OrderItem> get cartItems {
    if (_currentClient == null || _auth?.clientData == null) return [];
    return _auth!.clientData!.orders
        .where((o) =>
            o.clientPhone == _currentClient!.phone &&
            o.clientName == _currentClient!.name &&
            o.quantity > 0)
        .toList();
  }

  int getQuantity(String productId) {
    if (_currentClient == null || _auth?.clientData == null) return 0;
    final order = _auth!.clientData!.orders.firstWhereOrNull((o) =>
        o.clientPhone == _currentClient!.phone &&
        o.clientName == _currentClient!.name &&
        o.priceListId == productId);
    return order?.quantity ?? 0;
  }

  // ==========================================
  // УПРАВЛЕНИЕ СОСТОЯНИЕМ
  // ==========================================

  void setAuthProvider(AuthProvider auth) {
    _auth = auth;
  }

  void loadCartForClient(
      Client client, List<OrderItem> globalOrders, List<Product> allProducts) {
    _currentClient = client;
    _allProducts = allProducts;
    // НИКАКОЙ ЛОКАЛЬНОЙ ПАМЯТИ. Мы просто запоминаем, кто сейчас выбран.
    _isInitialized = true;
    _updateDeliveryCondition();
    notifyListeners();
  }

  Future<void> setPriceListMode(PriceListMode mode) async {
    _priceListMode = mode;
    await _saveModeToSharedPreferences();
    notifyListeners();
  }

  Future<void> loadPriceListMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('price_list_mode');
    if (modeString != null) {
      _priceListMode = PriceListModeExtension.fromString(modeString);
    }
  }

  void reset() {
    _currentClient = null;
    _isInitialized = false;
    // _allOrders НЕ ТРОГАЕМ!
    notifyListeners();
  }

  void hardReset() {
    _currentClient = null;
    _allProducts = null;
    _isInitialized = false;
    notifyListeners();
  }

  void _updateDeliveryCondition() {
    _deliveryCondition = null;
  }

  // ==========================================
  // ЛОГИКА КОРЗИНЫ
  // ==========================================

  Future<void> setQuantity(
      String productId, int quantity, int multiplicity) async {
    if (_currentClient == null ||
        _allProducts == null ||
        _auth?.clientData == null) {
      return;
    }

    final adjustedQuantity =
        ((quantity / multiplicity).round() * multiplicity).clamp(0, 999);
    final product = _allProducts!.firstWhere((p) => p.id == productId);

    // ИЩЕМ И МЕНЯЕМ СРАЗУ В ГЛОБАЛЬНОМ СПИСКЕ (через AuthProvider)
    final globalOrders = _auth!.clientData!.orders;

    final existingIndex = globalOrders.indexWhere((o) =>
        o.clientPhone == _currentClient!.phone &&
        o.clientName == _currentClient!.name &&
        o.priceListId == productId);

    if (adjustedQuantity <= 0) {
      if (existingIndex != -1) {
        globalOrders.removeAt(existingIndex);
      }
    } else if (existingIndex != -1) {
      final orderToUpdate = globalOrders[existingIndex];
      orderToUpdate.quantity = adjustedQuantity;
      orderToUpdate.totalPrice = product.price * adjustedQuantity;
      orderToUpdate.status = '';
    } else {
      globalOrders.add(OrderItem(
        status: '',
        productName: product.name,
        quantity: adjustedQuantity,
        totalPrice: product.price * adjustedQuantity,
        date: '',
        clientPhone: _currentClient!.phone!,
        clientName: _currentClient!.name!,
        priceListId: productId,
      ));
    }

    // Сохраняем и будим ТОЛЬКО AuthProvider. Он обновит и шапку прайса, и экран выбора.
    await _saveOrdersToPreferences();
    _auth!.notifyListeners();
  }

  void clearClientsCart(List<String> successClientKeys) {
    if (_auth?.clientData == null) return;
    final globalOrders = _auth!.clientData!.orders;

    globalOrders.removeWhere((order) {
      if (order.quantity <= 0) return false;
      final key = '${order.clientPhone}_${order.clientName}';
      return successClientKeys.contains(key);
    });

    _saveOrdersToPreferences();
    _auth!.notifyListeners(); // Будим экран выбора
  }
  // ==========================================
  // ОТПРАВКА
  // ==========================================

  Future<bool> submitAllOrders(
    BuildContext context,
    ApiService apiService, {
    List<OrderItem>? overrideOrders,
  }) async {
    final ordersToProcess = overrideOrders ?? cartItems;
    if (ordersToProcess.isEmpty) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет заказов для отправки')));
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
        final totalAmount =
            entry.value.fold(0.0, (sum, o) => sum + o.totalPrice);
        final minAmount = getMinOrderAmount(context);
        if (totalAmount < minAmount && minAmount > 0) {
          failedClients.add(
              '${entry.value.first.clientName} (сумма ${totalAmount.toStringAsFixed(0)}₽ < минималки)');
          hasValidationErrors = true;
        }
      }

      if (hasValidationErrors && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('⚠️ Не отправлены: ${failedClients.join(", ")}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5)));
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

        if (await apiService.createOrder(
            clientId: client.clientPhone,
            employeeId: 'автомат',
            items: items,
            totalAmount: totalAmount,
            deliveryCity: deliveryCity,
            deliveryAddress: deliveryAddress,
            comment: comment)) {
          successClientKeys.add(entry.key);
        } else {
          allNetworkSuccess = false;
        }
      }

      if (successClientKeys.isNotEmpty) {
        clearClientsCart(successClientKeys);
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '✅ Успешно отправлено заказов: ${successClientKeys.length}'),
              backgroundColor: Colors.green));
      }
      return allNetworkSuccess;
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Ошибка: $e'), backgroundColor: Colors.red));
      return false;
    }
  }

  // ==========================================
  // ОФЛАЙН И ВСПОМОГАТЕЛЬНЫЕ
  // ==========================================

  Future<bool> submitOrderOffline(
      {required BuildContext context,
      required String clientId,
      required String employeeId,
      required List<Map<String, dynamic>> items,
      required double totalAmount,
      String? deliveryCity,
      String? deliveryAddress,
      String? comment}) async {
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
          comment: comment);
      if (_currentClient != null)
        clearClientsCart(['${_currentClient!.phone}_${_currentClient!.name}']);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('📱 Заказ сохранён локально'),
            backgroundColor: Colors.orange));
      return true;
    } else {
      final success = await _apiService.createOrder(
          clientId: clientId,
          employeeId: employeeId,
          items: items,
          totalAmount: totalAmount,
          deliveryCity: deliveryCity,
          deliveryAddress: deliveryAddress,
          comment: comment);
      if (success && _currentClient != null)
        clearClientsCart(['${_currentClient!.phone}_${_currentClient!.name}']);
      return success;
    }
  }

  DeliveryCondition? getDeliveryCondition(BuildContext context) {
    if (_currentClient == null || _currentClient!.city == null) return null;
    return delivery.DeliveryConditionsService()
        .getConditionForLocation(_currentClient!.city!, context);
  }

  double getMinOrderAmount(BuildContext context) {
    if (_currentClient == null || _currentClient!.city == null) return 0.0;
    return delivery.DeliveryConditionsService()
        .getMinOrderAmount(_currentClient!.city!, context);
  }

  double getMarkupForClient(BuildContext context) {
    if (_currentClient == null || _currentClient!.city == null) return 0.0;
    return delivery.DeliveryConditionsService()
        .getMarkupForCity(_currentClient!.city!, context);
  }

  double getClientDiscount() => _currentClient?.discount ?? 0.0;

  double calculateFinalPrice(double basePrice, BuildContext context) {
    final markup = getMarkupForClient(context);
    final discount = getClientDiscount();
    return basePrice * (1 + (markup - discount) / 100);
  }

  bool meetsMinimumOrderAmount(BuildContext context) {
    final cartTotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    return cartTotal >= getMinOrderAmount(context);
  }

  Future<void> _saveOrdersToPreferences() async {
    if (_auth?.clientData == null) return; // Было: if (_allOrders == null)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('all_orders',
        jsonEncode(_auth!.clientData!.orders.map((o) => o.toJson()).toList()));
  }

  Future<void> _saveModeToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_list_mode', _priceListMode.name);
  }

  void forceUpdateAllOrdersForSubmission(
      List<OrderItem> allOrders, Client? client) {
    // Используется на экране выбора клиентов для отправки пачкой.
    // Заменяем глобальный список на переданный (хоть это и тот же самый список)
    if (_auth?.clientData != null) {
      _auth!.clientData!.orders = allOrders;
    }
    if (client != null) _currentClient = client;
    notifyListeners();
  }

  void updateData(List<OrderItem>? allOrders, List<Product>? allProducts) {
    // Если этот метод где-то вызывается, просто обновляем продукты
    _allProducts = allProducts;
    _updateDeliveryCondition();
    notifyListeners();
  }
}
