// lib/services/packaging_service.dart
import '../models/warehouse_operation.dart';
import '../models/order_item.dart';
import '../models/product_category.dart';

class PackagingService {
  // Рассчитать списание упаковки для заказа
  Map<String, double> calculatePackagingDeduction(
    OrderItem order,
    List<ProductCategory> categories,
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
      // Списание тары
      final packagesNeeded =
          (order.quantity / category.packagingQuantity).ceilToDouble();
      result[category.packagingName] = packagesNeeded;

      // Списание бумажек (1:1)
      result['Бумажные вкладыши'] = order.quantity.toDouble();
    }

    return result;
  }

  // Создать операции списания упаковки
  List<WarehouseOperation> createPackagingDeductions(
    OrderItem order,
    List<ProductCategory> categories,
  ) {
    final deductions = <WarehouseOperation>[];
    final packagingMap = calculatePackagingDeduction(order, categories);

    for (var entry in packagingMap.entries) {
      deductions.add(WarehouseOperation(
        id: 'packaging_${order.clientPhone}_${DateTime.now().millisecondsSinceEpoch}',
        name: entry.key,
        operation: 'списание',
        quantity: entry.value,
        unit: 'шт', // Упрощаем - все упаковка в штуках
        date: DateTime.now(),
        relatedOrderId: order.clientPhone,
        notes:
            'Списание упаковки для заказа ${order.clientName}, ${order.quantity} шт',
      ));
    }

    return deductions;
  }

  // Автоматическое списание упаковки при доставке/корректировке
  Future<bool> deductPackagingForOrder(
    OrderItem order,
    List<ProductCategory> categories,
    Function(List<WarehouseOperation>) saveOperations,
  ) async {
    if (order.status == 'доставлен' || order.status == 'корректировка') {
      final deductions = createPackagingDeductions(order, categories);
      await saveOperations(deductions);
      return true;
    }
    return false;
  }
}
