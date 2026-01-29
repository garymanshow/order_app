// lib/providers/orders_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/order_item.dart';
import '../services/google_sheets_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OrdersProvider with ChangeNotifier {
  List<OrderItem> _orders = [];
  late GoogleSheetsService _service;

  OrdersProvider() {
    _service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
  }

  List<OrderItem> get orders => _orders;

  Future<void> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString('orders_last_update');

    if (lastUpdateStr != null) {
      final lastUpdate = DateTime.tryParse(lastUpdateStr);
      final isFresh = await _checkOrdersFreshness(lastUpdate);
      if (isFresh) {
        _loadOrdersFromCache();
        return;
      }
    }

    await _loadFreshOrders();
  }

  void _loadOrdersFromCache() {
    SharedPreferences.getInstance().then((prefs) {
      final ordersJson = prefs.getString('orders_cache');
      if (ordersJson != null) {
        final list = jsonDecode(ordersJson) as List;
        _orders = list
            .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    });
  }

  Future<void> _loadFreshOrders() async {
    try {
      await _service.init();
      final data = await _service.read(sheetName: 'Заказы');
      _orders = data.map((row) => OrderItem.fromMap(row)).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('orders_cache', jsonEncode(_orders));
      await prefs.setString(
          'orders_last_update', DateTime.now().toIso8601String());

      notifyListeners();
    } catch (e) {
      print('Ошибка загрузки заказов: $e');
    }
  }

  Future<bool> _checkOrdersFreshness(DateTime? lastLocalUpdate) async {
    final metadata = await _loadMetadata();
    final remoteUpdate = metadata['Заказы']?.lastUpdate;
    return remoteUpdate != null &&
        lastLocalUpdate != null &&
        !remoteUpdate.isAfter(lastLocalUpdate);
  }

  Future<Map<String, SheetMetadata>> _loadMetadata() async {
    try {
      final metadataRows = await _service.read(sheetName: 'Метаданные');
      final metadata = <String, SheetMetadata>{};

      for (var row in metadataRows) {
        final sheetName = row['Лист']?.toString() ?? row['A']?.toString();
        final lastUpdateStr =
            row['Последнее обновление']?.toString() ?? row['B']?.toString();
        final editor = row['Редактор']?.toString() ?? row['C']?.toString();

        if (sheetName != null && lastUpdateStr != null) {
          try {
            final lastUpdate = DateTime.parse(lastUpdateStr);
            metadata[sheetName] =
                SheetMetadata(lastUpdate: lastUpdate, editor: editor ?? '');
          } catch (e) {
            print('Ошибка парсинга даты для листа $sheetName: $e');
          }
        }
      }

      return metadata;
    } catch (e) {
      print('Ошибка загрузки метаданных: $e');
      return {};
    }
  }

  // Менеджер может только управлять производственными статусами
  Future<void> startProduction(OrderItem order) async {
    if (order.canBeStartedByManager) {
      await _updateOrderStatus(order, 'в работе');
    }
  }

  Future<void> completeProduction(OrderItem order) async {
    if (order.isInProgress) {
      await _updateOrderStatus(order, 'готов к отправке');
    }
  }

  Future<void> _updateOrderStatus(OrderItem order, String newStatus) async {
    try {
      await _service.update(
        sheetName: 'Заказы',
        filters: [
          {'column': 'Телефон', 'value': order.clientPhone},
          {'column': 'Клиент', 'value': order.clientName},
          {'column': 'Название', 'value': order.productName},
        ],
        data: {
          'Статус': newStatus,
          'Уведомление отправлено': 'false',
        },
      );

      await loadOrders();
    } catch (e) {
      print('Ошибка обновления статуса: $e');
      rethrow;
    }
  }

  Future<void> loadOrdersIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString('metadata_orders');

    if (lastUpdateStr == null) {
      await loadOrders();
    } else {
      // 🔥 Исправление 1: конвертируем String в DateTime
      final lastUpdate = DateTime.tryParse(lastUpdateStr);
      final isFresh = await _checkOrdersFreshness(lastUpdate);
      if (!isFresh) {
        await loadOrders();
      } else {
        // 🔥 Исправление 2: используем существующий метод
        _loadOrdersFromCache();
      }
    }
  }

  Future<void> approveOrderForProduction(OrderItem order) async {
    if (order.canBeApprovedByAdmin) {
      await _updateOrderStatus(order, 'в производство');
      // Отправляем уведомление менеджеру
      await _sendNotificationToManager(order);
    }
  }

  Future<void> _sendNotificationToManager(OrderItem order) async {
    // Реализация отправки уведомления
    print('Уведомление менеджеру: Новый заказ "${order.productName}"');
  }
}

class SheetMetadata {
  final DateTime lastUpdate;
  final String editor;

  SheetMetadata({required this.lastUpdate, required this.editor});
}
