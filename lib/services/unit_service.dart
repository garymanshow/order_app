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
  /// Приоритет: кэш CacheService → локальный кэш сервиса → сервер
  Future<List<UnitOfMeasureSheet>> loadUnits(
      {bool forceRefresh = false}) async {
    // 🔥 1. Если forceRefresh — пропускаем кэш, идём на сервер
    if (!forceRefresh) {
      // 🔥 2. Проверяем локальный кэш сервиса (если уже загружали в этой сессии)
      if (_allUnits.isNotEmpty && _lastUpdated != null) {
        final age = DateTime.now().difference(_lastUpdated!);
        if (age.inMinutes < 5) {
          debugPrint(
              '📦 UnitService: возвращаем из локального кэша (${_allUnits.length} ед.)');
          return _allUnits;
        }
      }

      // 🔥 3. Проверяем кэш CacheService (заполняется при аутентификации)
      try {
        final cachedUnits = await _getUnitsFromCacheService();
        if (cachedUnits.isNotEmpty) {
          _allUnits = cachedUnits;
          _groupUnitsByCategory();
          _lastUpdated = DateTime.now();
          notifyListeners();
          debugPrint(
              '✅ UnitService: загружено ${_allUnits.length} единиц из CacheService');
          return _allUnits;
        }
      } catch (e) {
        debugPrint('⚠️ UnitService: ошибка чтения кэша: $e');
        // Продолжаем, пробуем загрузить с сервера
      }
    }

    // 🔥 4. Загружаем с сервера
    try {
      debugPrint('📤 UnitService: запрос единиц измерения с сервера...');
      final response = await _apiService.fetchUnitsOfMeasure();

      if (response != null && response['success'] == true) {
        final List<dynamic> unitsData = response['units'] ?? [];
        _allUnits = unitsData
            .map((json) =>
                UnitOfMeasureSheet.fromJson(json as Map<String, dynamic>))
            .toList();

        _groupUnitsByCategory();
        _lastUpdated = DateTime.now();

        // 🔥 Сохраняем в CacheService для будущего использования
        try {
          final cacheService = await CacheService.getInstance();
          await cacheService.saveUnits(_allUnits);
          debugPrint('💾 UnitService: сохранено в CacheService');
        } catch (e) {
          debugPrint('⚠️ UnitService: ошибка сохранения в кэш: $e');
        }

        notifyListeners();
        debugPrint(
            '✅ UnitService: загружено ${_allUnits.length} единиц с сервера');
        return _allUnits;
      } else {
        debugPrint('⚠️ UnitService: сервер вернул пустой ответ');
      }
    } catch (e) {
      debugPrint('❌ UnitService: ошибка загрузки с сервера: $e');
    }

    // 🔥 5. Фоллбэк: возвращаем то, что есть (даже если пусто)
    debugPrint(
        '⚠️ UnitService: возвращаем ${_allUnits.length} единиц (фоллбэк)');
    return _allUnits;
  }

  /// 🔥 Вспомогательный метод: получить единицы из CacheService
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
