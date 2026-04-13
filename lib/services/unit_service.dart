// lib/services/unit_service.dart
import 'package:flutter/material.dart';
import '../models/unit_of_measure_sheet.dart';
import 'api_service.dart';
import 'cache_service.dart';

class UnitService extends ChangeNotifier {
  final ApiService _apiService;

  // Кэш всех единиц измерения
  List<UnitOfMeasureSheet> _allUnits = [];
  Map<String, List<UnitOfMeasureSheet>> _unitsByCategory = {};

  // Время последнего обновления
  DateTime? _lastUpdated;

  // Геттеры
  List<UnitOfMeasureSheet> get allUnits => _allUnits;
  Map<String, List<UnitOfMeasureSheet>> get unitsByCategory => _unitsByCategory;

  UnitService(this._apiService);

  /// Загрузка всех единиц измерения
  /// Стратегия: Локальный кэш (Hive) -> Сервер (только если Hive пуст)
  Future<List<UnitOfMeasureSheet>> loadUnits(
      {bool forceRefresh = false}) async {
    // Если форсируем обновление, сбрасываем локальные переменные
    if (forceRefresh) {
      _allUnits.clear();
      _unitsByCategory.clear();
      _lastUpdated = null;
    }

    // 🔥 1. Проверяем кэш в памяти (для скорости внутри одной сессии)
    if (_allUnits.isNotEmpty && !forceRefresh) {
      return _allUnits;
    }

    // 🔥 2. Проверяем постоянный кэш (Hive/CacheService)
    try {
      final cachedUnits = await _getUnitsFromCacheService();

      if (cachedUnits.isNotEmpty) {
        debugPrint(
            '✅ UnitService: Загружено ${cachedUnits.length} ед. из локального кэша (Hive)');
        _allUnits = cachedUnits;
        _groupUnitsByCategory();
        _lastUpdated = DateTime.now();
        notifyListeners();
        return _allUnits;
      }
    } catch (e) {
      debugPrint('⚠️ UnitService: Ошибка чтения кэша Hive: $e');
    }

    // 🔥 3. Если кэш пуст — идем на сервер (ТОЛЬКО ОДИН РАЗ при первом запуске)
    debugPrint('📤 UnitService: Кэш пуст, запрос на сервер...');
    try {
      final response = await _apiService.fetchUnitsOfMeasure();

      if (response != null && response['success'] == true) {
        final List<dynamic> unitsData = response['units'] ?? [];
        _allUnits = unitsData
            .map((json) =>
                UnitOfMeasureSheet.fromJson(json as Map<String, dynamic>))
            .toList();

        _groupUnitsByCategory();
        _lastUpdated = DateTime.now();

        // Сохраняем в Hive для будущих запусков
        try {
          final cacheService = await CacheService.getInstance();
          await cacheService.saveUnits(_allUnits);
          debugPrint(
              '💾 UnitService: Сохранено ${_allUnits.length} ед. в Hive');
        } catch (e) {
          debugPrint('⚠️ UnitService: Ошибка сохранения в Hive: $e');
        }

        notifyListeners();
        debugPrint(
            '✅ UnitService: Загружено ${_allUnits.length} ед. с сервера');
        return _allUnits;
      } else {
        debugPrint('⚠️ UnitService: Сервер вернул пустой ответ или ошибку');
      }
    } catch (e) {
      debugPrint('❌ UnitService: Ошибка загрузки с сервера: $e');
    }

    // Фоллбэк: возвращаем то, что есть (даже если пусто)
    return _allUnits;
  }

  /// 🔥 Вспомогательный метод: получить единицы из CacheService (Hive)
  Future<List<UnitOfMeasureSheet>> _getUnitsFromCacheService() async {
    try {
      final cacheService = await CacheService.getInstance();
      final units = cacheService.getUnits();
      return units;
    } catch (e) {
      debugPrint('⚠️ _getUnitsFromCacheService: $e');
      return [];
    }
  }

  /// 🔥 Группирует единицы по категориям (weight/volume/piece)
  void _groupUnitsByCategory() {
    _unitsByCategory = {};
    for (var unit in _allUnits) {
      _unitsByCategory.putIfAbsent(unit.category, () => []).add(unit);
    }
  }

  // ==================== ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ ПОЛУЧЕНИЯ ЕДИНИЦ ====================

  /// Получить единицы по категории
  List<UnitOfMeasureSheet> getUnitsByCategory(String category) {
    return _unitsByCategory[category] ?? [];
  }

  /// Получить единицы для веса
  List<UnitOfMeasureSheet> getWeightUnits() {
    return getUnitsByCategory('weight');
  }

  /// Получить единицы для объема
  List<UnitOfMeasureSheet> getVolumeUnits() {
    return getUnitsByCategory('volume');
  }

  /// Получить единицы для штук
  List<UnitOfMeasureSheet> getPieceUnits() {
    return getUnitsByCategory('piece');
  }

  /// Получить все единицы для склада (только метрические)
  List<UnitOfMeasureSheet> getWarehouseUnits() {
    return _allUnits
        .where((u) =>
            (u.category == 'weight' && (u.symbol == 'кг' || u.symbol == 'г')) ||
            (u.category == 'volume' && (u.symbol == 'л' || u.symbol == 'мл')) ||
            u.category == 'piece')
        .toList();
  }

  /// Получить единицу по символу
  UnitOfMeasureSheet? getUnitBySymbol(String symbol) {
    try {
      return _allUnits.firstWhere((u) => u.symbol == symbol);
    } catch (e) {
      return null;
    }
  }

  /// Получить единицу по коду
  UnitOfMeasureSheet? getUnitByCode(String code) {
    try {
      return _allUnits.firstWhere((u) => u.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Проверить, является ли единица метрической для склада
  bool isWarehouseUnit(String symbol) {
    return symbol == 'кг' ||
        symbol == 'г' ||
        symbol == 'л' ||
        symbol == 'мл' ||
        symbol == 'шт';
  }

  /// Получить базовую единицу для категории
  String getBaseUnitForCategory(String category) {
    switch (category) {
      case 'weight':
        return 'г';
      case 'volume':
        return 'мл';
      case 'piece':
        return 'шт';
      default:
        return '';
    }
  }

  /// 🔥 Очистить кэш (для тестов или принудительного обновления)
  void clearCache() {
    _allUnits.clear();
    _unitsByCategory.clear();
    _lastUpdated = null;
    notifyListeners();
    debugPrint('🗑️ UnitService: кэш очищен');
  }
}
