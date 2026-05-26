// lib/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'cache_service.dart';
import 'api_service.dart';
import '../models/order_item.dart';
import '../models/filling.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';

class SyncService {
  final Connectivity _connectivity = Connectivity();
  late final CacheService _cache;
  final ApiService _api = ApiService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isInitialized = false;

  AuthProvider? _auth;

  SyncService();

  Future<void> initialize() async {
    if (_isInitialized) return;

    _cache = await CacheService.getInstance();
    _isInitialized = true;
    debugPrint('✅ SyncService инициализирован');
  }

  void startPeriodicSync() {
    if (!_isInitialized) return;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => sync());

    // Подписываемся на изменения подключения
    _connectivity.onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        debugPrint('🌐 Интернет появился, запускаем синхронизацию');
        sync();
      }
    });

    debugPrint('🔄 Запущена периодическая синхронизация (каждые 5 минут)');
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('🔄 Периодическая синхронизация остановлена');
  }

  void setAuthProvider(AuthProvider auth) {
    _auth = auth;
  }

  Future<void> sync() async {
    if (!_isInitialized || _isSyncing) return;
    _isSyncing = true;

    debugPrint('🔄 Начало синхронизации...');

    try {
      // 1. Получаем метаданные с сервера
      final serverMetadata = await _api.fetchMetadata();

      if (serverMetadata == null) {
        debugPrint('⚠️ Не удалось получить метаданные с сервера');
        return;
      }

      // 2. Сравниваем с локальными метаданными
      final localMetadata = _cache.getMetadata();

      final sheetsToUpdate = <String>[];
      for (var entry in serverMetadata.entries) {
        final local = localMetadata[entry.key];
        if (local == null || local.lastUpdate != entry.value.lastUpdate) {
          sheetsToUpdate.add(entry.key);
          debugPrint('📋 Лист "${entry.key}" требует обновления');
        }
      }

      // 3. Загружаем обновленные данные
      for (var sheet in sheetsToUpdate) {
        await _loadSheetData(sheet);
      }

      // 4. Отправляем отложенные операции
      await _sendPendingOperations();

      debugPrint(
          '✅ Синхронизация завершена, обновлено листов: ${sheetsToUpdate.length}');
    } catch (e) {
      debugPrint('❌ Ошибка синхронизации: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _loadSheetData(String sheetName) async {
    try {
      switch (sheetName) {
        case 'Заказы':
          final ordersData = await _api.fetchOrders();
          if (ordersData != null) {
            final orders =
                ordersData.map((json) => OrderItem.fromJson(json)).toList();
            await _cache.saveOrders(orders);
            debugPrint('📦 Загружено ${orders.length} заказов');
          }
          break;

        case 'Начинки':
          final fillingsData = await _api.fetchFillings();
          if (fillingsData != null) {
            final fillings =
                fillingsData.map((json) => Filling.fromJson(json)).toList();
            await _cache.saveFillings(fillings);
            debugPrint('🥣 Загружено ${fillings.length} начинок');
          }
          break;

        case 'Состав':
          // Состав загружается через другие методы
          // Пока пропускаем
          break;

        case 'Прайс-лист':
          final productsData = await _api.fetchProducts();
          if (productsData != null) {
            final products =
                productsData.map((json) => Product.fromJson(json)).toList();
            await _cache.saveProducts(products);
            debugPrint('📦 Загружено ${products.length} продуктов');
          }
          break;

        case 'Категории прайса':
          final categoriesData = await _api.fetchPriceCategories();
          if (categoriesData != null) {
            await _cache.savePriceCategories(categoriesData);
            debugPrint('📂 Загружено ${categoriesData.length} категорий');
          }
          break;

        default:
          debugPrint('⚠️ Неизвестный лист для синхронизации: $sheetName');
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки листа $sheetName: $e');
    }
  }

  Future<void> _sendPendingOperations() async {
    final pending = _cache.getPendingOperations();

    if (pending.isEmpty) return;

    debugPrint('📤 Отправка отложенных операций: ${pending.length}');

    for (var op in pending) {
      try {
        bool success = false;
        final id = op['id'];
        final type = op['type'];
        final entity = op['entity'];
        final data = op['data'];

        switch (type) {
          case 'create':
            if (entity == 'order') {
              success = await _createOrderFromData(data);
              debugPrint(
                  '📝 Создание заказа из очереди: ${success ? 'успешно' : 'ошибка'}');
            }
            break;

          // 🔥 case 'delete' УДАЛЕН. Удаление старых заказов теперь
          // происходит автоматически внутри GAS при вызове createOrder.

          case 'update':
            if (entity == 'order') {
              final order = OrderItem.fromJson(data);
              success = await _api.updateOrders([order]);
              debugPrint(
                  '🔄 Обновление заказа: ${success ? 'успешно' : 'ошибка'}');
            }
            break;
        }

        if (success) {
          await _cache.removeOperation(id);
          debugPrint('✅ Операция из очереди выполнена: $type/$entity');

          // Обновляем UI, если это был заказ
          if (entity == 'order') {
            _auth?.refreshOrdersFromCache();
          }
        } else {
          debugPrint(
              '⚠️ Не удалось выполнить операцию из очереди: $type/$entity');
        }
      } catch (e) {
        debugPrint('❌ Ошибка отправки операции из очереди: $e');
      }
    }
  }

  /// 🔥 ВСПОМОГАТЕЛЬНЫЙ МЕТОД ДЛЯ СОЗДАНИЯ ЗАКАЗА
  Future<bool> _createOrderFromData(Map<String, dynamic> data) async {
    try {
      // Извлекаем данные из структуры
      final clientId = data['clientId']?.toString() ?? '';
      final employeeId = data['employeeId']?.toString() ?? '';
      var items =
          (data['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final deliveryCity = data['deliveryCity'] as String?;
      final deliveryAddress = data['deliveryAddress'] as String?;
      final comment = data['comment'] as String?;

      // Гарантируем единую дату для офлайн-очереди
      final now = DateTime.now().toUtc().toIso8601String();
      items = items.map((item) {
        item['date'] = now; // Перезаписываем дату на момент реальной отправки
        return item;
      }).toList();

      // Вызываем API для создания заказа
      return await _api.createOrder(
        clientId: clientId,
        employeeId: employeeId,
        items: items,
        totalAmount: totalAmount,
        deliveryCity: deliveryCity,
        deliveryAddress: deliveryAddress,
        comment: comment,
      );
    } catch (e) {
      debugPrint('❌ Ошибка в _createOrderFromData: $e');
      return false;
    }
  }

  /// 🔥 МЕТОД ДЛЯ ДОБАВЛЕНИЯ ЗАКАЗА В ОЧЕРЕДЬ (ОФЛАЙН)
  Future<void> queueOrderCreation({
    required String clientId,
    required String employeeId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? deliveryCity,
    String? deliveryAddress,
    String? comment,
  }) async {
    final orderData = {
      'clientId': clientId,
      'employeeId': employeeId,
      'items': items,
      'totalAmount': totalAmount,
      if (deliveryCity != null) 'deliveryCity': deliveryCity,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (comment != null) 'comment': comment,
    };

    await _cache.addPendingOperation(
      type: 'create',
      entity: 'order',
      data: orderData,
    );

    debugPrint('📦 Заказ добавлен в очередь (офлайн-режим)');

    // Пытаемся отправить сразу, если есть интернет
    final connectivityResult = await _connectivity.checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await sync();
    }
  }

  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;

  void dispose() {
    stopPeriodicSync();
  }
}
