// lib/models/storage_condition.dart

class StorageCondition {
  final String id; // ID строки (для уникальности)
  final String
      level; // Уровень: "Категории прайса" или "Прайс-лист" (колонка "Лист")
  final String entityId; // ID Категории или Товара (колонка "ID сущности")

  // Данные
  final String storageLocation; // Место хранения
  final String temperature; // Температура
  final String humidity; // Влажность
  final String shelfLife; // Срок
  final String unit; // Ед.изм.

  StorageCondition({
    this.id = '',
    required this.level,
    required this.entityId,
    this.storageLocation = '',
    this.temperature = '',
    this.humidity = '',
    this.shelfLife = '',
    this.unit = '',
  });

  /// Парсинг из JSON, который прислал GAS
  factory StorageCondition.fromJson(Map<String, dynamic> json) {
    return StorageCondition(
      id: json['id']?.toString() ?? json['ID']?.toString() ?? '',
      level: json['Лист']?.toString() ?? '', // Берем из колонки "Лист"
      entityId: json['ID сущности']?.toString() ?? '',
      storageLocation: json['Место хранения']?.toString() ?? '',
      temperature: json['Температура']?.toString() ?? '',
      humidity: json['Влажность']?.toString() ?? '',
      shelfLife: json['Срок']?.toString() ?? '',
      unit: json['Ед.изм.']?.toString() ?? '',
    );
  }

  /// Для сохранения в Hive
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
      'entityId': entityId,
      'storageLocation': storageLocation,
      'temperature': temperature,
      'humidity': humidity,
      'shelfLife': shelfLife,
      'unit': unit,
    };
  }

  /// Красивое отображение одной строкой
  String get formatted {
    List<String> parts = [];
    if (storageLocation.isNotEmpty) parts.add(storageLocation);
    if (temperature.isNotEmpty) parts.add('$temperature°C');
    if (shelfLife.isNotEmpty) parts.add('$shelfLife $unit');
    return parts.join(' | ');
  }
}
