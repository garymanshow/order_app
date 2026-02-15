// lib/services/warehouse_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // ← ДОБАВЛЕНО: для jsonDecode

import '../models/warehouse_operation.dart';
import '../services/api_service.dart';

class WarehouseService {
  final ApiService _apiService = ApiService();

  // Получить все операции склада
  Future<List<WarehouseOperation>> getAllOperations() async {
    try {
      // Получаем телефон текущего пользователя из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final authUserJson = prefs.getString('auth_user');

      if (authUserJson == null) {
        print('❌ Пользователь не авторизован');
        return [];
      }

      final userData = jsonDecode(authUserJson);
      final phone = userData['phone'] as String?;

      if (phone == null) {
        print('❌ Не найден телефон пользователя');
        return [];
      }

      // Поскольку у нас нет метода fetchWarehouseOperations,
      // получаем все данные через fetchClientData и фильтруем
      final clientDataResponse = await _apiService.fetchClientData(phone);

      if (clientDataResponse != null && clientDataResponse['success'] == true) {
        final clientData = clientDataResponse['data'];
        if (clientData is Map<String, dynamic>) {
          final warehouseOps = clientData['warehouseOperations'] as List?;
          if (warehouseOps != null) {
            return warehouseOps
                .map((op) =>
                    WarehouseOperation.fromMap(op as Map<String, dynamic>))
                .toList();
          }
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
      // Получаем телефон текущего пользователя
      final prefs = await SharedPreferences.getInstance();
      final authUserJson = prefs.getString('auth_user');

      if (authUserJson == null) {
        print('❌ Пользователь не авторизован');
        return false;
      }

      final userData = jsonDecode(authUserJson);
      final phone = userData['phone'] as String?;

      if (phone == null) {
        print('❌ Не найден телефон пользователя');
        return false;
      }

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

      // Используем существующий метод addWarehouseOperation из ApiService
      final success = await _apiService.addWarehouseOperation(
        phone: phone,
        operationData: newOperation.toMap(),
      );

      return success;
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
