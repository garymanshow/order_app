// lib/models/transport_condition.dart

class TransportCondition {
  final String id;
  final String sheetName; // Не используется в текущей логике, дублирует level
  final String entityId;
  final String level; // "Категории прайса" и т.д. (Колонка "Лист")
  final String description;

  TransportCondition({
    this.id = '',
    required this.sheetName,
    required this.entityId,
    required this.level,
    this.description = '',
  });

  factory TransportCondition.fromJson(Map<String, dynamic> json) {
    final levelValue = json['Лист']?.toString() ?? '';
    final entityIdValue = json['ID сущности']?.toString() ?? '';

    return TransportCondition(
      id: json['ID']?.toString() ?? 'tc_${levelValue}_$entityIdValue',
      sheetName: levelValue, // В данной модели sheetName совпадает с level
      entityId: entityIdValue,
      level: levelValue,
      description: json['Описание']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sheetName': sheetName,
      'entityId': entityId,
      'level': level,
      'description': description,
    };
  }
}
