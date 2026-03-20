// lib/models/filling.dart
import '../utils/parsing_utils.dart';
import 'composition.dart';

class Filling {
  final String sheetName; // "Начинки" или "Категории прайса"
  final String entityId; // ID начинки
  final String name; // Название начинки
  final double quantity; // Количество начинки на порцию
  final String unitSymbol; // Единица измерения
  final List<Composition> ingredients; // Состав начинки

  Filling({
    required this.sheetName,
    required this.entityId,
    required this.name,
    required this.quantity,
    required this.unitSymbol,
    required this.ingredients,
  });

  // Общий вес начинки в граммах
  double get totalWeightGrams {
    if (unitSymbol == 'г') return quantity;
    if (unitSymbol == 'кг') return quantity * 1000;
    return quantity;
  }

  factory Filling.fromJson(Map<String, dynamic> json) {
    return Filling(
      sheetName: ParsingUtils.safeString(json['sheetName']) ?? '',
      entityId: ParsingUtils.safeString(json['entityId']) ?? '',
      name: ParsingUtils.safeString(json['name']) ?? '',
      quantity: ParsingUtils.parseDouble(json['quantity']) ?? 0.0,
      unitSymbol: ParsingUtils.safeString(json['unitSymbol']) ?? 'г',
      ingredients: [], // будут заполняться отдельно
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sheetName': sheetName,
      'entityId': entityId,
      'name': name,
      'quantity': quantity,
      'unitSymbol': unitSymbol,
    };
  }

  // Для Google Sheets
  Map<String, dynamic> toMap() {
    return {
      'Лист': sheetName,
      'ID сущности': entityId,
      'Наименование': name,
      'Количество': quantity.toString().replaceAll('.', ','),
      'Ед.изм': unitSymbol,
    };
  }

  factory Filling.fromMap(Map<String, dynamic> map) {
    return Filling(
      sheetName: map['Лист']?.toString() ?? '',
      entityId: map['ID сущности']?.toString() ?? '',
      name: map['Наименование']?.toString() ?? '',
      quantity: double.tryParse(
              map['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
          0.0,
      unitSymbol: map['Ед.изм']?.toString() ?? 'г',
      ingredients: [],
    );
  }
}
