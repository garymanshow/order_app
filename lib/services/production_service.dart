// lib/services/production_service.dart
import '../models/order.dart';
import '../models/production_operation.dart';
import '../models/warehouse_operation.dart';
import 'api_service.dart';
import 'warehouse_service.dart';
import 'unit_converter_service.dart';

class ProductionRequirement {
  final String ingredientName;
  final double metricQuantity;
  final String unit;
  final double originalQuantity;
  final String originalUnit;
  final String sourceType;
  final String sourceName;
  final int sourceId;

  ProductionRequirement({
    required this.ingredientName,
    required this.metricQuantity,
    required this.unit,
    required this.originalQuantity,
    required this.originalUnit,
    required this.sourceType,
    required this.sourceName,
    required this.sourceId,
  });
}

class ProductionStats {
  final double totalFillingsProduced; // кг
  final int totalProductsProduced; // шт
  final int totalShipped; // шт
  final int todayPlan; // шт
  final Map<String, double> fillingsByDay; // производство начинок по дням
  final Map<String, int> productsByDay; // выпуск продукции по дням

  ProductionStats({
    required this.totalFillingsProduced,
    required this.totalProductsProduced,
    required this.totalShipped,
    required this.todayPlan,
    required this.fillingsByDay,
    required this.productsByDay,
  });

  factory ProductionStats.fromJson(Map<String, dynamic> json) {
    return ProductionStats(
      totalFillingsProduced:
          (json['totalFillingsProduced'] as num?)?.toDouble() ?? 0,
      totalProductsProduced: json['totalProductsProduced'] as int? ?? 0,
      totalShipped: json['totalShipped'] as int? ?? 0,
      todayPlan: json['todayPlan'] as int? ?? 0,
      fillingsByDay: Map<String, double>.from(json['fillingsByDay'] ?? {}),
      productsByDay: Map<String, int>.from(json['productsByDay'] ?? {}),
    );
  }
}

class ProductionService {
  final ApiService _apiService;
  final WarehouseService _warehouseService;

  // Кэш для остатков
  Map<String, double> _fillingBalance = {}; // начинки: ID -> остаток в кг
  Map<String, int> _productBalance =
      {}; // готовая продукция: ID -> остаток в шт
  final Map<String, String> _fillingNames = {}; // начинки: ID -> название
  final Map<String, String> _productNames = {}; // продукты: ID -> название

  ProductionService({
    required ApiService apiService,
    required WarehouseService warehouseService,
  })  : _apiService = apiService,
        _warehouseService = warehouseService;

  // Инициализация - загрузка всех данных
  Future<void> initialize() async {
    try {
      print('🔄 Инициализация ProductionService...');

      // Загружаем все производственные операции
      final operations = await _apiService.fetchProductionOperations();

      // Загружаем справочники
      await _loadDictionaries();

      // Сбрасываем остатки
      _fillingBalance = {};
      _productBalance = {};

      if (operations != null) {
        // Сортируем по дате
        operations.sort((a, b) {
          final dateA = _parseDate(a['Дата']);
          final dateB = _parseDate(b['Дата']);
          return dateA.compareTo(dateB);
        });

        // Применяем каждую операцию
        for (var op in operations) {
          final sheet = op['Лист']?.toString() ?? '';
          final entityId =
              int.tryParse(op['ID сущности']?.toString() ?? '0') ?? 0;
          final quantity = double.tryParse(
                  op['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
              0;
          final unit = op['Ед.изм']?.toString();

          final record = ProductionOperation(
            sheet: sheet,
            entityId: entityId,
            name: op['Наименование'] ?? '',
            quantity: quantity,
            unit: unit,
            date: _parseDate(op['Дата']),
          );

          await _applyProductionRecord(record);
        }
      }

      print('✅ ProductionService инициализирован');
      print('   Начинок: ${_fillingBalance.length} видов');
      print('   Готовой продукции: ${_productBalance.length} видов');
    } catch (e) {
      print('❌ Ошибка инициализации ProductionService: $e');
    }
  }

  // Загрузка справочников
  Future<void> _loadDictionaries() async {
    try {
      // Загружаем начинки
      final fillings = await _apiService.fetchFillings();
      if (fillings != null) {
        for (var f in fillings) {
          final id = f['ID']?.toString() ?? '';
          final name = f['Наименование']?.toString() ?? '';
          _fillingNames[id] = name;
        }
      }

      // Загружаем продукты
      final products = await _apiService.fetchProducts();
      if (products != null) {
        for (var p in products) {
          final id = p['ID']?.toString() ?? '';
          final name = p['Название']?.toString() ?? '';
          _productNames[id] = name;
        }
      }
    } catch (e) {
      print('Ошибка загрузки справочников: $e');
    }
  }

  // Применение производственной записи
  Future<void> _applyProductionRecord(ProductionOperation record) async {
    if (record.isFilling && record.isProduction) {
      // Производство начинки
      final key = 'filling_${record.entityId}';
      _fillingBalance[key] = (_fillingBalance[key] ?? 0) + record.quantity;
    } else if (record.isProduct && record.isFinished) {
      // Выпуск готовой продукции
      final key = 'product_${record.entityId}';
      _productBalance[key] =
          (_productBalance[key] ?? 0) + record.quantity.toInt();

      // Получаем состав продукта для списания начинок
      final composition =
          await _apiService.getCompositionForProduct(record.entityId);

      if (composition != null) {
        for (var item in composition) {
          final filling =
              await _apiService.getFillingByName(item['Ингредиент'] ?? '');

          if (filling != null) {
            // Это начинка - уменьшаем ее остаток
            final fillingId = filling['ID']?.toString() ?? '';
            final fillingKey = 'filling_$fillingId';
            final quantity = double.tryParse(
                    item['Количество']?.toString().replaceAll(',', '.') ??
                        '0') ??
                0;
            final spentQuantity =
                (quantity * record.quantity) / 1000; // переводим в кг

            _fillingBalance[fillingKey] =
                (_fillingBalance[fillingKey] ?? 0) - spentQuantity;
          }
        }
      }
    }
  }

  // ==================== ПРОИЗВОДСТВО НАЧИНОК ====================

  // Производство начинки
  Future<bool> produceFilling({
    required int fillingId,
    required String fillingName,
    required double quantityKg,
    required DateTime date,
  }) async {
    print('🏭 Производство начинки: $fillingName $quantityKg кг');

    try {
      // Получаем состав начинки
      final composition = await _apiService.getCompositionForFilling(fillingId);

      if (composition == null || composition.isEmpty) {
        print('❌ Состав начинки не найден');
        return false;
      }

      // Получаем вес порции начинки
      final filling = await _apiService.getFilling(fillingId);
      if (filling == null) {
        print('❌ Начинка не найдена');
        return false;
      }

      final portionWeight = double.tryParse(
              filling['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
          0;
      if (portionWeight <= 0) {
        print('❌ Не указан вес порции начинки');
        return false;
      }

      // Рассчитываем коэффициент
      final multiplier = (quantityKg * 1000) / portionWeight;

      print('   Вес порции: $portionWeight г');
      print('   Коэффициент: $multiplier');

      // Списание ингредиентов
      for (var item in composition) {
        final ingredientName = item['Ингредиент']?.toString() ?? '';
        final itemQuantity = double.tryParse(
                item['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
            0;
        final unit = item['Ед.изм']?.toString() ?? 'г';

        final requiredGrams = itemQuantity * multiplier;
        final requiredKg = requiredGrams / 1000;

        // Конвертируем в метрическую систему
        final metricQuantity = UnitConverterService.convertToMetric(
          quantity: requiredKg,
          unitSymbol: unit,
        );

        // Создаем операцию списания
        final writeOff = WarehouseOperation.fromComposition(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: ingredientName,
          originalQuantity: metricQuantity,
          originalUnit: 'кг',
          date: date,
          relatedOrderId: 'prod_filling_$fillingId',
          notes: 'Производство начинки: $fillingName',
        );

        await _warehouseService.addOperation(writeOff);
        print(
            '   ✓ Списано: $ingredientName - ${metricQuantity.toStringAsFixed(3)} кг');
      }

      // Создаем запись в производстве
      final success = await _apiService.createProductionOperation(
        sheet: 'Начинки',
        entityId: fillingId,
        name: fillingName,
        quantity: quantityKg,
        unit: 'кг',
        date: date,
      );

      if (success) {
        // Обновляем кэш
        final key = 'filling_$fillingId';
        _fillingBalance[key] = (_fillingBalance[key] ?? 0) + quantityKg;

        print('✅ Производство начинки завершено');
        print('   Остаток начинки: ${_fillingBalance[key]} кг');
      }

      return success;
    } catch (e) {
      print('❌ Ошибка производства начинки: $e');
      return false;
    }
  }

  // ==================== ВЫПУСК ПРОДУКЦИИ ====================

  // Выпуск готовой продукции
  Future<bool> releaseProduct({
    required int productId,
    required String productName,
    required int quantity,
    required DateTime date,
  }) async {
    print('🏭 Выпуск продукции: $productName $quantity шт');

    try {
      // Получаем состав продукта
      final composition = await _apiService.getCompositionForProduct(productId);

      if (composition == null || composition.isEmpty) {
        print('❌ Состав продукта не найден');
        return false;
      }

      // Проверяем наличие всех начинок
      for (var item in composition) {
        final ingredientName = item['Ингредиент']?.toString() ?? '';
        final filling = await _apiService.getFillingByName(ingredientName);

        if (filling != null) {
          final fillingId = filling['ID']?.toString() ?? '';
          final fillingKey = 'filling_$fillingId';
          final itemQuantity = double.tryParse(
                  item['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
              0;
          final requiredKg = (itemQuantity * quantity) / 1000;
          final available = _fillingBalance[fillingKey] ?? 0;

          if (available < requiredKg) {
            print('❌ Не хватает начинки ${filling['Наименование']}');
            print('   Нужно: $requiredKg кг, есть: $available кг');
            return false;
          }
        }
      }

      // Все проверки пройдены - производим списания
      for (var item in composition) {
        final ingredientName = item['Ингредиент']?.toString() ?? '';
        final itemQuantity = double.tryParse(
                item['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
            0;
        final unit = item['Ед.изм']?.toString() ?? 'г';

        final filling = await _apiService.getFillingByName(ingredientName);

        if (filling != null) {
          // Это начинка - списываем с производственного склада
          final fillingId = filling['ID']?.toString() ?? '';
          final fillingKey = 'filling_$fillingId';
          final requiredKg = (itemQuantity * quantity) / 1000;

          _fillingBalance[fillingKey] =
              (_fillingBalance[fillingKey] ?? 0) - requiredKg;

          print(
              '   🥣 Списана начинка: ${filling['Наименование']} - $requiredKg кг');
        } else {
          // Это прямой ингредиент - списываем со склада
          final requiredKg = (itemQuantity * quantity) / 1000;

          // Конвертируем в метрическую систему
          final metricQuantity = UnitConverterService.convertToMetric(
            quantity: requiredKg,
            unitSymbol: unit,
          );

          final writeOff = WarehouseOperation.fromComposition(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: ingredientName,
            originalQuantity: metricQuantity,
            originalUnit: 'кг',
            date: date,
            relatedOrderId: 'prod_product_$productId',
            notes: 'Производство продукции: $productName',
          );

          await _warehouseService.addOperation(writeOff);
          print('   ✓ Списано: $ingredientName - $requiredKg кг');
        }
      }

      // Создаем запись в производстве
      final success = await _apiService.createProductionOperation(
        sheet: 'Прайс-лист',
        entityId: productId,
        name: productName,
        quantity: quantity.toDouble(),
        unit: null,
        date: date,
      );

      if (success) {
        // Обновляем кэш
        final key = 'product_$productId';
        _productBalance[key] = (_productBalance[key] ?? 0) + quantity;

        print('✅ Выпуск продукции завершен');
        print('   Остаток продукции: ${_productBalance[key]} шт');
      }

      return success;
    } catch (e) {
      print('❌ Ошибка выпуска продукции: $e');
      return false;
    }
  }

  // ==================== ЗАВЕРШЕНИЕ ЗАКАЗА ====================

  // Завершение заказа (списание + отгрузка)
  Future<bool> completeOrder(Order order) async {
    print('📦 Завершение заказа #${order.id}');
    print('   Продукт: ${order.name} x${order.quantity}');

    try {
      // Получаем состав продукта
      final composition =
          await _apiService.getCompositionForProduct(order.priceListItemId);

      if (composition == null || composition.isEmpty) {
        print('❌ Состав продукта не найден');
        return false;
      }

      // Рассчитываем списание
      final writeOffs = <WarehouseOperation>[];

      for (var item in composition) {
        final ingredientName = item['Ингредиент']?.toString() ?? '';
        final itemQuantity = double.tryParse(
                item['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
            0;
        final unit = item['Ед.изм']?.toString() ?? 'г';

        final filling = await _apiService.getFillingByName(ingredientName);

        if (filling != null) {
          // Это начинка - проверяем наличие
          final fillingId = filling['ID']?.toString() ?? '';
          final fillingKey = 'filling_$fillingId';
          final requiredKg = (itemQuantity * order.quantity) / 1000;
          final available = _fillingBalance[fillingKey] ?? 0;

          if (available < requiredKg) {
            print('❌ Не хватает начинки ${filling['Наименование']}');
            print('   Нужно: $requiredKg кг, есть: $available кг');
            return false;
          }

          // Списываем начинку
          _fillingBalance[fillingKey] = available - requiredKg;

          // Создаем операцию списания для начинки (для учета)
          writeOffs.add(WarehouseOperation.fromComposition(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: filling['Наименование'] ?? '',
            originalQuantity: requiredKg,
            originalUnit: 'кг',
            date: DateTime.now(),
            relatedOrderId: order.id,
            notes: 'Списание начинки по заказу #${order.id}',
          ));
        } else {
          // Это прямой ингредиент
          final requiredKg = (itemQuantity * order.quantity) / 1000;

          final metricQuantity = UnitConverterService.convertToMetric(
            quantity: requiredKg,
            unitSymbol: unit,
          );

          writeOffs.add(WarehouseOperation.fromComposition(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: ingredientName,
            originalQuantity: metricQuantity,
            originalUnit: 'кг',
            date: DateTime.now(),
            relatedOrderId: order.id,
            notes: 'Списание по заказу #${order.id}',
          ));
        }
      }

      // Сохраняем все операции списания
      for (var writeOff in writeOffs) {
        await _warehouseService.addOperation(writeOff);
      }

      // Уменьшаем остаток готовой продукции
      final productKey = 'product_${order.priceListItemId}';
      final currentBalance = _productBalance[productKey] ?? 0;
      _productBalance[productKey] = currentBalance - order.quantity;

      // Обновляем статус заказа
      await _apiService.updateOrderStatus(
        orderId: order.id,
        newStatus: 'доставлен',
      );

      print('✅ Заказ завершен, списано ${writeOffs.length} позиций');
      return true;
    } catch (e) {
      print('❌ Ошибка завершения заказа: $e');
      return false;
    }
  }

  // Массовое завершение заказов
  Future<Map<String, dynamic>> completeOrdersBatch(List<Order> orders) async {
    print('📦 Массовое завершение ${orders.length} заказов');

    final results = {
      'success': 0,
      'failed': 0,
      'errors': <String>[],
    };

    for (var order in orders) {
      final success = await completeOrder(order);
      if (success) {
        results['success'] = (results['success'] as int) + 1;
      } else {
        results['failed'] = (results['failed'] as int) + 1;
        (results['errors'] as List<String>)
            .add('Заказ #${order.id}: ${order.name}');
      }
    }

    print(
        '✅ Массовое завершение: ${results['success']} успешно, ${results['failed']} с ошибками');
    return results;
  }

  // ==================== ПОЛУЧЕНИЕ ДАННЫХ ====================

  // Получение остатков
  Future<Map<String, Map<String, double>>> getProductionBalances() async {
    final fillings = <String, double>{};
    final products = <String, double>{};

    // Преобразуем ID в названия
    _fillingBalance.forEach((key, value) {
      final id = key.replaceAll('filling_', '');
      final name = _fillingNames[id] ?? 'Начинка $id';
      fillings[name] = value;
    });

    _productBalance.forEach((key, value) {
      final id = key.replaceAll('product_', '');
      final name = _productNames[id] ?? 'Продукт $id';
      products[name] = value.toDouble();
    });

    return {
      'fillings': fillings,
      'products': products,
    };
  }

  // Получение статистики производства
  Future<ProductionStats> getProductionStats(DateTime date) async {
    try {
      final operations = await _apiService.fetchProductionOperations();

      if (operations == null) {
        return ProductionStats(
          totalFillingsProduced: 0,
          totalProductsProduced: 0,
          totalShipped: 0,
          todayPlan: 0,
          fillingsByDay: {},
          productsByDay: {},
        );
      }

      double totalFillings = 0;
      int totalProducts = 0;
      final fillingsByDay = <String, double>{};
      final productsByDay = <String, int>{};

      for (var op in operations) {
        final sheet = op['Лист']?.toString() ?? '';
        final quantity = double.tryParse(
                op['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
            0;
        final unit = op['Ед.изм']?.toString();
        final opDate = _parseDate(op['Дата']);
        final dateKey = '${opDate.day}.${opDate.month}.${opDate.year}';

        if (sheet == 'Начинки' && unit?.isNotEmpty == true) {
          totalFillings += quantity;
          fillingsByDay[dateKey] = (fillingsByDay[dateKey] ?? 0) + quantity;
        } else if (sheet == 'Прайс-лист' && (unit == null || unit.isEmpty)) {
          totalProducts += quantity.toInt();
          productsByDay[dateKey] =
              (productsByDay[dateKey] ?? 0) + quantity.toInt();
        }
      }

      // Получаем количество отгруженных заказов
      final orders = await _apiService.fetchOrders(status: 'доставлен');
      final totalShipped = orders?.length ?? 0;

      return ProductionStats(
        totalFillingsProduced: totalFillings,
        totalProductsProduced: totalProducts,
        totalShipped: totalShipped,
        todayPlan: productsByDay['${date.day}.${date.month}.${date.year}'] ?? 0,
        fillingsByDay: fillingsByDay,
        productsByDay: productsByDay,
      );
    } catch (e) {
      print('Ошибка получения статистики: $e');
      return ProductionStats(
        totalFillingsProduced: 0,
        totalProductsProduced: 0,
        totalShipped: 0,
        todayPlan: 0,
        fillingsByDay: {},
        productsByDay: {},
      );
    }
  }

  // Получение предупреждений
  Future<List<String>> getAlerts() async {
    final alerts = <String>[];

    // Проверяем начинки (меньше 2 кг)
    _fillingBalance.forEach((key, value) {
      if (value < 2) {
        final id = key.replaceAll('filling_', '');
        final name = _fillingNames[id] ?? 'Начинка $id';
        alerts.add(
            '⚠️ Заканчивается начинка: $name (${value.toStringAsFixed(1)} кг)');
      }
    });

    // Проверяем готовую продукцию (меньше 20 шт)
    _productBalance.forEach((key, value) {
      if (value < 20) {
        final id = key.replaceAll('product_', '');
        final name = _productNames[id] ?? 'Продукт $id';
        alerts.add('⚠️ Мало готовой продукции: $name ($value шт)');
      }
    });

    return alerts;
  }

  // Получение списка начинок
  Future<List<Map<String, dynamic>>> getFillings() async {
    final fillings = await _apiService.fetchFillings();
    if (fillings == null) return [];

    return fillings.map((item) {
      // Просто преобразуем, без проверки типа
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  // Получение списка продуктов
  Future<List<Map<String, dynamic>>> getProducts() async {
    final products = await _apiService.fetchProducts();
    if (products == null) return [];

    return products.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  // Получение производственных операций
  Future<List<ProductionOperation>> getProductionOperations() async {
    final data = await _apiService.fetchProductionOperations();
    if (data == null) return [];

    return data
        .map((json) => ProductionOperation(
              sheet: json['Лист']?.toString() ?? '',
              entityId:
                  int.tryParse(json['ID сущности']?.toString() ?? '0') ?? 0,
              name: json['Наименование']?.toString() ?? '',
              quantity: double.tryParse(
                      json['Количество']?.toString().replaceAll(',', '.') ??
                          '0') ??
                  0,
              unit: json['Ед.изм']?.toString(),
              date: _parseDate(json['Дата']),
            ))
        .toList();
  }

  // ==================== CRUD ОПЕРАЦИИ ====================

  // Создание производственной операции
  Future<bool> createProductionOperation(ProductionOperation operation) async {
    final success = await _apiService.createProductionOperation(
      sheet: operation.sheet,
      entityId: operation.entityId,
      name: operation.name,
      quantity: operation.quantity,
      unit: operation.unit,
      date: operation.date,
    );

    if (success) {
      await _applyProductionRecord(operation);
    }

    return success;
  }

  // Обновление производственной операции
  Future<bool> updateProductionOperation({
    required int rowId,
    String? sheet,
    int? entityId,
    String? name,
    double? quantity,
    String? unit,
    DateTime? date,
  }) async {
    return await _apiService.updateProductionOperation(
      rowId: rowId,
      sheet: sheet,
      entityId: entityId,
      name: name,
      quantity: quantity,
      unit: unit,
      date: date,
    );
  }

  // Удаление производственной операции
  Future<bool> deleteProductionOperation(int rowId) async {
    return await _apiService.deleteProductionOperation(rowId);
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    try {
      if (date is DateTime) return date;
      if (date is String) {
        final parts = date.split('.');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }
    } catch (e) {
      print('Ошибка парсинга даты: $e');
    }
    return DateTime.now();
  }

  // Получение остатка начинки
  double getFillingBalance(int fillingId) {
    return _fillingBalance['filling_$fillingId'] ?? 0;
  }

  // Получение остатка продукта
  int getProductBalance(int productId) {
    return _productBalance['product_$productId'] ?? 0;
  }

  // Проверка возможности производства
  Future<bool> canProduceFilling({
    required int fillingId,
    required double quantityKg,
  }) async {
    final composition = await _apiService.getCompositionForFilling(fillingId);
    if (composition == null) return false;

    final filling = await _apiService.getFilling(fillingId);
    if (filling == null) return false;

    final portionWeight = double.tryParse(
            filling['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
        0;
    final multiplier = (quantityKg * 1000) / portionWeight;

    for (var item in composition) {
      final ingredientName = item['Ингредиент']?.toString() ?? '';
      final itemQuantity = double.tryParse(
              item['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
          0;
      final unit = item['Ед.изм']?.toString() ?? 'г';

      final requiredGrams = itemQuantity * multiplier;
      final requiredKg = requiredGrams / 1000;

      final metricQuantity = UnitConverterService.convertToMetric(
        quantity: requiredKg,
        unitSymbol: unit,
      );

      final available =
          await _warehouseService.getStockBalance(ingredientName, 'кг');

      if (available < metricQuantity) {
        print(
            '❌ Не хватает $ingredientName: нужно $metricQuantity кг, есть $available кг');
        return false;
      }
    }

    return true;
  }

  // Проверка возможности выпуска продукции
  Future<bool> canReleaseProduct({
    required int productId,
    required int quantity,
  }) async {
    final composition = await _apiService.getCompositionForProduct(productId);
    if (composition == null) return false;

    for (var item in composition) {
      final ingredientName = item['Ингредиент']?.toString() ?? '';
      final itemQuantity = double.tryParse(
              item['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
          0;

      final filling = await _apiService.getFillingByName(ingredientName);

      if (filling != null) {
        // Проверяем наличие начинки
        final fillingId = filling['ID']?.toString() ?? '';
        final requiredKg = (itemQuantity * quantity) / 1000;
        final available = _fillingBalance['filling_$fillingId'] ?? 0;

        if (available < requiredKg) {
          print('❌ Не хватает начинки ${filling['Наименование']}');
          return false;
        }
      } else {
        // Проверяем наличие ингредиента
        final requiredKg = (itemQuantity * quantity) / 1000;
        final unit = item['Ед.изм']?.toString() ?? 'г';

        final metricQuantity = UnitConverterService.convertToMetric(
          quantity: requiredKg,
          unitSymbol: unit,
        );

        final available =
            await _warehouseService.getStockBalance(ingredientName, 'кг');

        if (available < metricQuantity) {
          print('❌ Не хватает $ingredientName');
          return false;
        }
      }
    }

    return true;
  }
}
