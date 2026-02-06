// lib/models/client_data.dart
import 'product.dart';
import 'order_item.dart';
import 'composition.dart';
import 'filling.dart';
import 'nutrition_info.dart';
import 'delivery_condition.dart';
import 'client_category.dart';
import 'client.dart'; // ← ДОБАВЬТЕ ЭТОТ ИМПОРТ

class ClientData {
  List<Product> products = [];
  List<OrderItem> orders = [];
  List<Composition> compositions = [];
  List<Filling> fillings = [];
  List<NutritionInfo> nutritionInfos = [];
  List<DeliveryCondition> deliveryConditions = [];
  List<ClientCategory> clientCategories = [];
  List<Client> clients = []; // ← ДОБАВЬТЕ ЭТО ПОЛЕ
  Map<String, dynamic> cart = {};

  // Индексы для быстрого поиска
  Map<String, Product> productIndex = {};
  Map<String, List<Composition>> compositionIndex = {};
  Map<String, Filling> fillingIndex = {};
  Map<String, List<String>> clientCategoryIndex = {};

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
  }

  factory ClientData.fromJson(Map<String, dynamic> json) {
    final clientData = ClientData();

    if (json['products'] != null) {
      clientData.products = (json['products'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['orders'] != null) {
      clientData.orders = (json['orders'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['compositions'] != null) {
      clientData.compositions = (json['compositions'] as List)
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['fillings'] != null) {
      clientData.fillings = (json['fillings'] as List)
          .map((item) => Filling.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['nutritionInfos'] != null) {
      clientData.nutritionInfos = (json['nutritionInfos'] as List)
          .map((item) => NutritionInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['deliveryConditions'] != null) {
      clientData.deliveryConditions = (json['deliveryConditions'] as List)
          .map((item) =>
              DeliveryCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['clientCategories'] != null) {
      clientData.clientCategories = (json['clientCategories'] as List)
          .map((item) => ClientCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 🔥 ЗАГРУЗКА КЛИЕНТОВ
    if (json['clients'] != null) {
      clientData.clients = (json['clients'] as List)
          .map((item) => Client.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['cart'] != null) {
      clientData.cart = json['cart'] as Map<String, dynamic>;
    }

    clientData.buildIndexes();
    return clientData;
  }

  Map<String, dynamic> toJson() {
    return {
      'products': products.map((p) => p.toJson()).toList(),
      'orders': orders.map((o) => o.toJson()).toList(),
      'compositions': compositions.map((c) => c.toJson()).toList(),
      'fillings': fillings.map((f) => f.toJson()).toList(),
      'nutritionInfos': nutritionInfos.map((n) => n.toJson()).toList(),
      'deliveryConditions': deliveryConditions.map((d) => d.toJson()).toList(),
      'clientCategories': clientCategories.map((c) => c.toJson()).toList(),
      'clients': clients.map((c) => c.toJson()).toList(), // 🔥
      'cart': cart,
    };
  }
}
