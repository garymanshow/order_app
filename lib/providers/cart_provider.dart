import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
  List<OrderItem> _allOrders = []; // Это наша "песочница" для текущего клиента
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
    if (_currentClient == null || _allOrders.isEmpty) return [];
    // Показываем всё, что есть в песочнице (и серверное, и накликанное)
    return _allOrders.where((o) => o.quantity > 0).toList();
  }

  int getQuantity(String productId) {
    if (_currentClient == null || _allOrders.isEmpty) return 0;
    final order =
        _allOrders.firstWhereOrNull((o) => o.priceListId == productId);
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

    // 🔥 РЕНТГЕН
    debugPrint('🏷️ loadCartForClient для: ${client.name}');
    debugPrint('🏷️ Всего глобальных заказов пришло: ${globalOrders.length}');

    _allOrders = globalOrders
        .where((o) =>
            o.clientPhone == client.phone &&
            o.clientName == client.name &&
            o.status == 'оформлен')
        .toList();

    // 🔥 РЕНТГЕН
    debugPrint(
        '🏷️ Отфильтровано в песочницу (оформленных у этого клиента): ${_allOrders.length}');

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
    notifyListeners();
  }

  void hardReset() {
    _currentClient = null;
    _allProducts = null;
    _allOrders.clear();
    _isInitialized = false;
    notifyListeners();
  }

  void _updateDeliveryCondition() {
    _deliveryCondition = null;
  }

  // ==========================================
  // ЛОГИКА КОРЗИНЫ
  // ==========================================
  Future<int> setQuantity(String productId, int quantity, int multiplicity,
      BuildContext context) async {
    if (_currentClient == null || _allProducts == null) return 0;

    final adjustedQuantity =
        ((quantity / multiplicity).round() * multiplicity).clamp(0, 999);
    final product = _allProducts!.firstWhere((p) => p.id == productId);

    final existingIndex =
        _allOrders.indexWhere((o) => o.priceListId == productId);

    if (adjustedQuantity <= 0) {
      if (existingIndex != -1) _allOrders.removeAt(existingIndex);
    } else if (existingIndex != -1) {
      // 🔥 ТОВАР УЖЕ ЕСТЬ (возможно, пришел с сервера со статусом "оформлен")
      final existingOrder = _allOrders[existingIndex];

      // Меняем количество и цену, но СТАТУС ОСТАВЛЯЕМ КАК БЫЛ!
      _allOrders[existingIndex] = existingOrder.copyWith(
        quantity: adjustedQuantity,
        totalPrice: product.price * adjustedQuantity,
        isLocalDraft:
            true, // 🔥 Любое изменение руками = пометка "не отправлено"
      );
    } else {
      // 🔥 НОВЫЙ ТОВАР
      _allOrders.add(OrderItem(
        status: 'оформлен', // Сразу ставим правильный статус
        productName: product.name,
        quantity: adjustedQuantity,
        totalPrice: product.price * adjustedQuantity,
        date: '', // GAS заполнит сам при отправке
        clientPhone: _currentClient!.phone!,
        clientName: _currentClient!.name!,
        priceListId: productId,
        isLocalDraft: true, // 🔥 Новый товар = локальный черновик
      ));
    }

    // Сразу пушим в AuthProvider для обновления суммы на главном экране
    _syncToGlobal(saveToDisk: true);

    notifyListeners();

    // Убираем принудительную перерисовку дерева, notifyListeners() справляется лучше и безопаснее
    return adjustedQuantity;
  }

  void clearClientsCart(List<String> successClientKeys) {
    if (_allOrders.isEmpty) return;

    // Удаляем из песочницы только то, что успешно ушло на сервер
    _allOrders.removeWhere((order) {
      final key = '${order.clientPhone}_${order.clientName}';
      return successClientKeys.contains(key);
    });

    // Синхронизируем удаление с AuthProvider
    _syncToGlobal(saveToDisk: true);
    notifyListeners();
  }

  // ==========================================
  // СИНХРОНИЗАЦИЯ МЕЖДУ ПЕСОЧНИЦЕЙ И AUTH PROVIDER
  // ==========================================

  /// Выгружает текущие заказы из песочницы обратно в общий список AuthProvider
  void _syncToGlobal({required bool saveToDisk}) {
    debugPrint('🔍 _syncToGlobal ЗАПУЩЕН');
    debugPrint('🔍 _auth is null? ${_auth == null}');
    debugPrint('🔍 _auth.clientData is null? ${_auth?.clientData == null}');
    debugPrint(
        '🔍 _currentClient phone: ${_currentClient?.phone}, name: ${_currentClient?.name}');
    debugPrint('🔍 Размер песочницы _allOrders: ${_allOrders.length}');

    if (_auth?.clientData == null || _currentClient == null) {
      debugPrint('❌ _syncToGlobal ПРЕРВАН: Нет данных или клиента');
      return;
    }

    // 1. Удаляем старые записи по этому клиенту из глобального списка
    final beforeCount = _auth!.clientData!.orders.length;
    _auth!.clientData!.orders.removeWhere((o) =>
        o.clientPhone == _currentClient!.phone &&
        o.clientName == _currentClient!.name);
    debugPrint(
        '🔍 Удалено старых записей: ${beforeCount - _auth!.clientData!.orders.length}');

    // 2. Добавляем актуальные из песочницы
    _auth!.clientData!.orders.addAll(_allOrders);
    debugPrint('🔍 Добавлено новых из песочницы: ${_allOrders.length}');
    debugPrint(
        '🔍 ИТОГО в глобальном списке стало: ${_auth!.clientData!.orders.length}');

    // 3. Сообщаем UI обновить суммы на главном экране
    _auth!.notifyListeners();

    // 4. (Опционально) Сохраняем вPrefs для защиты от закрытия вкладки
    if (saveToDisk) {
      _saveOrdersToPreferences();
    }
  }

  // ==========================================
  // ОТПРАВКА
  // ==========================================

  Future<bool> submitAllOrders(
    BuildContext context,
    ApiService apiService, {
    List<OrderItem>? overrideOrders,
  }) async {
    // Берем переданные заказы (они прилетят из ClientSelectionScreen)
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

        // Формируем JSON для отправки. isLocalDraft не уходит на сервер (мы убрали его из toMap)
        final items = clientOrders.map((o) {
          final json = o.toMap();
          json['Дата'] = now;
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
        // Очищаем из песочницы только успешно отправленных клиентов
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
  // ОСТАЛЬНЫЕ МЕТОДЫ (ОФЛАЙН, ДОСТАВКА, ВСПОМОГАТЕЛЬНЫЕ)
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

  /// Сохраняет ВСЕ глобальные заказы в SharedPreferences для защиты от закрытия вкладки
  Future<void> _saveOrdersToPreferences() async {
    if (_auth?.clientData == null) return;
    final prefs = await SharedPreferences.getInstance();
    // Сохраняем весь массив из AuthProvider, включая isLocalDraft
    await prefs.setString('all_orders',
        jsonEncode(_auth!.clientData!.orders.map((o) => o.toJson()).toList()));
  }

  Future<void> _saveModeToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_list_mode', _priceListMode.name);
  }

  void forceUpdateAllOrdersForSubmission(
      List<OrderItem> allOrders, Client? client) {
    // Этот метод вызывается перед отправкой пачки.
    // Мы не меняем _allOrders тут, чтобы не портить состояние CartProvider,
    // просто передаем ссылку в submitAllOrders
  }

  void updateData(List<OrderItem>? allOrders, List<Product>? allProducts) {
    _allProducts = allProducts;
    _updateDeliveryCondition();
    notifyListeners();
  }
}
