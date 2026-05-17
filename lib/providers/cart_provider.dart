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
  // Геттер для доступа к сырым заказам извне (нужно для слияния при входе)
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
          status: '',
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

  // 🔥 ТОЧЕЧНАЯ ОЧИСТКА: удаляем только тех клиентов, чьи заказы улетели на сервер
  void clearClientsCart(List<String> successClientKeys) {
    if (_allOrders == null) return;

    _allOrders!.removeWhere((order) {
      if (order.quantity <= 0) return false; // Не трогаем пустые
      final key = '${order.clientPhone}_${order.clientName}';
      return successClientKeys
          .contains(key); // Удаляем только из списка успешных
    });

    _saveOrdersToPreferences();
    notifyListeners();
    print('🗑️ Очищены корзины для: ${successClientKeys.join(', ')}');
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

  // Установка клиента и данных с учетом слияния локальных и серверных корзин
  void setClient(Client client, List<OrderItem>? serverOrders,
      List<Product>? allProducts) {
    _currentClient = client;
    _allProducts = allProducts;

    // 🔥 СЛИЯНИЕ: Если в памяти уже были набраны товары (приложение свернули и открыли)
    if (_allOrders != null && serverOrders != null) {
      // Ищем товары, которые есть ТОЛЬКО локально (еще не отправлялись на сервер, статус пустой или 'новый')
      final localOnlyItems = _allOrders!
          .where((o) =>
              o.clientPhone == client.phone &&
              o.clientName == client.name &&
              (o.status.isEmpty || o.status.toLowerCase() == 'новый'))
          .toList();

      // Берем серверные заказы (оформленные) как базу
      _allOrders = List.from(serverOrders);

      // Накидываем локальные поверх серверных
      // (если менеджер правил один и тот же товар, останется его последняя локальная правка)
      _allOrders!.addAll(localOnlyItems);
    } else {
      // Если первый вход — просто берем то, что пришло с сервера
      _allOrders = serverOrders;
    }

    _isInitialized = true;
    _updateDeliveryCondition();
    notifyListeners();
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
    _allOrders = null; // Теперь можно обнулять
    _allProducts = null; // Теперь можно обнулять
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
    // 🔥 Если нам передали заказы напрямую (со списка клиентов), используем их.
    // Иначе берем стандартные cartItems.
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

      // 1. Группируем товары по клиентам (по ключу phone_name)
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

      // 2. ЛОКАЛЬНАЯ ПРЕДВАРИТЕЛЬНАЯ ПРОВЕРКА (Минимальные суммы)
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

      // Если есть клиенты, не прошедшие проверку минималки — warnим, но продолжаем для тех, кто прошел
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

      // Оставляем только тех, кто прошел валидацию
      final validOrders = Map.fromEntries(ordersByClient.entries.where(
          (entry) => !failedClients
              .any((f) => f.startsWith(entry.value.first.clientName))));

      if (validOrders.isEmpty) return false;

      // 3. ОТПРАВКА НА СЕРВЕР
      bool allNetworkSuccess = true;

      for (var entry in validOrders.entries) {
        final clientOrders = entry.value;
        final client = clientOrders.first;
        final totalAmount =
            clientOrders.fold(0.0, (sum, o) => sum + o.totalPrice);

        // 🔥 ФОРМИРУЕМ ЕДИНУЮ ДАТУ ДЛЯ ВСЕХ ТОВАРОВ ЭТОГО ЗАКАЗА
        final now = DateTime.now().toUtc().toIso8601String();
        final items = clientOrders.map((o) {
          final json = o.toJson();
          json['date'] = now; // Перезаписываем дату на момент отправки
          return json;
        }).toList();

        // Отправляем пачку товаров для конкретного клиента
        // GAS сам внутри handleCreateOrder удалит старые "оформленные" заказы этого клиента
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

      // 4. ФИНАЛЬНАЯ ОЧИСТКА ЛОКАЛЬНОЙ ПАМЯТИ
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

    // Проверяем интернет (исправлено для новой версии connectivity_plus)
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.isEmpty ||
        connectivityResult.contains(ConnectivityResult.none);

    if (isOffline) {
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

      // 🔥 ТОЧЕЧНАЯ ОЧИСТКА ОФЛАЙН
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

      if (success && _currentClient != null) {
        // 🔥 ТОЧЕЧНАЯ ОЧИСТКА ОНЛАЙН
        clearClientsCart(['${_currentClient!.phone}_${_currentClient!.name}']);
      }
      return success;
    }
  }

  Future<void> _saveModeToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_list_mode', _priceListMode.name);
  }

  // 🔥 Вспомогательный метод для экрана выбора клиентов.
  // Временно подкидывает ВСЕ заказы, чтобы отправить их пачкой.
  void forceUpdateAllOrdersForSubmission(
      List<OrderItem> allOrders, Client? client) {
    _allOrders = allOrders;
    if (client != null) {
      _currentClient =
          client; // Временно ставим любого клиента, чтобы геттеры не ругались на null
    }
    notifyListeners();
  }
}
