// lib/models/warehouse_operation.dart
class WarehouseOperation {
  final String id;
  final String name; // Наименование (ингредиент или упаковка)
  final String operation; // 'приход' или 'списание'
  final double quantity; // Количество
  final String unit; // Единица измерения
  final DateTime date; // Дата операции
  final DateTime? expiryDate; // Срок годности (только для ингредиентов)
  final double? price; // Цена за единицу (только для приходов)
  final String? supplier; // Поставщик (только для приходов)
  final String? relatedOrderId; // Связанный заказ (только для списаний)
  final String? notes; // Примечания

  WarehouseOperation({
    required this.id,
    required this.name,
    required this.operation,
    required this.quantity,
    required this.unit,
    required this.date,
    this.expiryDate,
    this.price,
    this.supplier,
    this.relatedOrderId,
    this.notes,
  });

  factory WarehouseOperation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return WarehouseOperation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      operation: json['operation'] as String? ?? 'приход',
      quantity: json['quantity'] as double? ?? 0.0,
      unit: json['unit'] as String? ?? 'шт',
      date: parseDate(json['date'] as String? ?? '') ?? DateTime.now(),
      expiryDate: parseDate(json['expiryDate'] as String?),
      price: json['price'] as double?,
      supplier: json['supplier'] as String?,
      relatedOrderId: json['relatedOrderId'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'operation': operation,
      'quantity': quantity,
      'unit': unit,
      'date': date.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'price': price,
      'supplier': supplier,
      'relatedOrderId': relatedOrderId,
      'notes': notes,
    };
  }

  // Для Google Таблиц
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Наименование': name,
      'Операция': operation,
      'Количество': quantity.toString(),
      'Ед.изм.': unit,
      'Дата': date.toIso8601String(),
      'Срок годности': expiryDate?.toIso8601String() ?? '',
      'Цена': price?.toString() ?? '',
      'Поставщик': supplier ?? '',
      'Платежный документ': relatedOrderId ?? '',
      'Примечания': notes ?? '',
    };
  }

  factory WarehouseOperation.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return WarehouseOperation(
      id: map['ID']?.toString() ?? '',
      name: map['Наименование']?.toString() ?? '',
      operation: map['Операция']?.toString() ?? 'приход',
      quantity: double.tryParse(map['Количество']?.toString() ?? '0') ?? 0.0,
      unit: map['Ед.изм.']?.toString() ?? 'шт',
      date: parseDate(map['Дата']?.toString()) ?? DateTime.now(),
      expiryDate: parseDate(map['Срок годности']?.toString()),
      price: double.tryParse(map['Цена']?.toString() ?? '0'),
      supplier: map['Поставщик']?.toString(),
      relatedOrderId: map['Платежный документ']?.toString(),
      notes: map['Примечания']?.toString(),
    );
  }
}
