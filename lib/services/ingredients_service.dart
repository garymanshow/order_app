// lib/services/ingredients_service.dart
import '../models/warehouse_operation.dart';
import '../models/order_item.dart';
import '../models/product_category.dart';
import '../models/composition.dart';

class IngredientsService {
  // Рассчитать списание ингредиентов для заказа с учетом издержек
  Map<String, double> calculateIngredientsDeduction(
    OrderItem order,
    List<ProductCategory> categories,
    List<Composition> compositions,
  ) {
    final result = <String, double>{};

    // Найти категорию для продукта
    ProductCategory? category;
    for (var cat in categories) {
      if (cat.name == order.productName) {
        category = cat;
        break;
      }
    }

    if (category != null) {
      // Найти состав для этого продукта
      final productCompositions = compositions
          .where((comp) => comp.entityId == order.priceListId)
          .toList();

      // Рассчитать коэффициент издержек
      final wasteMultiplier = 1.0 + (category.wastePercentage / 100.0);

      // Списать каждый ингредиент из состава
      for (var composition in productCompositions) {
        // Безопасное преобразование строк в double
        final compQuantity = double.tryParse(composition.quantity) ?? 0.0;
        final orderQty = order.quantity.toDouble();

        final ingredientAmount = compQuantity * orderQty * wasteMultiplier;

        // Добавить к существующему количеству или создать новое
        final currentAmount = result[composition.ingredientName] ?? 0.0;
        result[composition.ingredientName] = currentAmount + ingredientAmount;
      }
    }

    return result;
  }

  // Создать операции списания ингредиентов
  List<WarehouseOperation> createIngredientsDeductions(
    OrderItem order,
    List<ProductCategory> categories,
    List<Composition> compositions,
  ) {
    final deductions = <WarehouseOperation>[];
    final ingredientsMap =
        calculateIngredientsDeduction(order, categories, compositions);

    // Найти категорию для получения процента издержек
    int wastePercentage = 10;
    for (var cat in categories) {
      if (cat.name == order.productName) {
        wastePercentage = cat.wastePercentage;
        break;
      }
    }

    for (var entry in ingredientsMap.entries) {
      deductions.add(WarehouseOperation(
        id: 'ingredients_${order.clientPhone}_${DateTime.now().millisecondsSinceEpoch}',
        name: entry.key,
        operation: 'списание',
        quantity: entry.value,
        unit: 'кг',
        date: DateTime.now(),
        relatedOrderId: order.clientPhone,
        notes:
            'Списание ингредиентов для заказа ${order.clientName}, ${order.quantity} шт (издержки $wastePercentage%)',
      ));
    }

    return deductions;
  }

  // Списание ингредиентов при переводе заказа в статус "в производстве"
  Future<bool> deductIngredientsForProduction(
    OrderItem order,
    List<ProductCategory> categories,
    List<Composition> compositions,
    Function(List<WarehouseOperation>) saveOperations,
  ) async {
    if (order.status == 'в производстве') {
      final deductions =
          createIngredientsDeductions(order, categories, compositions);
      await saveOperations(deductions);
      return true;
    }
    return false;
  }
}
