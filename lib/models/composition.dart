// lib/models/composition.dart
import '../utils/parsing_utils.dart';

/// Универсальная модель для хранения:
/// 1. Состава (Ингредиенты) - sheetName = "Состав"
/// 2. Начинок - sheetName = "Начинки"
/// 3. Условий хранения - sheetName = "Условия хранения"
/// 4. Условий транспортировки - sheetName = "Условия транспортировки"
class Composition {
  // === Неизменяемые идентификаторы ===
  final String id;
  final String sheetName; // Имя листа-источника
  final String
      level; // Уровень иерархии: "Категории прайса", "Прайс-лист", "Начинки"
  final String entityId; // ID сущности (Категории, Товара или Начинки)

  // === ИЗМЕНЯЕМЫЕ ДАННЫЕ (Убрано final) ===
  // Теперь мы можем редактировать эти поля в диалоге
  String description;
  String ingredientName;
  double quantity;
  String unitSymbol;

  // === Поля для "Условий хранения" (Убрано final) ===
  String storagePlace;
  String temperature;
  String humidity;
  String shelfLife;
  String shelfLifeUnit;

  Composition({
    required this.id,
    required this.sheetName,
    this.level = 'Прайс-лист',
    required this.entityId,
    this.description = '',
    this.ingredientName = '',
    this.quantity = 0.0,
    this.unitSymbol = '',
    this.storagePlace = '',
    this.temperature = '',
    this.humidity = '',
    this.shelfLife = '',
    this.shelfLifeUnit = '',
  });

  /// Геттер для получения отображаемого имени (универсальный)
  String get displayName =>
      description.isNotEmpty ? description : ingredientName;

  /// Геттер для форматирования условий хранения в одну строку
  String get formattedStorage {
    if (sheetName != 'Условия хранения') return description;
    List<String> parts = [];
    if (storagePlace.isNotEmpty) parts.add(storagePlace);
    if (temperature.isNotEmpty) parts.add('$temperature°C');
    if (shelfLife.isNotEmpty) parts.add('$shelfLife ${shelfLifeUnit}');
    return parts.join(' | ');
  }

  factory Composition.fromJson(Map<String, dynamic> json) {
    return Composition(
      id: ParsingUtils.safeString(json['id']) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      sheetName: ParsingUtils.safeString(json['sheetName']) ?? '',
      level: ParsingUtils.safeString(json['level']) ?? 'Прайс-лист',
      entityId: ParsingUtils.safeString(json['entityId']) ?? '',
      description: ParsingUtils.safeString(json['description']) ?? '',
      ingredientName: ParsingUtils.safeString(json['ingredientName']) ?? '',
      quantity: ParsingUtils.parseDouble(json['quantity']) ?? 0.0,
      unitSymbol: ParsingUtils.safeString(json['unitSymbol']) ?? '',
      // Новые поля
      storagePlace: ParsingUtils.safeString(json['storagePlace']) ?? '',
      temperature: ParsingUtils.safeString(json['temperature']) ?? '',
      humidity: ParsingUtils.safeString(json['humidity']) ?? '',
      shelfLife: ParsingUtils.safeString(json['shelfLife']) ?? '',
      shelfLifeUnit: ParsingUtils.safeString(json['shelfLifeUnit']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sheetName': sheetName,
      'level': level,
      'entityId': entityId,
      'description': description,
      'ingredientName': ingredientName,
      'quantity': quantity,
      'unitSymbol': unitSymbol,
      'storagePlace': storagePlace,
      'temperature': temperature,
      'humidity': humidity,
      'shelfLife': shelfLife,
      'shelfLifeUnit': shelfLifeUnit,
    };
  }

  // Для создания копии при редактировании
  Composition copyWith(
      {String? id,
      String? sheetName,
      String? level,
      String? entityId,
      String? description,
      String? ingredientName,
      double? quantity,
      String? unitSymbol,
      String? storagePlace,
      String? temperature,
      String? humidity,
      String? shelfLife,
      String? shelfLifeUnit}) {
    return Composition(
      id: id ?? this.id,
      sheetName: sheetName ?? this.sheetName,
      level: level ?? this.level,
      entityId: entityId ?? this.entityId,
      description: description ?? this.description,
      ingredientName: ingredientName ?? this.ingredientName,
      quantity: quantity ?? this.quantity,
      unitSymbol: unitSymbol ?? this.unitSymbol,
      storagePlace: storagePlace ?? this.storagePlace,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      shelfLife: shelfLife ?? this.shelfLife,
      shelfLifeUnit: shelfLifeUnit ?? this.shelfLifeUnit,
    );
  }
}
