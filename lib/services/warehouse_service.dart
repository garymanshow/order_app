// lib/services/warehouse_service.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/warehouse_operation.dart';
import '../models/employee.dart';
import '../providers/auth_provider.dart';
import 'api_service.dart';

class WarehouseService {
  final ApiService _apiService;

  WarehouseService(this._apiService);

  // =======================================================================
  // 🔥 БАЗОВЫЕ ВЕЩИ: КОНТЕКСТ И ДАТЫ
  // =======================================================================

  Future<String?> _getCurrentUserPhone(BuildContext? context) async {
    if (context == null) return null;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user is Employee && user.phone != null) {
        return user.phone;
      }
    } catch (e) {
      print('⚠️ Ошибка получения телефона пользователя: $e');
    }

    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  // =======================================================================
  // 🔥 ПОЛУЧЕНИЕ ДАННЫХ (ВАШИ ОРИГИНАЛЬНЫЕ МЕТОДЫ)
  // =======================================================================

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

  Future<List<String>> getAllIngredients() async {
    try {
      final operations = await getOperations();
      final ingredients = operations.map((op) => op.name).toSet().toList();
      return ingredients;
    } catch (e) {
      print('❌ Ошибка получения списка ингредиентов: $e');
      return [];
    }
  }

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

  Future<Map<String, double>> getAllBalances() async {
    final operations = await getOperations();
    final balances = <String, double>{};

    for (var op in operations) {
      final key = '${op.name}_${op.unit}';
      if (op.operation.toLowerCase() == 'приход') {
        balances[key] = (balances[key] ?? 0) + op.quantity;
      } else if (op.operation.toLowerCase() == 'списание') {
        balances[key] = (balances[key] ?? 0) - op.quantity;
      }
    }

    return balances;
  }

  Future<List<String>> getLowStockAlerts() async {
    try {
      final operations = await getOperations();
      final balances = <String, double>{};

      for (var op in operations) {
        final key = '${op.name}_${op.unit}';
        if (op.operation.toLowerCase() == 'приход') {
          balances[key] = (balances[key] ?? 0) + op.quantity;
        } else if (op.operation.toLowerCase() == 'списание') {
          balances[key] = (balances[key] ?? 0) - op.quantity;
        }
      }

      final alerts = <String>[];
      for (var entry in balances.entries) {
        final parts = entry.key.split('_');
        final name = parts[0];
        final unit = parts.length > 1 ? parts[1] : '';
        final threshold = unit == 'шт' ? 10 : 1.0;

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

  // =======================================================================
  // 🔥 ЗАПИСЬ ДАННЫХ (ВАШИ ОРИГИНАЛЬНЫЕ МЕТОДЫ)
  // =======================================================================

  Future<bool> addOperation(
    WarehouseOperation operation, {
    BuildContext? context,
  }) async {
    try {
      String? phone;
      if (context != null) {
        phone = await _getCurrentUserPhone(context);
      }
      phone ??= 'unknown';

      final operationData = operation.toSheetRow();

      final response = await _apiService.addWarehouseOperation(
        phone: phone,
        operationData: operationData,
      );

      return response;
    } catch (e) {
      print('❌ Ошибка добавления операции: $e');
      return false;
    }
  }

  Future<bool> addOperations(
    List<WarehouseOperation> operations, {
    BuildContext? context,
  }) async {
    try {
      String? phone;
      if (context != null) {
        phone = await _getCurrentUserPhone(context);
      }
      phone ??= 'unknown';

      final operationsData = operations.map((op) => op.toSheetRow()).toList();

      final response = await _apiService.addWarehouseOperations(operationsData);

      return response;
    } catch (e) {
      print('❌ Ошибка добавления операций: $e');
      return false;
    }
  }

  // =======================================================================
  // 🚀 НОВАЯ ЛОГИКА: ЯЙЦА, ТАРА, АВТОМАТИЗАЦИЯ
  // =======================================================================

  /// 1. КОНСТАНТНАЯ ФИЛЬТРАЦИЯ ЯИЦ
  /// Создает операцию списания с автоматическим округлением до целого яйца.
  /// [knownBatchSize] можно не указывать, метод определит по названию (50г куриное, 15г перепелиное).
  WarehouseOperation createEggWriteOff({
    required String id,
    required String eggName,
    required double requiredGrams,
    required DateTime date,
    String? relatedOrderId,
    double? knownBatchSize,
  }) {
    // Автоопределение веса, если не передали явно
    final double batch = knownBatchSize ??
        (eggName.toLowerCase().contains('перепел') ? 15.0 : 50.0);

    // Математика: требуемое / вес 1 яйца = кол-во (с округлением ВВЕРХ)
    final int unitsToWriteOff = (requiredGrams / batch).ceil();
    final double actualGrams = unitsToWriteOff * batch;

    return WarehouseOperation(
      id: id,
      name: eggName,
      operation: 'списание',
      quantity: actualGrams, // Списываем кратное значение (50, 100, 150...)
      unit: 'г',
      date: date,
      relatedOrderId: relatedOrderId,
      notes:
          'Автосписание: требовалось ${requiredGrams.toStringAsFixed(1)}г, списано $actualGramsг ($unitsToWriteOff шт)',
    );
  }

  /// 2. УМНЫЙ ФИЛЬТР ТАРЫ
  /// Возвращает чистый список названий упаковок (без муки и яиц) для выпадающего меню.
  Future<List<String>> getPackagingNamesForDropdown() async {
    try {
      final operations = await getOperations();

      // Черный список: сырье в штуках, которое тарой не является
      final excludedKeywords = ['яйцо', 'яйца', 'палочка'];

      final packagingNames = operations
          .where((op) {
            final nameLower = op.name.toLowerCase();
            final unitLower = op.unit.toLowerCase();

            return unitLower == 'шт' &&
                !excludedKeywords.any((ex) => nameLower.contains(ex));
          })
          .map((op) => op.name)
          .toSet()
          .toList();

      return packagingNames;
    } catch (e) {
      print('❌ Ошибка получения списка тары: $e');
      return [];
    }
  }

  /// 3. АВТОМАТИЧЕСКОЕ СПИСАНИЕ ТАРЫ ПРИ СМЕНЕ СТАТУСА ЗАКАЗА
  /// Принимает товары из заказа и их настройки из Категорий прайса.
  /// Возвращает список операций списания готовых к отправке в Google Таблицы.
  Future<List<WarehouseOperation>> generatePackagingWriteOffs({
    required Map<String, int> orderItems, // Пример: {"Моти": 7, "Брауни": 2}
    required Map<String, Map<String, dynamic>>
        categorySettings, // Пример: {"Моти": {"packagingName": "Контейнер", "batchSize": 5}}
    required DateTime date,
    required String relatedOrderId,
  }) async {
    final writeOffs = <WarehouseOperation>[];

    for (var entry in orderItems.entries) {
      final productName = entry.key;
      final orderedQty = entry.value;

      final settings = categorySettings[productName];
      if (settings == null) continue;

      final String packagingName = settings['packagingName'] ?? '';
      final int batchSize =
          settings['batchSize'] ?? 1; // Если не указано, значит 1 шт в упаковке

      if (packagingName.isEmpty) continue;

      // Магия математики: 7 моти / 5 в коробке = 1.4 -> Округляем ВВЕРХ = 2 коробки
      final int packagesNeeded = (orderedQty / batchSize).ceil();

      writeOffs.add(WarehouseOperation(
        id: 'pack_${relatedOrderId}_$productName',
        name: packagingName,
        operation: 'списание',
        quantity: packagesNeeded.toDouble(),
        unit: 'шт',
        date: date,
        relatedOrderId: relatedOrderId,
        notes:
            'Автосписание тары: $productName ($orderedQty шт, кратн. $batchSize)',
      ));
    }

    return writeOffs;
  }
}
