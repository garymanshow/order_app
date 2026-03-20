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
    // Ищем КБЖУ для продукта
    final nutrition = clientData.nutritionInfos.firstWhere(
      (n) => n.priceListId == product.id,
      orElse: () => NutritionInfo(
        priceListId: product.id,
        calories: '',
        proteins: '',
        fats: '',
        carbohydrates: '',
      ),
    );

    // Ищем условия хранения для продукта
    StorageCondition? storage;
    try {
      storage = clientData.storageConditions.firstWhere(
        (s) => s.sheetName == 'Прайс-лист' && s.entityId == product.id,
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
  ) {
    return products.map((product) {
      // 🔥 ПОЛУЧАЕМ ИНФОРМАЦИЮ О КАТЕГОРИИ
      final categoryInfo = _getCategoryInfo(product, clientData);

      return buildProductCard(
        product,
        clientData,
        packagingQuantity: categoryInfo['packagingQuantity'] as int,
        packagingName: categoryInfo['packagingName'] as String,
        declaredWeight: categoryInfo['declaredWeight'] as int,
      );
    }).toList();
  }

  // 🔥 ПОЛУЧЕНИЕ ИНФОРМАЦИИ О КАТЕГОРИИ ТОВАРА
  static Map<String, dynamic> _getCategoryInfo(
    Product product,
    ClientData clientData,
  ) {
    // Значения по умолчанию
    const defaultPackagingQuantity = 1;
    const defaultPackagingName = 'Транспортный контейнер';
    const defaultDeclaredWeight = 120;

    // Если у продукта нет categoryId, возвращаем значения по умолчанию
    if (product.categoryId.isEmpty) {
      print('⚠️ Товар "${product.name}" не имеет категории');
      return {
        'packagingQuantity': defaultPackagingQuantity,
        'packagingName': defaultPackagingName,
        'declaredWeight': defaultDeclaredWeight,
      };
    }

    // Ищем категорию по ID в индексе
    final category = clientData.priceCategoryIndex[product.categoryId];

    if (category == null) {
      print(
          '⚠️ Категория с ID ${product.categoryId} не найдена для товара "${product.name}"');
      return {
        'packagingQuantity': defaultPackagingQuantity,
        'packagingName': defaultPackagingName,
        'declaredWeight': defaultDeclaredWeight,
      };
    }

    // Возвращаем данные из категории
    return {
      'packagingQuantity': category.packagingQuantity,
      'packagingName': category.packagingName,
      'declaredWeight': category.weight.toInt(), // Вес из категории
    };
  }

  // 🔥 ПОЛУЧЕНИЕ УСЛОВИЙ ХРАНЕНИЯ ДЛЯ КАТЕГОРИИ
  static List<StorageCondition> getStorageConditionsForCategory(
    String categoryId,
    ClientData clientData,
  ) {
    return clientData.storageConditions
        .where((s) =>
            s.sheetName == 'Категория прайса' && s.entityId == categoryId)
        .toList();
  }

  // 🔥 ФОРМАТИРОВАНИЕ УСЛОВИЙ ХРАНЕНИЯ
  static String formatStorageConditions(StorageCondition? condition) {
    if (condition == null) return 'Не указано';

    final parts = <String>[];
    if (condition.storageLocation.isNotEmpty) {
      parts.add('Место: ${condition.storageLocation}');
    }
    if (condition.temperature.isNotEmpty) {
      parts.add('Температура: ${condition.temperature}°C');
    }
    if (condition.humidity.isNotEmpty) {
      parts.add('Влажность: ${condition.humidity}%');
    }
    if (condition.shelfLife.isNotEmpty) {
      parts.add('Срок: ${condition.shelfLife} ${condition.unit}');
    }

    return parts.join(', ');
  }

  // 🔥 ФОРМАТИРОВАНИЕ КБЖУ
  static String formatNutrition(NutritionInfo nutrition) {
    final parts = <String>[];
    if (nutrition.calories?.isNotEmpty == true) {
      parts.add('${nutrition.calories} ккал');
    }
    if (nutrition.proteins?.isNotEmpty == true) {
      parts.add('б: ${nutrition.proteins}г');
    }
    if (nutrition.fats?.isNotEmpty == true) {
      parts.add('ж: ${nutrition.fats}г');
    }
    if (nutrition.carbohydrates?.isNotEmpty == true) {
      parts.add('у: ${nutrition.carbohydrates}г');
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Не указано';
  }

  // 🔥 ПОЛУЧЕНИЕ ПОЛНОГО СОСТАВА ТОВАРА (базовый + уникальный)
  static List<Map<String, String>> getFullComposition(
    Product product,
    ClientData clientData,
  ) {
    final result = <Map<String, String>>[];

    // 1. Добавляем состав из категории (базовый)
    if (product.categoryId.isNotEmpty) {
      final categoryCompositions = clientData.compositions
          .where((c) =>
              c.sheetName == 'Категория прайса' &&
              c.entityId == product.categoryId)
          .toList();

      for (var comp in categoryCompositions) {
        result.add({
          'name': comp.ingredientName,
          // 🔥 ИСПРАВЛЕНО: преобразуем double в String
          'quantity': comp.quantity.toString(),
          // 🔥 ИСПРАВЛЕНО: используем правильное поле unitSymbol
          'unit': comp.unitSymbol,
        });
      }
    }

    // 2. Добавляем уникальный состав из товара
    final productCompositions = clientData.compositions
        .where((c) => c.sheetName == 'Прайс-лист' && c.entityId == product.id)
        .toList();

    for (var comp in productCompositions) {
      result.add({
        'name': comp.ingredientName,
        // 🔥 ИСПРАВЛЕНО: преобразуем double в String
        'quantity': comp.quantity.toString(),
        // 🔥 ИСПРАВЛЕНО: используем правильное поле unitSymbol
        'unit': comp.unitSymbol,
      });
    }

    return result;
  }
}
