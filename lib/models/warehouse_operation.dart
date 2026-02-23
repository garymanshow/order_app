// lib/models/warehouse_operation.dart
import '../utils/parsing_utils.dart';

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

  // 🔥 ИСПРАВЛЕНО: безопасный fromJson
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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      operation: json['operation']?.toString() ?? 'приход',
      quantity: ParsingUtils.parseDouble(json['quantity']) ?? 0.0,
      unit: json['unit']?.toString() ?? 'шт',
      date: parseDate(json['date']?.toString()) ?? DateTime.now(),
      expiryDate: parseDate(json['expiryDate']?.toString()),
      price: ParsingUtils.parseDouble(json['price']),
      supplier: json['supplier']?.toString(),
      relatedOrderId: json['relatedOrderId']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id ?? '',
      'name': name ?? '',
      'operation': operation ?? 'приход',
      'quantity': quantity,
      'unit': unit ?? 'шт',
      'date': date.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'price': price,
      'supplier': supplier,
      'relatedOrderId': relatedOrderId,
      'notes': notes,
    };
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toMap для Google Таблиц
  Map<String, dynamic> toMap() {
    return {
      'ID': id ?? '',
      'Наименование': name ?? '',
      'Операция': operation ?? 'приход',
      'Количество': quantity.toString(),
      'Ед.изм.': unit ?? 'шт',
      'Дата': date.toIso8601String(),
      'Срок годности': expiryDate?.toIso8601String() ?? '',
      'Цена': price?.toString() ?? '',
      'Поставщик': supplier ?? '',
      'Платежный документ': relatedOrderId ?? '',
      'Примечания': notes ?? '',
    };
  }

  // 🔥 ИСПРАВЛЕНО: безопасный fromMap
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
      price: double.tryParse(map['Цена']?.toString() ?? ''),
      supplier: map['Поставщик']?.toString(),
      relatedOrderId: map['Платежный документ']?.toString(),
      notes: map['Примечания']?.toString(),
    );
  }
}
