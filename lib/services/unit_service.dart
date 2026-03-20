// lib/services/unit_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/unit_of_measure_sheet.dart';
import '../utils/parsing_utils.dart';
import 'api_service.dart';

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

  // Загрузка всех единиц измерения
  Future<List<UnitOfMeasureSheet>> loadUnits(
      {bool forceRefresh = false}) async {
    // Если данные уже загружены и не прошло 5 минут, возвращаем кэш
    if (!forceRefresh && _allUnits.isNotEmpty && _lastUpdated != null) {
      final age = DateTime.now().difference(_lastUpdated!);
      if (age.inMinutes < 5) {
        return _allUnits;
      }
    }

    try {
      final response = await _apiService.fetchUnitsOfMeasure();

      if (response != null && response['success'] == true) {
        final List<dynamic> unitsData = response['units'] ?? [];
        _allUnits = unitsData
            .map((json) =>
                UnitOfMeasureSheet.fromJson(json as Map<String, dynamic>))
            .toList();

        // Группируем по категориям
        _unitsByCategory = {};
        for (var unit in _allUnits) {
          _unitsByCategory.putIfAbsent(unit.category, () => []).add(unit);
        }

        _lastUpdated = DateTime.now();
        notifyListeners();

        print('✅ Загружено ${_allUnits.length} единиц измерения');
      }
    } catch (e) {
      print('❌ Ошибка загрузки единиц измерения: $e');
    }

    return _allUnits;
  }

  // Получить единицы по категории
  List<UnitOfMeasureSheet> getUnitsByCategory(String category) {
    return _unitsByCategory[category] ?? [];
  }

  // Получить единицы для веса
  List<UnitOfMeasureSheet> getWeightUnits() {
    return getUnitsByCategory('weight');
  }

  // Получить единицы для объема
  List<UnitOfMeasureSheet> getVolumeUnits() {
    return getUnitsByCategory('volume');
  }

  // Получить единицы для штук
  List<UnitOfMeasureSheet> getPieceUnits() {
    return getUnitsByCategory('piece');
  }

  // Получить все единицы для склада (только метрические)
  List<UnitOfMeasureSheet> getWarehouseUnits() {
    return _allUnits
        .where((u) =>
            (u.category == 'weight' && (u.symbol == 'кг' || u.symbol == 'г')) ||
            (u.category == 'volume' && (u.symbol == 'л' || u.symbol == 'мл')) ||
            u.category == 'piece')
        .toList();
  }

  // Получить единицу по символу
  UnitOfMeasureSheet? getUnitBySymbol(String symbol) {
    try {
      return _allUnits.firstWhere((u) => u.symbol == symbol);
    } catch (e) {
      return null;
    }
  }

  // Получить единицу по коду
  UnitOfMeasureSheet? getUnitByCode(String code) {
    try {
      return _allUnits.firstWhere((u) => u.code == code);
    } catch (e) {
      return null;
    }
  }

  // Проверить, является ли единица метрической для склада
  bool isWarehouseUnit(String symbol) {
    return symbol == 'кг' ||
        symbol == 'г' ||
        symbol == 'л' ||
        symbol == 'мл' ||
        symbol == 'шт';
  }

  // Получить базовую единицу для категории
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
}
