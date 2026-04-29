// lib/models/client_data.dart
import 'composition.dart';
import 'client_category.dart';
import 'client.dart';
import 'delivery_condition.dart';
import 'filling.dart';
import 'nutrition_info.dart';
import 'order_item.dart';
import 'product.dart';
import 'price_category.dart';
import 'storage_condition.dart';
import 'transport_condition.dart';
import 'unit_of_measure.dart';

// ИМПОРТИРУЕМ НОВЫЕ МОДЕЛИ
import 'vending_machine.dart';

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
  List<TransportCondition> transportConditions = [];
  List<PriceCategory> priceCategories = [];
  List<UnitOfMeasure> unitsOfMeasure = [];
  Map<String, dynamic> cart = {};

  // 🏭 НОВЫЕ СПИСКИ ВЕНДИНГА
  List<VendingMachine> vendingMachines = [];
  List<VendingLoad> vendingLoads = [];
  List<VendingOperation> vendingOperations = [];

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

  // Вспомогательный метод для безопасного парсинга (защита от коротких строк из Google Sheets)
  String _safeGetString(Map<String, dynamic> json, String key) {
    return json[key]?.toString() ?? '';
  }

  factory ClientData.fromJson(Map<String, dynamic> json) {
    print('🔍 ClientData.fromJson keys: ${json.keys}');
    final clientData = ClientData();

    // 🔥 Безопасная обработка списка продуктов
    if (json['products'] is List) {
      clientData.products = (json['products'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['orders'] is List) {
      clientData.orders = (json['orders'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['compositions'] is List) {
      clientData.compositions = (json['compositions'] as List)
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['fillings'] is List) {
      clientData.fillings = (json['fillings'] as List)
          .map((item) => Filling.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['nutritionInfos'] is List) {
      clientData.nutritionInfos = (json['nutritionInfos'] as List)
          .map((item) => NutritionInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['deliveryConditions'] is List) {
      clientData.deliveryConditions = (json['deliveryConditions'] as List)
          .map((item) =>
              DeliveryCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['clientCategories'] is List) {
      clientData.clientCategories = (json['clientCategories'] as List)
          .map((item) => ClientCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['clients'] is List) {
      clientData.clients = (json['clients'] as List)
          .map((item) => Client.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['storageConditions'] is List) {
      clientData.storageConditions = (json['storageConditions'] as List)
          .map(
              (item) => StorageCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['transportConditions'] is List) {
      clientData.transportConditions = (json['transportConditions'] as List)
          .map((item) =>
              TransportCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['priceCategories'] is List) {
      clientData.priceCategories = (json['priceCategories'] as List)
          .map((item) => PriceCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['unitsOfMeasure'] is List) {
      clientData.unitsOfMeasure = (json['unitsOfMeasure'] as List)
          .map((item) => UnitOfMeasure.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['cart'] is Map) {
      clientData.cart = json['cart'] as Map<String, dynamic>;
    }

    // ==============================================
    // 🏭 ПАРСИНГ ВЕНДИНГА
    // ==============================================
    if (json['vendingMachines'] is List) {
      clientData.vendingMachines = (json['vendingMachines'] as List)
          .map((item) => VendingMachine.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['vendingLoads'] is List) {
      clientData.vendingLoads = (json['vendingLoads'] as List)
          .map((item) => VendingLoad.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['vendingOperations'] is List) {
      clientData.vendingOperations = (json['vendingOperations'] as List)
          .map(
              (item) => VendingOperation.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    // ==============================================

    clientData.buildIndexes();
    return clientData;
  }

  Map<String, dynamic> toJson() {
    final json = {
      'products': products.map((p) => p.toJson()).toList(),
      'orders': orders.map((o) => o.toJson()).toList(),
      'compositions': compositions.map((c) => c.toJson()).toList(),
      'fillings': fillings.map((f) => f.toJson()).toList(),
      'nutritionInfos': nutritionInfos.map((n) => n.toJson()).toList(),
      'deliveryConditions': deliveryConditions.map((d) => d.toJson()).toList(),
      'clientCategories': clientCategories.map((c) => c.toJson()).toList(),
      'clients': clients.map((c) => c.toJson()).toList(),
      'storageConditions': storageConditions.map((s) => s.toJson()).toList(),
      'transportConditions':
          transportConditions.map((t) => t.toJson()).toList(),
      'priceCategories': priceCategories.map((pc) => pc.toJson()).toList(),
      'unitsOfMeasure': unitsOfMeasure.map((u) => u.toJson()).toList(),
      'cart': cart,
      // 🏭 ВЕНДИНГ
      'vendingMachines': vendingMachines.map((vm) => vm.toJson()).toList(),
      'vendingLoads': vendingLoads.map((vl) => vl.toJson()).toList(),
      'vendingOperations': vendingOperations.map((vo) => vo.toJson()).toList(),
    };

    return json;
  }
}
