// lib/models/composition.dart
import '../utils/parsing_utils.dart';

class Composition {
  final String id;
  final String sheetName; // "Начинки" или "Прайс-лист"
  final String entityId; // ID сущности
  final String ingredientName; // Название ингредиента
  final double quantity; // Количество
  final String unitSymbol; // Единица измерения

  Composition({
    required this.id,
    required this.sheetName,
    required this.entityId,
    required this.ingredientName,
    required this.quantity,
    required this.unitSymbol,
  });

  factory Composition.fromJson(Map<String, dynamic> json) {
    return Composition(
      id: ParsingUtils.safeString(json['id']) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      sheetName: ParsingUtils.safeString(json['sheetName']) ?? '',
      entityId: ParsingUtils.safeString(json['entityId']) ?? '',
      ingredientName: ParsingUtils.safeString(json['ingredientName']) ?? '',
      quantity: ParsingUtils.parseDouble(json['quantity']) ?? 0.0,
      unitSymbol: ParsingUtils.safeString(json['unitSymbol']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sheetName': sheetName,
      'entityId': entityId,
      'ingredientName': ingredientName,
      'quantity': quantity,
      'unitSymbol': unitSymbol,
    };
  }

  // Для Google Sheets
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Лист': sheetName,
      'ID сущности': entityId,
      'Ингредиент': ingredientName,
      'Количество': quantity.toString().replaceAll('.', ','),
      'Ед.изм.': unitSymbol,
    };
  }

  factory Composition.fromMap(Map<String, dynamic> map) {
    return Composition(
      id: map['ID']?.toString() ?? '',
      sheetName: map['Лист']?.toString() ?? '',
      entityId: map['ID сущности']?.toString() ?? '',
      ingredientName: map['Ингредиент']?.toString() ?? '',
      quantity: double.tryParse(
              map['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
          0.0,
      unitSymbol: map['Ед.изм.']?.toString() ?? '',
    );
  }
}
