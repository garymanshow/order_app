// lib/services/auth_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Models
import '../models/client.dart';
import '../models/user.dart';
import '../models/sheet_metadata.dart';
import '../models/product.dart';
import '../models/order_item.dart';

// Services
import './google_sheets_service.dart';

class AuthService {
  /// Нормализует телефон: добавляет '+' если отсутствует
  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    return trimmed.startsWith('+') ? trimmed : '+$trimmed';
  }

  Future<AuthResponse?> authenticate(String phone) async {
    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    final normalizedInputPhone = _normalizePhone(phone);

    try {
      // Поиск клиента
      final clients = await service.read(
        sheetName: 'Клиенты',
        filters: [
          {'column': 'Телефон', 'value': normalizedInputPhone}
        ],
      );

      if (clients.isNotEmpty) {
        final row = clients.first;
        final client = Client(
          phone: _normalizePhone(
              row['Телефон']?.toString() ?? normalizedInputPhone),
          name: row['Клиент']?.toString() ?? 'Клиент',
          discount: _parseDiscount(row['Скидка']?.toString() ?? '')?.toDouble(),
          minOrderAmount:
              double.tryParse(row['Сумма миним.заказа']?.toString() ?? '0') ??
                  0.0,
        );

        // Получаем метаданные
        final metadata = await _loadMetadata(service);

        // Загружаем только обновлённые данные для клиента
        final clientData =
            await _loadClientSpecificData(service, metadata, client);

        return AuthResponse(
          user: client,
          metadata: metadata,
          clientData: clientData,
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return null;
    } catch (e) {
      print('Ошибка авторизации: $e');
      return null;
    }
  }

  Future<Map<String, SheetMetadata>> _loadMetadata(
      GoogleSheetsService service) async {
    try {
      final metadataRows = await service.read(sheetName: 'Метаданные');
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

  Future<ClientData> _loadClientSpecificData(GoogleSheetsService service,
      Map<String, SheetMetadata> metadata, Client client) async {
    final prefs = await SharedPreferences.getInstance();

    // Прайс-лист: проверяем метаданные (общий для всех)
    final priceLastUpdate = prefs.getString('client_price_last_update');
    final priceNeedsUpdate = _needsUpdate(
        priceLastUpdate, metadata['Прайс-лист']?.lastUpdate.toIso8601String());

    final clientData = ClientData();

    // Загружаем прайс-лист если нужно ИЛИ если кэш пустой
    if (priceNeedsUpdate) {
      // Загружаем свежие данные
      final products = await service.read(sheetName: 'Прайс-лист');

      // 🔥 ОТЛАДКА: Проверяем ключи первого продукта
      if (products.isNotEmpty) {
        print('🔍 Ключи в первом продукте из Google:');
        products[0].keys.forEach((key) {
          print('   "$key" = "${products[0][key]}"');
        });
      }

      clientData.products =
          products.map((row) => Product.fromMap(row)).toList();

      // 🔥 ОТЛАДКА: Проверяем ID продуктов
      print('💾 Продукты из Google:');
      for (var product in clientData.products.take(3)) {
        print('   ID: "${product.id}", Название: "${product.name}"');
      }

      await prefs.setString('client_price_data',
          jsonEncode(clientData.products.map((p) => p.toJson()).toList()));
      await prefs.setString(
          'client_price_last_update', DateTime.now().toIso8601String());
    } else {
      // Загружаем из кэша
      final priceJson = prefs.getString('client_price_data');
      if (priceJson != null) {
        clientData.products = _deserializeProducts(priceJson);
      } else {
        // 🔥 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: если кэш пуст, загружаем с сервера
        final products = await service.read(sheetName: 'Прайс-лист');

        // 🔥 ОТЛАДКА: Проверяем ключи первого продукта
        if (products.isNotEmpty) {
          print('🔍 Ключи в первом продукте из Google (кэш пуст):');
          products[0].keys.forEach((key) {
            print('   "$key" = "${products[0][key]}"');
          });
        }

        clientData.products =
            products.map((row) => Product.fromMap(row)).toList();

        // 🔥 ОТЛАДКА: Проверяем ID продуктов
        print('💾 Продукты из Google (кэш пуст):');
        for (var product in clientData.products.take(3)) {
          print('   ID: "${product.id}", Название: "${product.name}"');
        }

        await prefs.setString('client_price_data',
            jsonEncode(clientData.products.map((p) => p.toJson()).toList()));
        await prefs.setString(
            'client_price_last_update', DateTime.now().toIso8601String());
      }
    }

    print('📱 AUTH: Загружаем заказы для телефона: ${client.phone ?? "null"}');

    // Загружаем ЗАКАЗЫ КЛИЕНТА ВСЕГДА (без проверки метаданных)
    final orders = await service.read(
      sheetName: 'Заказы',
      filters: [
        {'column': 'Телефон', 'value': client.phone ?? ''},
      ],
    );

    print('✅ AUTH: Найдено заказов в Google: ${orders.length}');
    if (orders.isNotEmpty) {
      print('📋 Первый заказ: ${orders[0]}');
    }

    clientData.orders = orders.map((row) => OrderItem.fromMap(row)).toList();
    print('✅ AUTH SERVICE: Загружено заказов из Google: ${orders.length}');
    print('📱 AUTH SERVICE: Телефон клиента: ${client.phone ?? "null"}');

    final ordersJson =
        jsonEncode(clientData.orders.map((order) => order.toJson()).toList());
    await prefs.setString('client_orders_data', ordersJson);
    print(
        '💾 AUTH SERVICE: Сохранено ${clientData.orders.length} заказов для телефона ${client.phone}');

    // Загружаем корзину из SharedPreferences
    final cartJson = prefs.getString('client_cart_data');
    if (cartJson != null) {
      clientData.cart = jsonDecode(cartJson) as Map<String, dynamic>;
    }

    return clientData;
  }

  bool _needsUpdate(String? lastLocalUpdate, String? lastRemoteUpdate) {
    if (lastRemoteUpdate == null) return false;
    if (lastLocalUpdate == null) return true;

    final localDate = DateTime.tryParse(lastLocalUpdate);
    final remoteDate = DateTime.tryParse(lastRemoteUpdate);

    return remoteDate != null &&
        localDate != null &&
        remoteDate.isAfter(localDate);
  }

  int? _parseDiscount(String raw) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^\d,]'), '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.replaceAll(',', '.');
    try {
      return double.parse(normalized).toInt();
    } catch (e) {
      return null;
    }
  }

  List<Product> _deserializeProducts(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<OrderItem> _deserializeOrders(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}

class ClientData {
  List<Product> products = [];
  List<OrderItem> orders = [];
  Map<String, dynamic> cart = {};

  ClientData();
}

class AuthResponse {
  final User user;
  final Map<String, SheetMetadata> metadata;
  final ClientData? clientData;
  final String timestamp;

  AuthResponse({
    required this.user,
    required this.metadata,
    this.clientData,
    required this.timestamp,
  });
}
