// lib/models/composition.dart
// Состав
class Composition {
  final String sheetName; // Лист-родитель ("Категории прайса" или "Прайс-лист")
  final String entityId; // ID сущности в родительском листе
  final String ingredientName;
  final String quantity;
  final String unit;

  Composition({
    required this.sheetName,
    required this.entityId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
  });

  factory Composition.fromMap(Map<String, dynamic> map) {
    return Composition(
      sheetName: map['Лист']?.toString() ?? '',
      entityId: map['ID сущности']?.toString() ?? '',
      ingredientName: map['Ингредиент']?.toString() ?? '',
      quantity: map['Количество']?.toString() ?? '',
      unit: map['Ед.изм.']?.toString() ?? '',
    );
  }

  factory Composition.fromJson(Map<String, dynamic> json) {
    return Composition(
      sheetName: json['sheetName']?.toString() ?? '',
      entityId: json['entityId']?.toString() ?? '',
      ingredientName: json['ingredientName']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
    );
  }

  // 🔥 ИСПРАВЛЕНО: добавляем защиту от null в toJson
  Map<String, dynamic> toJson() {
    return {
      'sheetName': sheetName ?? '',
      'entityId': entityId ?? '',
      'ingredientName': ingredientName ?? '',
      'quantity': quantity ?? '',
      'unit': unit ?? '',
    };
  }

  // 🔥 ИСПРАВЛЕНО: добавляем защиту от null в toMap
  Map<String, dynamic> toMap() {
    return {
      'Лист': sheetName ?? '',
      'ID сущности': entityId ?? '',
      'Ингредиент': ingredientName ?? '',
      'Количество': quantity ?? '',
      'Ед.изм.': unit ?? '',
    };
  }
}
