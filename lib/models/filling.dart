// lib/models/filling.dart
import '../utils/parsing_utils.dart';
import 'composition.dart';

class Filling {
  final String
      id; // ID начинки (добавил, так как он нужен для связи с Составом)
  final String sheetName; // Имя листа: "Начинки"
  final String
      level; // Уровень: "Категории прайса" или "Прайс-лист" (из колонки "Лист")
  final String entityId; // ID сущности: ID Категории или ID Товара
  final String name; // Название начинки
  final double quantity; // Масса начинки на изделие
  final String unitSymbol;
  final List<Composition> ingredients; // Состав начинки

  Filling({
    this.id = '',
    this.sheetName = 'Начинки',
    this.level = 'Прайс-лист',
    this.entityId = '',
    required this.name,
    this.quantity = 0.0,
    this.unitSymbol = 'г',
    List<Composition>? ingredients,
  }) : ingredients = ingredients ?? const [];

  /// Геттер для получения отображаемого имени (совместимость с Composition)
  String get displayName => name;

  /// Общий вес начинки в граммах
  double get totalWeightGrams {
    if (unitSymbol == 'г') return quantity;
    if (unitSymbol == 'кг') return quantity * 1000;
    return quantity;
  }

  /// Парсинг из JSON, который прислал GAS
  factory Filling.fromJson(Map<String, dynamic> json) {
    return Filling(
      id: json['id']?.toString() ?? json['ID']?.toString() ?? '',
      sheetName: json['sheetName']?.toString() ?? 'Начинки',
      level: json['Лист']?.toString() ?? 'Прайс-лист',
      entityId:
          json['ID сущности']?.toString() ?? json['entityId']?.toString() ?? '',
      name: json['Наименование']?.toString() ?? json['name']?.toString() ?? '',
      quantity:
          ParsingUtils.parseDouble(json['Количество'] ?? json['quantity']) ??
              0.0,
      unitSymbol:
          json['Ед.изм.']?.toString() ?? json['unitSymbol']?.toString() ?? 'г',
      ingredients: [], // Инициализируем пустым, заполним позже на уровне ClientData
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sheetName': sheetName,
      'level': level,
      'entityId': entityId,
      'name': name,
      'quantity': quantity,
      'unitSymbol': unitSymbol,
    };
  }

  // Метод для создания копии с обновленным списком ингредиентов
  Filling copyWith({
    String? id,
    String? sheetName,
    String? level,
    String? entityId,
    String? name,
    double? quantity,
    String? unitSymbol,
    List<Composition>? ingredients,
  }) {
    return Filling(
      id: id ?? this.id,
      sheetName: sheetName ?? this.sheetName,
      level: level ?? this.level,
      entityId: entityId ?? this.entityId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitSymbol: unitSymbol ?? this.unitSymbol,
      ingredients: ingredients ?? this.ingredients,
    );
  }
}
