// lib/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'cache_service.dart';
import 'api_service.dart';
import '../models/order_item.dart';
import '../models/filling.dart';
import '../models/composition.dart';
import '../models/product.dart';
import '../models/price_category.dart';
import '../models/sheet_metadata.dart';
import '../models/client.dart';

class SyncService {
  final Connectivity _connectivity = Connectivity();
  late final CacheService _cache;
  final ApiService _api = ApiService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isInitialized = false;

  SyncService();

  Future<void> initialize() async {
    if (_isInitialized) return;

    _cache = await CacheService.getInstance();
    _isInitialized = true;
    print('✅ SyncService инициализирован');
  }

  void startPeriodicSync() {
    if (!_isInitialized) return;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => sync());

    // Подписываемся на изменения подключения
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        print('🌐 Интернет появился, запускаем синхронизацию');
        sync();
      }
    });

    print('🔄 Запущена периодическая синхронизация (каждые 5 минут)');
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('🔄 Периодическая синхронизация остановлена');
  }

  Future<void> sync() async {
    if (!_isInitialized || _isSyncing) return;
    _isSyncing = true;

    print('🔄 Начало синхронизации...');

    try {
      // 1. Получаем метаданные с сервера
      final serverMetadata = await _api.fetchMetadata();

      if (serverMetadata == null) {
        print('⚠️ Не удалось получить метаданные с сервера');
        return;
      }

      // 2. Сравниваем с локальными метаданными
      final localMetadata = _cache.getMetadata();

      final sheetsToUpdate = <String>[];
      for (var entry in serverMetadata.entries) {
        final local = localMetadata[entry.key];
        if (local == null || local.lastUpdate != entry.value.lastUpdate) {
          sheetsToUpdate.add(entry.key);
          print('📋 Лист "${entry.key}" требует обновления');
        }
      }

      // 3. Загружаем обновленные данные
      for (var sheet in sheetsToUpdate) {
        await _loadSheetData(sheet);
      }

      // 4. Отправляем отложенные операции
      await _sendPendingOperations();

      print(
          '✅ Синхронизация завершена, обновлено листов: ${sheetsToUpdate.length}');
    } catch (e) {
      print('❌ Ошибка синхронизации: $e');
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
            print('📦 Загружено ${orders.length} заказов');
          }
          break;

        case 'Начинки':
          final fillingsData = await _api.fetchFillings();
          if (fillingsData != null) {
            final fillings =
                fillingsData.map((json) => Filling.fromJson(json)).toList();
            await _cache.saveFillings(fillings);
            print('🥣 Загружено ${fillings.length} начинок');
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
            print('📦 Загружено ${products.length} продуктов');
          }
          break;

        case 'Категории прайса':
          final categoriesData = await _api.fetchPriceCategories();
          if (categoriesData != null) {
            await _cache.savePriceCategories(categoriesData);
            print('📂 Загружено ${categoriesData.length} категорий');
          }
          break;

        default:
          print('⚠️ Неизвестный лист для синхронизации: $sheetName');
      }
    } catch (e) {
      print('❌ Ошибка загрузки листа $sheetName: $e');
    }
  }

  Future<void> _sendPendingOperations() async {
    final pending = _cache.getPendingOperations();

    if (pending.isEmpty) return;

    print('📤 Отправка отложенных операций: ${pending.length}');

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
              // 🔥 РЕАЛИЗОВАНО: создание заказа
              success = await _createOrderFromData(data);
              print('📝 Создание заказа: ${success ? 'успешно' : 'ошибка'}');
            }
            break;
          case 'update':
            if (entity == 'order') {
              final order = OrderItem.fromJson(data);
              success = await _api.updateOrders([order]);
            }
            break;
          case 'delete':
            if (entity == 'order') {
              success = await _api.deleteOrder(data['id']);
            }
            break;
        }

        if (success) {
          await _cache.removeOperation(id);
          print('✅ Операция отправлена: $type/$entity');
        } else {
          print('⚠️ Не удалось отправить операцию: $type/$entity');
        }
      } catch (e) {
        print('❌ Ошибка отправки операции: $e');
      }
    }
  }

  /// 🔥 ВСПОМОГАТЕЛЬНЫЙ МЕТОД ДЛЯ СОЗДАНИЯ ЗАКАЗА
  Future<bool> _createOrderFromData(Map<String, dynamic> data) async {
    try {
      // Извлекаем данные из структуры
      final clientId = data['clientId']?.toString() ?? '';
      final employeeId = data['employeeId']?.toString() ?? '';
      final items =
          (data['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final deliveryCity = data['deliveryCity'] as String?;
      final deliveryAddress = data['deliveryAddress'] as String?;
      final comment = data['comment'] as String?;

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
      print('❌ Ошибка в _createOrderFromData: $e');
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

    print('📦 Заказ добавлен в очередь (офлайн-режим)');

    // Пытаемся отправить сразу, если есть интернет
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await sync();
    }
  }

  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;

  void dispose() {
    stopPeriodicSync();
  }
}
