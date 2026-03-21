// lib/services/production_planning_service.dart
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/composition.dart';
import '../models/filling.dart';
import '../models/price_category.dart';
import '../models/production_plan.dart';
import '../services/unit_converter_service.dart';

class ProductionPlanningService {
  final List<OrderItem> orders;
  final List<Product> products;
  final List<Composition> compositions;
  final List<Filling> fillings;
  final List<PriceCategory> categories;
  final Map<String, double> currentStock;

  ProductionPlanningService({
    required this.orders,
    required this.products,
    required this.compositions,
    required this.fillings,
    required this.categories,
    required this.currentStock,
  });

  /// Расчёт плана производства на основе заказов со статусом "производство"
  ProductionPlan calculatePlan() {
    // 1. Собираем все заказы со статусом "производство"
    final productionOrders =
        orders.where((o) => o.status == 'производство').toList();

    // 2. Группируем по продуктам
    final productsNeeded = <String, int>{};
    for (var order in productionOrders) {
      productsNeeded[order.productName] =
          (productsNeeded[order.productName] ?? 0) + order.quantity;
    }

    // 3. Рассчитываем потребность в начинках
    final fillingsNeeded = _calculateFillingsNeeded(productsNeeded);

    // 4. Рассчитываем потребность в ингредиентах (с учётом начинок)
    final ingredientsNeeded = _calculateIngredientsNeeded(fillingsNeeded);

    // 5. Определяем, чего не хватает
    final shortage = <String, double>{};
    for (var entry in ingredientsNeeded.entries) {
      final available = currentStock[entry.key] ?? 0;
      if (available < entry.value) {
        shortage[entry.key] = entry.value - available;
      }
    }

    // 6. Добавляем проверку начинок (меньше 2 кг)
    for (var entry in fillingsNeeded.entries) {
      final available = currentStock['🥣 ${entry.key}'] ?? 0;
      if (available < entry.value) {
        shortage['🥣 ${entry.key}'] = entry.value - available;
      }
    }

    return ProductionPlan(
      date: DateTime.now(),
      productsNeeded: productsNeeded,
      fillingsNeeded: fillingsNeeded,
      ingredientsNeeded: ingredientsNeeded,
      currentStock: currentStock,
      shortage: shortage,
    );
  }

  /// Расчёт потребности в начинках
  Map<String, double> _calculateFillingsNeeded(
      Map<String, int> productsNeeded) {
    final fillingsNeeded = <String, double>{};

    for (var entry in productsNeeded.entries) {
      final productName = entry.key;
      final quantity = entry.value;

      // Находим продукт
      final product = products.firstWhere(
        (p) => p.name == productName,
        orElse: () => throw Exception('Продукт не найден: $productName'),
      );

      // Получаем состав продукта (начинки и ингредиенты)
      final productComposition = compositions
          .where((c) => c.sheetName == 'Прайс-лист' && c.entityId == product.id)
          .toList();

      for (var comp in productComposition) {
        // Проверяем, является ли ингредиент начинкой
        final filling = fillings.firstWhere(
          (f) => f.name == comp.ingredientName,
          orElse: () => null as Filling,
        );

        if (filling != null) {
          // Это начинка
          final neededKg = (comp.quantity * quantity) / 1000; // переводим в кг
          fillingsNeeded[filling.name] =
              (fillingsNeeded[filling.name] ?? 0) + neededKg;
        }
      }
    }

    return fillingsNeeded;
  }

  /// Расчёт потребности в ингредиентах
  Map<String, double> _calculateIngredientsNeeded(
      Map<String, double> fillingsNeeded) {
    final ingredientsNeeded = <String, double>{};

    for (var entry in fillingsNeeded.entries) {
      final fillingName = entry.key;
      final quantityKg = entry.value;

      // Находим начинку
      final filling = fillings.firstWhere(
        (f) => f.name == fillingName,
        orElse: () => throw Exception('Начинка не найдена: $fillingName'),
      );

      // Получаем состав начинки
      final fillingComposition = compositions
          .where(
              (c) => c.sheetName == 'Начинки' && c.entityId == filling.entityId)
          .toList();

      // Рассчитываем коэффициент (сколько порций начинки в нужном количестве)
      final multiplier = (quantityKg * 1000) / filling.quantity;

      for (var comp in fillingComposition) {
        final neededGrams = comp.quantity * multiplier;
        final neededKg = neededGrams / 1000;

        ingredientsNeeded[comp.ingredientName] =
            (ingredientsNeeded[comp.ingredientName] ?? 0) + neededKg;
      }
    }

    return ingredientsNeeded;
  }
}
