// lib/services/warehouse_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/warehouse_operation.dart';
import '../models/product_category.dart';

class WarehouseService {
  // Получить все операции склада
  Future<List<WarehouseOperation>> getAllOperations() async {
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['APPS_SCRIPT_URL']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'fetchWarehouseOperations',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['operations'] != null) {
          return (data['operations'] as List)
              .map((op) =>
                  WarehouseOperation.fromMap(op as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Ошибка загрузки операций склада: $e');
      return [];
    }
  }

  // Рассчитать остаток по наименованию
  double calculateStockBalance(
      String itemName, List<WarehouseOperation> operations) {
    double balance = 0.0;

    for (var op in operations) {
      if (op.name == itemName) {
        if (op.operation == 'приход') {
          balance += op.quantity;
        } else if (op.operation == 'списание') {
          balance -= op.quantity;
        }
      }
    }

    return balance;
  }

  // Получить все уникальные наименования
  List<String> getUniqueItemNames(List<WarehouseOperation> operations) {
    final names = <String>{};
    for (var op in operations) {
      names.add(op.name);
    }
    return names.toList()..sort();
  }

  // Проверить просроченные ингредиенты и автоматически списать
  List<WarehouseOperation> getExpiredDeductions(
      List<WarehouseOperation> operations) {
    final now = DateTime.now();
    final expiredDeductions = <WarehouseOperation>[];

    // Группируем приходы по наименованию с указанием срока годности
    final Map<String, List<WarehouseOperation>> incomingByItem = {};

    for (var op in operations) {
      if (op.operation == 'приход' && op.expiryDate != null) {
        if (!incomingByItem.containsKey(op.name)) {
          incomingByItem[op.name] = [];
        }
        incomingByItem[op.name]!.add(op);
      }
    }

    // Для каждого наименования проверяем просроченные партии
    for (var entry in incomingByItem.entries) {
      final itemName = entry.key;
      final incomingOps = entry.value;

      double totalIncoming = 0;
      double totalDeducted = 0;

      // Считаем общее количество прихода
      for (var op in incomingOps) {
        if (op.expiryDate != null && op.expiryDate!.isBefore(now)) {
          totalIncoming += op.quantity;
        }
      }

      // Считаем уже списанное количество
      for (var op in operations) {
        if (op.name == itemName && op.operation == 'списание') {
          totalDeducted += op.quantity;
        }
      }

      final availableForDeduction = totalIncoming - totalDeducted;
      if (availableForDeduction > 0) {
        // Создаем операцию списания просроченного
        expiredDeductions.add(WarehouseOperation(
          id: 'auto_expired_${DateTime.now().millisecondsSinceEpoch}',
          name: itemName,
          operation: 'списание',
          quantity: availableForDeduction,
          unit: incomingOps.first.unit,
          date: now,
          notes: 'Автоматическое списание просроченного товара',
        ));
      }
    }

    return expiredDeductions;
  }

  // Добавить операцию прихода
  Future<bool> addReceipt({
    required String name,
    required double quantity,
    required String unit,
    DateTime? expiryDate,
    double? price,
    String? supplier,
    String? notes,
  }) async {
    try {
      final newOperation = WarehouseOperation(
        id: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        operation: 'приход',
        quantity: quantity,
        unit: unit,
        date: DateTime.now(),
        expiryDate: expiryDate,
        price: price,
        supplier: supplier,
        notes: notes,
      );

      final response = await http.post(
        Uri.parse('${dotenv.env['APPS_SCRIPT_URL']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'addWarehouseOperation',
          'operation': newOperation.toMap(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка добавления прихода: $e');
      return false;
    }
  }

  // Получить статус количества (для цветовой индикации)
  String getQuantityStatus(double balance, double minStock) {
    if (balance <= 0) return 'empty';
    if (balance <= minStock) return 'low';
    return 'normal';
  }

  // Получить статус срока годности
  String getExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) return 'none'; // упаковка

    final now = DateTime.now();
    final daysLeft = expiryDate.difference(now).inDays;

    if (daysLeft < 0) return 'expired';
    if (daysLeft <= 7) return 'warning'; // 7 дней порог
    return 'normal';
  }
}
