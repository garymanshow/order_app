// lib/models/client_data.dart
import 'product.dart';
import 'order_item.dart';
import 'composition.dart';
import 'filling.dart';
import 'nutrition_info.dart';
import 'delivery_condition.dart';

class ClientData {
  List<Product> products = [];
  List<OrderItem> orders = [];
  List<Composition> compositions = [];
  List<Filling> fillings = [];
  List<NutritionInfo> nutritionInfos = [];
  List<DeliveryCondition> deliveryConditions = [];
  Map<String, dynamic> cart = {};

  // Индексы для быстрого поиска
  Map<String, Product> productIndex = {};
  Map<String, List<Composition>> compositionIndex = {}; // Составы по entityId
  Map<String, Filling> fillingIndex = {}; // Начинки по entityId

  ClientData();

  // 🔥 Строим индексы для оптимизации поиска
  void buildIndexes() {
    productIndex = {for (var p in products) p.id: p};

    // Индекс составов по entityId (может быть несколько записей на одну сущность)
    compositionIndex = {};
    for (var comp in compositions) {
      if (!compositionIndex.containsKey(comp.entityId)) {
        compositionIndex[comp.entityId] = [];
      }
      compositionIndex[comp.entityId]!.add(comp);
    }

    // Индекс начинок по entityId
    fillingIndex = {for (var f in fillings) f.entityId: f};
  }

  // 🔥 fromJson для восстановления из кэша
  factory ClientData.fromJson(Map<String, dynamic> json) {
    final clientData = ClientData();

    if (json['products'] != null) {
      clientData.products = (json['products'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (json['orders'] != null) {
      // 🔥 ИСПРАВЛЕНО: используем fromJson вместо fromMap
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

    if (json['cart'] != null) {
      clientData.cart = json['cart'] as Map<String, dynamic>;
    }

    clientData.buildIndexes();
    return clientData;
  }

  // 🔥 toJson для сохранения в кэш
  Map<String, dynamic> toJson() {
    return {
      'products': products.map((p) => p.toJson()).toList(),
      'orders': orders
          .map((o) => o.toJson())
          .toList(), // 🔥 ИСПРАВЛЕНО: toJson вместо toMap
      'compositions': compositions.map((c) => c.toJson()).toList(),
      'fillings': fillings.map((f) => f.toJson()).toList(),
      'nutritionInfos': nutritionInfos.map((n) => n.toJson()).toList(),
      'deliveryConditions': deliveryConditions.map((d) => d.toJson()).toList(),
      'cart': cart,
    };
  }
}
