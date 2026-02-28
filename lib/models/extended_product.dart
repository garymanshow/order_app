// lib/models/extended_product.dart
import 'product.dart';
import 'composition.dart';
import 'filling.dart';
import 'nutrition_info.dart';
import 'storage_condition.dart';

class ExtendedProduct {
  // Основная информация из Product
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? imageBase64;

  // Информация о фасовке (из Product или Category)
  final int packagingQuantity; // Фасовка (она же кратность)
  final String packagingName; // Тара
  final int declaredWeight; // Вес для клиента

  // Дополнительная информация для клиента
  final String? composition; // Состав (простая строка через запятую)
  final NutritionInfo? nutritionInfo; // КБЖУ
  final StorageCondition? storageConditions; // Условия хранения

  // Для производства (не показываем клиенту)
  final List<Composition>? detailedComposition; // Детальный состав
  final List<Filling>? fillings; // Полуфабрикаты

  ExtendedProduct({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.imageBase64,
    required this.packagingQuantity,
    required this.packagingName,
    required this.declaredWeight,
    this.composition,
    this.nutritionInfo,
    this.storageConditions,
    this.detailedComposition,
    this.fillings,
  });

  // Фабричный конструктор для сборки из всех источников
  factory ExtendedProduct.build({
    required Product product,
    required int packagingQuantity,
    required String packagingName,
    required int declaredWeight,
    List<Composition>? allCompositions, // используем
    List<Filling>? allFillings, // используем
    NutritionInfo? nutritionInfo,
    StorageCondition? storageConditions,
  }) {
    // Формируем состав для клиента
    String? compositionString;

    if (allCompositions != null && allCompositions.isNotEmpty) {
      final ingredients = <String>{};

      // Состав продукта
      final productComps = allCompositions
          .where((c) => c.sheetName == 'Прайс-лист' && c.entityId == product.id)
          .toList();

      for (var comp in productComps) {
        // Проверяем, является ли ингредиент полуфабрикатом
        final isFilling =
            allFillings?.any((f) => f.name == comp.ingredientName) ?? false;

        if (isFilling && allFillings != null) {
          // Это полуфабрикат - ищем его состав
          final filling = allFillings.firstWhere(
            (f) => f.name == comp.ingredientName,
            orElse: () => Filling(sheetName: '', entityId: '', name: ''),
          );

          if (filling.entityId.isNotEmpty) {
            final fillingComps = allCompositions
                .where((c) =>
                    c.sheetName == 'Категории прайса' &&
                    c.entityId == filling.entityId)
                .toList();

            for (var fillingComp in fillingComps) {
              ingredients.add(fillingComp.ingredientName);
            }
          }
        } else {
          ingredients.add(comp.ingredientName);
        }
      }

      if (ingredients.isNotEmpty) {
        compositionString = ingredients.join(', ');
      }
    }

    return ExtendedProduct(
      id: product.id,
      name: product.name,
      price: product.price,
      imageUrl: product.imageUrl,
      imageBase64: product.imageBase64,
      packagingQuantity: packagingQuantity,
      packagingName: packagingName,
      declaredWeight: declaredWeight,
      composition: compositionString,
      nutritionInfo: nutritionInfo,
      storageConditions: storageConditions,
      detailedComposition: allCompositions
          ?.where(
              (c) => c.entityId == product.id && c.sheetName == 'Прайс-лист')
          .toList(),
      fillings: allFillings,
    );
  }

  // Вспомогательные геттеры
  bool get hasComposition => composition != null && composition!.isNotEmpty;
  bool get hasNutrition => nutritionInfo != null;
  bool get hasStorage => storageConditions != null;
  bool get hasImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (imageBase64 != null && imageBase64!.isNotEmpty);

  // Форматированный вес для отображения
  String get formattedWeight => '$declaredWeight г';

  // Форматированная фасовка для отображения
  String get formattedPackaging => '$packagingQuantity шт/$packagingName';

  // Для JSON (кеширование)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'packagingQuantity': packagingQuantity,
      'packagingName': packagingName,
      'declaredWeight': declaredWeight,
      'composition': composition,
      'nutritionInfo': nutritionInfo?.toJson(),
      'storageConditions': storageConditions?.toJson(),
    };
  }

  factory ExtendedProduct.fromJson(Map<String, dynamic> json) {
    return ExtendedProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      imageBase64: json['imageBase64'] as String?,
      packagingQuantity: json['packagingQuantity'] as int,
      packagingName: json['packagingName'] as String,
      declaredWeight: json['declaredWeight'] as int,
      composition: json['composition'] as String?,
      nutritionInfo: json['nutritionInfo'] != null
          ? NutritionInfo.fromJson(
              json['nutritionInfo'] as Map<String, dynamic>)
          : null,
      storageConditions: json['storageConditions'] != null
          ? StorageCondition.fromJson(
              json['storageConditions'] as Map<String, dynamic>)
          : null,
    );
  }
}
