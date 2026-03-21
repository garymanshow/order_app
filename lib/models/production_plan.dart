// lib/models/production_plan.dart
class ProductionPlan {
  final DateTime date;
  final Map<String, int> productsNeeded; // продукт -> количество (шт)
  final Map<String, double> fillingsNeeded; // начинка -> количество (кг)
  final Map<String, double>
      ingredientsNeeded; // ингредиент -> количество (кг/л)
  final Map<String, double> currentStock; // текущие остатки
  final Map<String, double> shortage; // чего не хватает

  ProductionPlan({
    required this.date,
    required this.productsNeeded,
    required this.fillingsNeeded,
    required this.ingredientsNeeded,
    required this.currentStock,
    required this.shortage,
  });

  bool get hasShortage => shortage.isNotEmpty;
  int get totalProducts => productsNeeded.values.fold(0, (sum, q) => sum + q);
}
