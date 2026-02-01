// lib/models/client_category.dart
class ClientCategory {
  final String sheetName; // Всегда "Категории прайса"
  final String entityId; // ID категории из "Категории прайса"
  final String clientName; // Название клиента

  ClientCategory({
    required this.sheetName,
    required this.entityId,
    required this.clientName,
  });

  factory ClientCategory.fromMap(Map<String, dynamic> map) {
    return ClientCategory(
      sheetName: map['Лист']?.toString() ?? '',
      entityId: map['ID сущности']?.toString() ?? '',
      clientName: map['Клиент']?.toString() ?? '',
    );
  }

  factory ClientCategory.fromJson(Map<String, dynamic> json) {
    return ClientCategory(
      sheetName: json['sheetName'] as String,
      entityId: json['entityId'] as String,
      clientName: json['clientName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sheetName': sheetName,
      'entityId': entityId,
      'clientName': clientName,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'Лист': sheetName,
      'ID сущности': entityId,
      'Клиент': clientName,
    };
  }
}
