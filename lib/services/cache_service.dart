// lib/services/cache_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/order_item.dart';
import '../models/filling.dart';
import '../models/composition.dart';
import '../models/product.dart';
import '../models/price_category.dart';
import '../models/warehouse_operation.dart';
import '../models/production_operation.dart';
import '../models/unit_of_measure_sheet.dart';
import '../models/sheet_metadata.dart';
import 'adapters/hive_adapters.dart';

class CacheService {
  static const String _ordersBox = 'orders';
  static const String _fillingsBox = 'fillings';
  static const String _compositionsBox = 'compositions';
  static const String _productsBox = 'products';
  static const String _priceCategoriesBox = 'price_categories';
  static const String _warehouseOperationsBox = 'warehouse_operations';
  static const String _productionOperationsBox = 'production_operations';
  static const String _unitsBox = 'units';
  static const String _pendingOperationsBox = 'pending_operations';
  static const String _metadataBox = 'metadata';
  // 🔥 КЛЮЧИ ДЛЯ ХРАНЕНИЯ ФЛАГОВ
  static const String _keyHasBeenUsed = 'app_has_been_used';
  static const String _keyLastPhone = 'last_login_phone';

  static CacheService? _instance;
  late Box<OrderItem> _orders;
  late Box<Filling> _fillings;
  late Box<Composition> _compositions;
  late Box<Product> _products;
  late Box<PriceCategory> _priceCategories;
  late Box<WarehouseOperation> _warehouseOperations;
  late Box<ProductionOperation> _productionOperations;
  late Box<UnitOfMeasureSheet> _units;
  late Box<Map<String, dynamic>> _pendingOperations;
  late Box<Map<String, dynamic>> _metadata;

  bool _isInitialized = false;

  CacheService._();

  static Future<CacheService> getInstance() async {
    if (_instance == null) {
      _instance = CacheService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    // Инициализация Hive
    await Hive.initFlutter();

    // Регистрация адаптеров
    registerHiveAdapters();

    // Открытие боксов
    _orders = await Hive.openBox<OrderItem>(_ordersBox);
    _fillings = await Hive.openBox<Filling>(_fillingsBox);
    _compositions = await Hive.openBox<Composition>(_compositionsBox);
    _products = await Hive.openBox<Product>(_productsBox);
    _priceCategories = await Hive.openBox<PriceCategory>(_priceCategoriesBox);
    _warehouseOperations =
        await Hive.openBox<WarehouseOperation>(_warehouseOperationsBox);
    _productionOperations =
        await Hive.openBox<ProductionOperation>(_productionOperationsBox);
    _units = await Hive.openBox<UnitOfMeasureSheet>(_unitsBox);
    _pendingOperations =
        await Hive.openBox<Map<String, dynamic>>(_pendingOperationsBox);
    _metadata = await Hive.openBox<Map<String, dynamic>>(_metadataBox);

    _isInitialized = true;
    print('✅ CacheService инициализирован');
  }

  // ==================== ЗАКАЗЫ ====================

  /// Сохраняет все заказы в кэш
  Future<void> saveOrders(List<OrderItem> orders) async {
    await _orders.clear();
    for (var order in orders) {
      // Используем уникальный ключ на основе комбинации полей
      final key = '${order.clientPhone}_${order.productName}_${order.date}';
      await _orders.put(key, order);
    }
    print('📦 Сохранено ${orders.length} заказов');
  }

  /// Получает все заказы из кэша
  List<OrderItem> getOrders() {
    return _orders.values.toList();
  }

  /// Обновляет один заказ
  Future<void> updateOrder(OrderItem order, String key) async {
    await _orders.put(key, order);
  }

  /// Получает заказ по ключу
  OrderItem? getOrder(String key) {
    return _orders.get(key);
  }

  // ==================== НАЧИНКИ ====================

  /// Сохраняет все начинки в кэш
  Future<void> saveFillings(List<Filling> fillings) async {
    await _fillings.clear();
    for (var filling in fillings) {
      await _fillings.put(filling.entityId, filling);
    }
    print('🥣 Сохранено ${fillings.length} начинок');
  }

  /// Получает все начинки из кэша
  List<Filling> getFillings() {
    return _fillings.values.toList();
  }

  /// Получает начинку по ID
  Filling? getFilling(String id) {
    return _fillings.get(id);
  }

  // ==================== СОСТАВ ====================

  /// Сохраняет все элементы состава в кэш
  Future<void> saveCompositions(List<Composition> compositions) async {
    await _compositions.clear();
    for (var comp in compositions) {
      await _compositions.put(comp.id, comp);
    }
    print('📝 Сохранено ${compositions.length} элементов состава');
  }

  /// Получает все элементы состава из кэша
  List<Composition> getCompositions() {
    return _compositions.values.toList();
  }

  /// Получает состав по источнику (начинка или продукт)
  List<Composition> getCompositionsBySource(String sheetName, String entityId) {
    return _compositions.values
        .where((c) => c.sheetName == sheetName && c.entityId == entityId)
        .toList();
  }

  // ==================== ПРОДУКТЫ ====================

  /// Сохраняет все продукты в кэш
  Future<void> saveProducts(List<Product> products) async {
    await _products.clear();
    for (var product in products) {
      await _products.put(product.id, product);
    }
    print('📦 Сохранено ${products.length} продуктов');
  }

  /// Получает все продукты из кэша
  List<Product> getProducts() {
    return _products.values.toList();
  }

  /// Получает продукт по ID
  Product? getProduct(String id) {
    return _products.get(id);
  }

  // ==================== КАТЕГОРИИ ====================

  /// Сохраняет все категории в кэш
  Future<void> savePriceCategories(List<PriceCategory> categories) async {
    await _priceCategories.clear();
    for (var category in categories) {
      await _priceCategories.put(category.id, category);
    }
    print('📂 Сохранено ${categories.length} категорий');
  }

  /// Получает все категории из кэша
  List<PriceCategory> getPriceCategories() {
    return _priceCategories.values.toList();
  }

  /// Получает категорию по ID
  PriceCategory? getPriceCategory(String id) {
    return _priceCategories.get(id);
  }

  // ==================== СКЛАД ====================

  /// Сохраняет все складские операции в кэш
  Future<void> saveWarehouseOperations(
      List<WarehouseOperation> operations) async {
    await _warehouseOperations.clear();
    for (var op in operations) {
      await _warehouseOperations.put(op.id, op);
    }
    print('🏭 Сохранено ${operations.length} складских операций');
  }

  /// Получает все складские операции из кэша
  List<WarehouseOperation> getWarehouseOperations() {
    return _warehouseOperations.values.toList();
  }

  /// Добавляет одну складскую операцию
  Future<void> addWarehouseOperation(WarehouseOperation operation) async {
    await _warehouseOperations.put(operation.id, operation);
  }

  // ==================== ПРОИЗВОДСТВО ====================

  /// Сохраняет все производственные операции в кэш
  Future<void> saveProductionOperations(
      List<ProductionOperation> operations) async {
    await _productionOperations.clear();
    for (var op in operations) {
      final key = op.rowId?.toString() ?? op.name;
      await _productionOperations.put(key, op);
    }
    print('🏭 Сохранено ${operations.length} производственных операций');
  }

  /// Получает все производственные операции из кэша
  List<ProductionOperation> getProductionOperations() {
    return _productionOperations.values.toList();
  }

  /// Добавляет одну производственную операцию
  Future<void> addProductionOperation(ProductionOperation operation) async {
    final key = operation.rowId?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await _productionOperations.put(key, operation);
  }

  // ==================== ЕДИНИЦЫ ИЗМЕРЕНИЯ ====================

  /// Сохраняет все единицы измерения в кэш
  Future<void> saveUnits(List<UnitOfMeasureSheet> units) async {
    await _units.clear();
    for (var unit in units) {
      await _units.put(unit.code, unit);
    }
    print('📏 Сохранено ${units.length} единиц измерения');
  }

  /// Получает все единицы измерения из кэша
  List<UnitOfMeasureSheet> getUnits() {
    return _units.values.toList();
  }

  /// Получает единицу измерения по символу
  UnitOfMeasureSheet? getUnitBySymbol(String symbol) {
    try {
      return _units.values.firstWhere(
        (u) => u.symbol == symbol,
        orElse: () => throw Exception(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Получает единицу измерения по коду
  UnitOfMeasureSheet? getUnitByCode(String code) {
    return _units.get(code);
  }

  // ==================== МЕТАДАННЫЕ ====================

  /// Сохраняет метаданные в кэш
  Future<void> saveMetadata(Map<String, SheetMetadata> metadata) async {
    await _metadata.clear();
    for (var entry in metadata.entries) {
      await _metadata.put(entry.key, {
        'lastUpdate':
            entry.value.lastUpdate.toIso8601String(), // 👈 сохраняем как строку
        'editor': entry.value.editor,
      });
    }
    print('📊 Сохранено метаданных: ${metadata.length}');
  }

  /// Получает метаданные из кэша (возвращает Map<String, SheetMetadata>)
  Map<String, SheetMetadata> getMetadata() {
    final result = <String, SheetMetadata>{};
    for (var key in _metadata.keys) {
      final value = _metadata.get(key);
      if (value != null) {
        try {
          // 👈 ВОССТАНАВЛИВАЕМ DateTime из строки
          final lastUpdateStr = value['lastUpdate'] as String?;
          final lastUpdate = lastUpdateStr != null
              ? DateTime.parse(lastUpdateStr)
              : DateTime.now();

          result[key] = SheetMetadata(
            lastUpdate: lastUpdate,
            editor: value['editor'] as String? ?? '',
          );
        } catch (e) {
          print('⚠️ Ошибка парсинга метаданных для $key: $e');
          // Создаём с текущей датой в случае ошибки
          result[key] = SheetMetadata(
            lastUpdate: DateTime.now(),
            editor: value['editor'] as String? ?? '',
          );
        }
      }
    }
    return result;
  }

  /// Обновляет метаданные для конкретного листа
  Future<void> updateMetadata(
      String sheetName, DateTime lastUpdate, String editor) async {
    await _metadata.put(sheetName, {
      'lastUpdate': lastUpdate.toIso8601String(),
      'editor': editor,
    });
  }

  // ==================== ОЧЕРЕДЬ ОПЕРАЦИЙ ====================

  /// Добавляет операцию в очередь для последующей синхронизации
  Future<void> addPendingOperation({
    required String type,
    required String entity,
    required Map<String, dynamic> data,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final operation = {
      'id': id,
      'type': type,
      'entity': entity,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    };
    await _pendingOperations.put(id, operation);
    print('📤 Добавлена операция в очередь: $type/$entity');
  }

  /// Получает все несинхронизированные операции
  List<Map<String, dynamic>> getPendingOperations() {
    return _pendingOperations.values
        .where((op) => op['synced'] == false)
        .toList()
      ..sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
  }

  /// Отмечает операцию как синхронизированную
  Future<void> markOperationSynced(String id) async {
    final op = _pendingOperations.get(id);
    if (op != null) {
      op['synced'] = true;
      await _pendingOperations.put(id, op);
    }
  }

  /// Удаляет операцию из очереди
  Future<void> removeOperation(String id) async {
    await _pendingOperations.delete(id);
  }

  /// Получает количество ожидающих операций
  int get pendingOperationsCount {
    return _pendingOperations.values
        .where((op) => op['synced'] == false)
        .length;
  }

  // ==================== ОЧИСТКА ====================

  /// Очищает все кэши
  Future<void> clearAll() async {
    await _orders.clear();
    await _fillings.clear();
    await _compositions.clear();
    await _products.clear();
    await _priceCategories.clear();
    await _warehouseOperations.clear();
    await _productionOperations.clear();
    await _units.clear();
    await _pendingOperations.clear();
    await _metadata.clear();
    print('🗑️ Все кэши очищены');
  }

  /// Очищает только данные пользователя (заказы, корзину), но оставляет справочники
  Future<void> clearUserData() async {
    await _orders.clear();
    await _pendingOperations.clear();
    print('🗑️ Пользовательские данные очищены');
  }

  // 🔥 ПРОВЕРКА: было ли устройство использовано ранее?
  Future<bool> hasBeenUsed() async {
    try {
      final box = await _getBox('settings');
      return box.get(_keyHasBeenUsed, defaultValue: false) as bool;
    } catch (e) {
      print('⚠️ Ошибка проверки hasBeenUsed: $e');
      return false;
    }
  }

  // 🔥 ОТМЕТКА: устройство использовано
  Future<void> markAsUsed() async {
    try {
      final box = await _getBox('settings');
      await box.put(_keyHasBeenUsed, true);
    } catch (e) {
      print('⚠️ Ошибка markAsUsed: $e');
    }
  }

  // 🔥 ПОЛУЧЕНИЕ последнего телефона
  Future<String?> getLastPhone() async {
    try {
      final box = await _getBox('settings');
      return box.get(_keyLastPhone) as String?;
    } catch (e) {
      print('⚠️ Ошибка getLastPhone: $e');
      return null;
    }
  }

  // 🔥 СОХРАНЕНИЕ телефона
  Future<void> saveLastPhone(String phone) async {
    try {
      final box = await _getBox('settings');
      await box.put(_keyLastPhone, phone);
    } catch (e) {
      print('⚠️ Ошибка saveLastPhone: $e');
    }
  }

  // 🔥 ВСПОМОГАТЕЛЬНЫЙ МЕТОД для получения бокса
  Future<Box> _getBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    }
    return await Hive.openBox(name);
  }

  // ==================== СТАТУС ====================

  /// Проверяет, инициализирован ли сервис
  bool get isInitialized => _isInitialized;

  /// Получает размер базы данных (приблизительно)
  int get totalItemsCount {
    return _orders.length +
        _fillings.length +
        _compositions.length +
        _products.length +
        _priceCategories.length +
        _warehouseOperations.length +
        _productionOperations.length +
        _units.length +
        _pendingOperations.length +
        _metadata.length;
  }
}
