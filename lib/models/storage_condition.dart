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

  // 🔥 ИСПРАВЛЕНО: безопасное преобразование из JSON
  factory StorageCondition.fromJson(Map<String, dynamic> json) {
    return StorageCondition(
      sheetName: json['sheetName']?.toString() ?? '',
      entityId: json['entityId']?.toString() ?? '',
      storageLocation: json['storageLocation']?.toString() ?? '',
      temperature: json['temperature']?.toString() ?? '',
      humidity: json['humidity']?.toString() ?? '',
      shelfLife: json['shelfLife']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toJson
  Map<String, dynamic> toJson() {
    return {
      'sheetName': sheetName ?? '',
      'entityId': entityId ?? '',
      'storageLocation': storageLocation ?? '',
      'temperature': temperature ?? '',
      'humidity': humidity ?? '',
      'shelfLife': shelfLife ?? '',
      'unit': unit ?? '',
    };
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toMap
  Map<String, dynamic> toMap() {
    return {
      'Лист': sheetName ?? '',
      'ID сущности': entityId ?? '',
      'Место хранения': storageLocation ?? '',
      'Температура': temperature ?? '',
      'Влажность': humidity ?? '',
      'Срок': shelfLife ?? '',
      'Ед.изм.': unit ?? '',
    };
  }
}
