// lib/models/transport_condition.dart

class TransportCondition {
  final String id;
  final String level; // "Категории прайса" или "Прайс-лист"
  final String entityId; // ID Категории или Товара
  final String description; // Текст условия

  TransportCondition({
    this.id = '',
    required this.level,
    required this.entityId,
    this.description = '',
  });

  factory TransportCondition.fromJson(Map<String, dynamic> json) {
    return TransportCondition(
      id: json['id']?.toString() ?? json['ID']?.toString() ?? '',
      level: json['Лист']?.toString() ?? '',
      entityId: json['ID сущности']?.toString() ?? '',
      description: json['Описание']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
      'entityId': entityId,
      'description': description,
    };
  }
}
