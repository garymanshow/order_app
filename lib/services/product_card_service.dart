// lib/services/product_card_service.dart
import '../models/product.dart';
import '../models/extended_product.dart';
import '../models/client_data.dart';
import '../models/nutrition_info.dart';
import '../models/storage_condition.dart';

class ProductCardService {
  // Собрать расширенную карточку для одного продукта
  static ExtendedProduct buildProductCard(
    Product product,
    ClientData clientData, {
    required int packagingQuantity,
    required String packagingName,
    required int declaredWeight,
  }) {
    // Фильтруем состав для этого продукта (используем позже)
    final productCompositions = clientData.compositions
        .where((c) => c.sheetName == 'Прайс-лист' && c.entityId == product.id)
        .toList();

    // Ищем КБЖУ для продукта
    final nutrition = clientData.nutritionInfos.firstWhere(
      (n) => n.priceListId == product.id,
      orElse: () => NutritionInfo(),
    );

    // Ищем условия хранения для продукта
    StorageCondition? storage;
    try {
      storage = clientData.storageConditions.firstWhere(
        (s) => s.entityId == product.id && s.sheetName == 'Прайс-лист',
      );
    } catch (e) {
      storage = null;
    }

    return ExtendedProduct.build(
      product: product,
      packagingQuantity: packagingQuantity,
      packagingName: packagingName,
      declaredWeight: declaredWeight,
      allCompositions: clientData.compositions,
      allFillings: clientData.fillings,
      nutritionInfo: nutrition,
      storageConditions: storage,
    );
  }

  // Получить все продукты с расширенной информацией (для экспорта)
  static List<ExtendedProduct> buildAllProductCards(
    List<Product> products,
    ClientData clientData,
    Map<String, dynamic> categoryInfo, // информация о категориях
  ) {
    return products.map((product) {
      // TODO: получать информацию о категории
      return buildProductCard(
        product,
        clientData,
        packagingQuantity: 5,
        packagingName: 'Транспортный контейнер',
        declaredWeight: 120,
      );
    }).toList();
  }
}
