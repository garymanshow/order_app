// lib/models/storage_condition.dart

class StorageCondition {
  final String id; // Генерируемый ID (или ID строки, если добавите колонку)
  final String level; // Уровень: "Категории прайса", "Начинки" (Колонка "Лист")
  final String entityId; // ID Категории или Начинки (Колонка "ID сущности")

  // Данные
  final String storageLocation; // Колонка "Место хранения"
  final String temperature; // Колонка "Температура"
  final String humidity; // Колонка "Влажность"
  final String shelfLife; // Колонка "Срок"
  final String unit; // Колонка "Ед.изм."

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

  factory StorageCondition.fromJson(Map<String, dynamic> json) {
    // === ЛОГИКА ЧТЕНИЯ ИЗ ВАШЕЙ ТАБЛИЦЫ ===

    // 1. Колонка "Лист" -> это level ("Категории прайса", "Начинки")
    final levelValue = json['Лист']?.toString() ?? '';

    // 2. Колонка "ID сущности" -> это entityId (2, 7, 1...)
    final entityIdValue = json['ID сущности']?.toString() ?? '';

    // 3. Генерируем уникальный ID, если его нет в таблице
    // Используем комбинацию level + entityId + место, чтобы ID был уникальным
    final generatedId =
        'sc_${levelValue}_${entityIdValue}_${json['Место хранения']}';

    return StorageCondition(
      id: json['ID']?.toString() ??
          generatedId, // Если колонки ID нет, используем сгенерированный
      level: levelValue,
      entityId: entityIdValue,
      storageLocation: json['Место хранения']?.toString() ?? '',
      temperature: json['Температура']?.toString() ?? '',
      humidity: json['Влажность']?.toString() ?? '',
      shelfLife: json['Срок']?.toString() ?? '',
      unit: json['Ед.изм.']?.toString() ?? '',
    );
  }

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

  String get formatted {
    List<String> parts = [];
    if (storageLocation.isNotEmpty) parts.add(storageLocation);
    if (temperature.isNotEmpty) parts.add('$temperature°C');
    if (shelfLife.isNotEmpty) parts.add('$shelfLife $unit');
    return parts.join(' | ');
  }
}
