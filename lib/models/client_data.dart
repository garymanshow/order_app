// lib/models/client_data.dart
import 'product.dart';
import 'order_item.dart';
import 'composition.dart';
import 'filling.dart';
import 'nutrition_info.dart';
import 'delivery_condition.dart';
import 'client_category.dart';
import 'client.dart';
import 'storage_condition.dart';
import 'price_category.dart'; // 👈 НОВЫЙ ИМПОРТ

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
  List<PriceCategory> priceCategories = []; // 👈 НОВОЕ ПОЛЕ
  Map<String, dynamic> cart = {};

  // Индексы для быстрого поиска
  Map<String, Product> productIndex = {};
  Map<String, List<Composition>> compositionIndex = {};
  Map<String, Filling> fillingIndex = {};
  Map<String, List<String>> clientCategoryIndex = {};
  Map<String, PriceCategory> priceCategoryIndex = {}; // 👈 НОВЫЙ ИНДЕКС

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

    // 👈 НОВЫЙ ИНДЕКС ДЛЯ КАТЕГОРИЙ
    priceCategoryIndex = {for (var pc in priceCategories) pc.id: pc};
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

    // 🔥 Безопасная обработка заказов
    if (json['orders'] is List) {
      clientData.orders = (json['orders'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 Безопасная обработка составов
    if (json['compositions'] is List) {
      clientData.compositions = (json['compositions'] as List)
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 Безопасная обработка начинок
    if (json['fillings'] is List) {
      clientData.fillings = (json['fillings'] as List)
          .map((item) => Filling.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 Безопасная обработка КБЖУ
    if (json['nutritionInfos'] is List) {
      clientData.nutritionInfos = (json['nutritionInfos'] as List)
          .map((item) => NutritionInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 Безопасная обработка условий доставки
    if (json['deliveryConditions'] is List) {
      clientData.deliveryConditions = (json['deliveryConditions'] as List)
          .map((item) =>
              DeliveryCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 Безопасная обработка категорий клиентов
    if (json['clientCategories'] is List) {
      clientData.clientCategories = (json['clientCategories'] as List)
          .map((item) => ClientCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 Безопасная обработка клиентов
    if (json['clients'] is List) {
      clientData.clients = (json['clients'] as List)
          .map((item) => Client.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 Безопасная обработка условий хранения
    if (json['storageConditions'] is List) {
      clientData.storageConditions = (json['storageConditions'] as List)
          .map(
              (item) => StorageCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 НОВОЕ: обработка категорий прайса
    if (json['priceCategories'] is List) {
      clientData.priceCategories = (json['priceCategories'] as List)
          .map((item) => PriceCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 Безопасная обработка корзины
    if (json['cart'] is Map) {
      clientData.cart = json['cart'] as Map<String, dynamic>;
    }

    clientData.buildIndexes();
    return clientData;
  }

  Map<String, dynamic> toJson() {
    print('🟢 ClientData.toJson() START');
    print('   - products: ${products.length}');
    print('   - orders: ${orders.length}');
    print('   - compositions: ${compositions.length}');
    print('   - fillings: ${fillings.length}');
    print('   - nutritionInfos: ${nutritionInfos.length}');
    print('   - deliveryConditions: ${deliveryConditions.length}');
    print('   - clientCategories: ${clientCategories.length}');
    print('   - clients: ${clients.length}');
    print('   - storageConditions: ${storageConditions.length}');
    print('   - priceCategories: ${priceCategories.length}'); // 👈 НОВОЕ

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
      'priceCategories':
          priceCategories.map((pc) => pc.toJson()).toList(), // 👈 НОВОЕ
      'cart': cart,
    };

    print('🟢 ClientData.toJson() END');
    return json;
  }
}
