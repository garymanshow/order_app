// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Models
import '../models/client_category.dart';
import '../models/client.dart';
import '../models/composition.dart';
import '../models/delivery_condition.dart';
import '../models/employee.dart';
import '../models/filling.dart';
import '../models/nutrition_info.dart';
import '../models/order_item.dart';
import '../models/price_category.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/sheet_metadata.dart';
import '../models/storage_condition.dart';

// Services
import '../services/api_service.dart';

// Utils
import '../utils/phone_validator.dart';

class AuthService {
  Future<AuthResponse?> authenticate(String phone) async {
    // 🔥 Используем утилиту PhoneValidator для нормализации
    final normalizedPhone = PhoneValidator.normalizePhone(phone);

    if (normalizedPhone == null) {
      print('❌ Неверный формат телефона: $phone');
      return null;
    }

    // 🔥 Дополнительная валидация для авторизации
    if (!PhoneValidator.isValidAuthPhone(normalizedPhone)) {
      print('❌ Телефон не прошел валидацию для авторизации: $normalizedPhone');
      return null;
    }

    try {
      // 🔥 ПОЛУЧАЕМ ЛОКАЛЬНЫЕ МЕТАДАННЫЕ
      final prefs = await SharedPreferences.getInstance();
      final localMetadataJson = prefs.getString('local_metadata');
      Map<String, SheetMetadata> localMetadata = {};

      if (localMetadataJson != null) {
        final metadataMap =
            jsonDecode(localMetadataJson) as Map<String, dynamic>;
        localMetadata = metadataMap.map((key, value) => MapEntry(
            key, SheetMetadata.fromJson(value as Map<String, dynamic>)));
      }

      // 🔥 ИСПОЛЬЗУЕМ ApiService (без FCM)
      final apiService = ApiService();
      final authResponse = await apiService.authenticate(
        phone: normalizedPhone,
        localMetadata: localMetadata,
      );

      if (authResponse == null) return null;

      // Сохраняем обновленные метаданные
      await prefs.setString(
          'local_metadata', jsonEncode(authResponse['metadata']));

      // Десериализация пользователя
      final userData = authResponse['user'];
      User user;
      if (userData['role'] != null) {
        user = Employee.fromJson(userData);
      } else {
        user = Client.fromJson(userData);
      }

      // Десериализация данных клиента (расширенная версия)
      final clientDataObj = _deserializeClientData(authResponse['data']);

      final result = AuthResponse(
        user: user,
        metadata: authResponse['metadata'] as Map<String, SheetMetadata>,
        clientData: clientDataObj,
        timestamp: DateTime.now().toIso8601String(),
      );

      return result;
    } catch (e) {
      print('❌ Ошибка авторизации: $e');
      return null;
    }
  }

  // 🔥 ПОЛНАЯ ДЕСЕРИАЛИЗАЦИЯ ДАННЫХ КЛИЕНТА
  ClientData _deserializeClientData(dynamic data) {
    if (data == null) return ClientData();

    final clientData = ClientData();
    final clientDataMap = data as Map<String, dynamic>;

    // Продукты
    if (clientDataMap['products'] != null) {
      clientData.products = (clientDataMap['products'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Заказы
    if (clientDataMap['orders'] != null) {
      clientData.orders = (clientDataMap['orders'] as List)
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    // Составы
    if (clientDataMap['compositions'] != null) {
      clientData.compositions = (clientDataMap['compositions'] as List)
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Начинки
    if (clientDataMap['fillings'] != null) {
      clientData.fillings = (clientDataMap['fillings'] as List)
          .map((item) => Filling.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // КБЖУ
    if (clientDataMap['nutritionInfos'] != null) {
      clientData.nutritionInfos = (clientDataMap['nutritionInfos'] as List)
          .map((item) => NutritionInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Условия доставки
    if (clientDataMap['deliveryConditions'] != null) {
      clientData.deliveryConditions =
          (clientDataMap['deliveryConditions'] as List)
              .map((item) =>
                  DeliveryCondition.fromJson(item as Map<String, dynamic>))
              .toList();
    }

    // Категории клиентов
    if (clientDataMap['clientCategories'] != null) {
      clientData.clientCategories = (clientDataMap['clientCategories'] as List)
          .map((item) => ClientCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Клиенты
    if (clientDataMap['clients'] != null) {
      clientData.clients = (clientDataMap['clients'] as List)
          .map((item) => Client.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    // Условия хранения
    if (clientDataMap['storageConditions'] != null) {
      clientData.storageConditions = (clientDataMap['storageConditions']
              as List)
          .map(
              (item) => StorageCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Категории прайса
    if (clientDataMap['priceCategories'] != null) {
      clientData.priceCategories = (clientDataMap['priceCategories'] as List)
          .map((item) => PriceCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Корзина
    if (clientDataMap['cart'] != null) {
      clientData.cart = clientDataMap['cart'] as Map<String, dynamic>;
    }

    // Строим индексы для быстрого поиска
    clientData.buildIndexes();

    return clientData;
  }
}

class ClientData {
  List<Product> products = [];
  List<OrderItem> orders = [];
  List<Composition> compositions = [];
  List<Filling> fillings = [];
  List<NutritionInfo> nutritionInfos = [];
  List<DeliveryCondition> deliveryConditions = [];
  List<ClientCategory> clientCategories = [];
  List<Client> clients = [];
  List<StorageCondition> storageConditions = [];
  List<PriceCategory> priceCategories = [];
  Map<String, dynamic> cart = {};

  // Индексы для быстрого поиска
  Map<String, Product> productIndex = {};
  Map<String, List<Composition>> compositionIndex = {};
  Map<String, Filling> fillingIndex = {};
  Map<String, List<String>> clientCategoryIndex = {};
  Map<String, PriceCategory> priceCategoryIndex = {};

  ClientData();

  void buildIndexes() {
    productIndex = {for (var p in products) p.id: p};

    compositionIndex = {};
    for (var comp in compositions) {
      if (!compositionIndex.containsKey(comp.entityId)) {
        compositionIndex[comp.entityId] = [];
      }
      compositionIndex[comp.entityId]!.add(comp);
    }

    fillingIndex = {for (var f in fillings) f.entityId: f};

    clientCategoryIndex = {};
    for (var category in clientCategories) {
      if (!clientCategoryIndex.containsKey(category.clientName)) {
        clientCategoryIndex[category.clientName] = [];
      }
      clientCategoryIndex[category.clientName]!.add(category.entityId);
    }

    priceCategoryIndex = {for (var pc in priceCategories) pc.id: pc};
  }
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
