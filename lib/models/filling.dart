// lib/models/filling.dart
import 'composition.dart';

class Filling {
  final String sheetName; // Лист-родитель (обычно "Категория прайса")
  final String entityId; // ID категории в родительском листе
  final String name; // Наименование начинки
  final String? quantity; // Количество (рассчитывается автоматически)
  final String? unit; // Единица измерения

  Filling({
    required this.sheetName,
    required this.entityId,
    required this.name,
    this.quantity,
    this.unit,
  });

  // 🔥 МЕТОД РАСЧЕТА ИЗ СОСТАВА С ОКРУГЛЕНИЕМ В БОЛЬШУЮ СТОРОНУ
  static Filling calculateFromComposition(String sheetName, String entityId,
      String name, List<Composition> compositions) {
    double totalQuantity = 0.0;
    String? commonUnit;

    // 🔥 ИСПРАВЛЕНО: фильтруем по sheetName и entityId
    // Начинки хранятся как: sheetName="Категории прайса", entityId="[ID категории]"
    final fillingCompositions = compositions
        .where((comp) =>
            comp.sheetName == 'Категории прайса' && comp.entityId == entityId)
        .toList();

    if (fillingCompositions.isEmpty) {
      return Filling(sheetName: sheetName, entityId: entityId, name: name);
    }

    // Определяем единицу измерения (берем первую)
    commonUnit = fillingCompositions.first.unit;

    // Суммируем количество
    for (var comp in fillingCompositions) {
      final qty = double.tryParse(comp.quantity.replaceAll(',', '.')) ?? 0.0;
      totalQuantity += qty;
    }

    // 🔥 ОКРУГЛЕНИЕ В БОЛЬШУЮ СТОРОНУ ДО ЦЕЛОГО ЧИСЛА
    final roundedQuantity = totalQuantity.ceil().toString();

    return Filling(
      sheetName: sheetName,
      entityId: entityId,
      name: name,
      quantity: roundedQuantity,
      unit: commonUnit,
    );
  }

  factory Filling.fromMap(Map<String, dynamic> map) {
    return Filling(
      sheetName: map['Лист']?.toString() ?? '',
      entityId: map['ID сущности']?.toString() ?? '',
      name: map['Наименование']?.toString() ?? '',
      quantity: map['Количество']?.toString().isNotEmpty == true
          ? map['Количество']?.toString()
          : null,
      unit: map['Ед.изм.']?.toString().isNotEmpty == true
          ? map['Ед.изм.']?.toString()
          : null,
    );
  }

  factory Filling.fromJson(Map<String, dynamic> json) {
    return Filling(
      sheetName: json['sheetName']?.toString() ?? '',
      entityId: json['entityId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: json['quantity']?.toString(),
      unit: json['unit']?.toString(),
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toJson
  Map<String, dynamic> toJson() {
    return {
      'sheetName': sheetName ?? '',
      'entityId': entityId ?? '',
      'name': name ?? '',
      'quantity': quantity,
      'unit': unit,
    };
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toMap
  Map<String, dynamic> toMap() {
    return {
      'Лист': sheetName ?? '',
      'ID сущности': entityId ?? '',
      'Наименование': name ?? '',
      'Количество': quantity ?? '',
      'Ед.изм.': unit ?? '',
    };
  }
}
