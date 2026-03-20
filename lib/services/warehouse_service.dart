// lib/services/warehouse_service.dart
import 'dart:convert';
import '../models/unit_of_measure.dart';
import '../models/warehouse_operation.dart';
// Убираем несуществующие импорты
// import '../models/unit_of_measure.dart';
// import '../services/unit_converter_service.dart';
import 'api_service.dart';

class WarehouseService {
  final ApiService _apiService;

  WarehouseService(this._apiService);

  // 🔥 ПОЛУЧЕНИЕ ВСЕХ ОПЕРАЦИЙ СО СКЛАДА
  Future<List<WarehouseOperation>> getOperations() async {
    try {
      final response = await _apiService.fetchWarehouseOperations();

      if (response != null && response['success'] == true) {
        final List<dynamic> operationsData = response['operations'] ?? [];
        return operationsData
            .map((json) => WarehouseOperation.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      print('❌ Ошибка получения операций склада: $e');
      return [];
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ОПЕРАЦИЙ ПО ФИЛЬТРАМ
  Future<List<WarehouseOperation>> getOperationsFiltered({
    String? ingredientName,
    String? operation,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final filters = {
        if (ingredientName != null) 'ingredientName': ingredientName,
        if (operation != null) 'operation': operation,
        if (fromDate != null) 'fromDate': _formatDate(fromDate),
        if (toDate != null) 'toDate': _formatDate(toDate),
      };

      final response =
          await _apiService.fetchWarehouseOperationsFiltered(filters);

      if (response != null && response['success'] == true) {
        final List<dynamic> operationsData = response['operations'] ?? [];
        return operationsData
            .map((json) => WarehouseOperation.fromJson(json))
            .toList();
      }

      return [];
    } catch (e) {
      print('❌ Ошибка получения отфильтрованных операций: $e');
      return [];
    }
  }

  // 🔥 ДОБАВЛЕНИЕ ОПЕРАЦИИ
  Future<bool> addOperation(WarehouseOperation operation) async {
    try {
      // Метод toSheetRow должен быть определен в модели WarehouseOperation
      final operationData = operation.toSheetRow();

      final response = await _apiService.addWarehouseOperation(
        phone: '', // TODO: получить из контекста
        operationData: operationData,
      );

      return response;
    } catch (e) {
      print('❌ Ошибка добавления операции: $e');
      return false;
    }
  }

  // 🔥 ДОБАВЛЕНИЕ НЕСКОЛЬКИХ ОПЕРАЦИЙ
  Future<bool> addOperations(List<WarehouseOperation> operations) async {
    try {
      final operationsData = operations.map((op) => op.toSheetRow()).toList();

      final response = await _apiService.addWarehouseOperations(operationsData);

      return response;
    } catch (e) {
      print('❌ Ошибка добавления операций: $e');
      return false;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ОСТАТКА ПО ИНГРЕДИЕНТУ
  Future<double> getStockBalance(String ingredientName, String unit) async {
    final operations = await getOperations();

    double balance = 0;

    for (var op in operations) {
      if (op.name == ingredientName && op.unit == unit) {
        if (op.operation.toLowerCase() == 'приход') {
          balance += op.quantity;
        } else if (op.operation.toLowerCase() == 'списание') {
          balance -= op.quantity;
        }
      }
    }

    return balance;
  }

  // 🔥 ПОЛУЧЕНИЕ УВЕДОМЛЕНИЙ О НЕДОСТАТКЕ
  Future<List<String>> getLowStockAlerts() async {
    try {
      final operations = await getOperations();

      // Рассчитываем остатки
      final balances = <String, double>{};

      for (var op in operations) {
        final key = '${op.name}_${op.unit}';
        if (op.operation.toLowerCase() == 'приход') {
          balances[key] = (balances[key] ?? 0) + op.quantity;
        } else if (op.operation.toLowerCase() == 'списание') {
          balances[key] = (balances[key] ?? 0) - op.quantity;
        }
      }

      // Формируем уведомления
      final alerts = <String>[];
      for (var entry in balances.entries) {
        final parts = entry.key.split('_');
        final name = parts[0];
        final unit = parts.length > 1 ? parts[1] : '';

        // Проверяем пороговые значения в зависимости от единицы измерения
        final threshold = unit == 'шт' ? 10 : 1.0; // 10 штук или 1 кг/л

        if (entry.value < threshold) {
          alerts.add('$name: осталось ${entry.value.toStringAsFixed(2)} $unit');
        }
      }

      return alerts;
    } catch (e) {
      print('❌ Ошибка получения уведомлений: $e');
      return [];
    }
  }

  // 🔥 ПОЛУЧЕНИЕ ВСЕХ ИНГРЕДИЕНТОВ (уникальных)
  Future<List<String>> getAllIngredients() async {
    try {
      final operations = await getOperations();

      // Получаем уникальные названия ингредиентов
      final ingredients = operations.map((op) => op.name).toSet().toList();

      return ingredients;
    } catch (e) {
      print('❌ Ошибка получения списка ингредиентов: $e');
      return [];
    }
  }

  // Форматирование даты
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
