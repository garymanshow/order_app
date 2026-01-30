// lib/models/storage_condition.dart
// Условия хранения
class StorageCondition {
  final String sheetName; // Название листа-родителя
  final String entityId; // ID сущности в родительском листе
  final String storageLocation;
  final String temperature;
  final String humidity;
  final String shelfLife;
  final String unit;

  StorageCondition({
    required this.sheetName,
    required this.entityId,
    required this.storageLocation,
    required this.temperature,
    required this.humidity,
    required this.shelfLife,
    required this.unit,
  });

  factory StorageCondition.fromMap(Map<String, dynamic> map) {
    return StorageCondition(
      sheetName: map['Лист']?.toString() ?? '',
      entityId: map['ID сущности']?.toString() ?? '',
      storageLocation: map['Место хранения']?.toString() ?? '',
      temperature: map['Температура']?.toString() ?? '',
      humidity: map['Влажность']?.toString() ?? '',
      shelfLife: map['Срок']?.toString() ?? '',
      unit: map['Ед.изм.']?.toString() ?? '',
    );
  }

  factory StorageCondition.fromJson(Map<String, dynamic> json) {
    return StorageCondition(
      sheetName: json['sheetName'] as String,
      entityId: json['entityId'] as String,
      storageLocation: json['storageLocation'] as String,
      temperature: json['temperature'] as String,
      humidity: json['humidity'] as String,
      shelfLife: json['shelfLife'] as String,
      unit: json['unit'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sheetName': sheetName,
      'entityId': entityId,
      'storageLocation': storageLocation,
      'temperature': temperature,
      'humidity': humidity,
      'shelfLife': shelfLife,
      'unit': unit,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'Лист': sheetName,
      'ID сущности': entityId,
      'Место хранения': storageLocation,
      'Температура': temperature,
      'Влажность': humidity,
      'Срок': shelfLife,
      'Ед.изм.': unit,
    };
  }
}
