// lib/widgets/unit_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/unit_of_measure_sheet.dart';
import '../services/unit_service.dart';

enum UnitSelectorMode {
  all, // все единицы
  weight, // только вес
  volume, // только объем
  piece, // только штуки
  warehouse, // только складские (кг, л, шт)
}

class UnitSelector extends StatefulWidget {
  final UnitSelectorMode mode;
  final String? selectedUnit;
  final ValueChanged<String?> onUnitSelected;
  final String? labelText;
  final bool isRequired;
  final bool showOnlyMetric;

  const UnitSelector({
    super.key,
    this.mode = UnitSelectorMode.all,
    this.selectedUnit,
    required this.onUnitSelected,
    this.labelText,
    this.isRequired = false,
    this.showOnlyMetric = false,
  });

  @override
  State<UnitSelector> createState() => _UnitSelectorState();
}

class _UnitSelectorState extends State<UnitSelector> {
  List<UnitOfMeasureSheet> _units = [];
  bool _isLoading = true;
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selectedUnit;
    _loadUnits();
  }

  @override
  void didUpdateWidget(UnitSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedUnit != widget.selectedUnit) {
      setState(() {
        _selectedValue = widget.selectedUnit;
      });
    }
  }

  /// 🔥 Загружает единицы через UnitService (который сам знает про кэш)
  Future<void> _loadUnits() async {
    try {
      // Получаем сервис через Provider
      final unitService = Provider.of<UnitService>(context, listen: false);

      // Загружаем данные (сервис сам решит: взять из кэша или пойти на сервер)
      await unitService.loadUnits();

      if (mounted) {
        setState(() {
          _units = _filterUnitsByMode(unitService.allUnits);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ UnitSelector: ошибка загрузки: $e');
      if (mounted) {
        setState(() {
          _units = _getFallbackUnits(); // Фоллбэк на хардкод
          _isLoading = false;
        });
      }
    }
  }

  /// 🔥 Фильтрация списка по выбранному режиму
  List<UnitOfMeasureSheet> _filterUnitsByMode(List<UnitOfMeasureSheet> units) {
    switch (widget.mode) {
      case UnitSelectorMode.weight:
        return units.where((u) => u.category == 'weight').toList();
      case UnitSelectorMode.volume:
        return units.where((u) => u.category == 'volume').toList();
      case UnitSelectorMode.piece:
        return units.where((u) => u.category == 'piece').toList();
      case UnitSelectorMode.warehouse:
        return units
            .where((u) =>
                (u.category == 'weight' &&
                    (u.symbol == 'кг' || u.symbol == 'г')) ||
                (u.category == 'volume' &&
                    (u.symbol == 'л' || u.symbol == 'мл')) ||
                u.category == 'piece')
            .toList();
      case UnitSelectorMode.all:
      default:
        return units;
    }
  }

  /// 🔥 Фоллбэк-список, если сервис недоступен
  List<UnitOfMeasureSheet> _getFallbackUnits() {
    return [
      UnitOfMeasureSheet(
          code: 'GR',
          symbol: 'г',
          name: 'грамм',
          category: 'weight',
          toBase: 1,
          baseUnit: 'г'),
      UnitOfMeasureSheet(
          code: 'KG',
          symbol: 'кг',
          name: 'килограмм',
          category: 'weight',
          toBase: 1000,
          baseUnit: 'г'),
      UnitOfMeasureSheet(
          code: 'ML',
          symbol: 'мл',
          name: 'миллилитр',
          category: 'volume',
          toBase: 1,
          baseUnit: 'мл'),
      UnitOfMeasureSheet(
          code: 'L',
          symbol: 'л',
          name: 'литр',
          category: 'volume',
          toBase: 1000,
          baseUnit: 'мл'),
      UnitOfMeasureSheet(
          code: 'PCS',
          symbol: 'шт',
          name: 'штука',
          category: 'piece',
          toBase: 1,
          baseUnit: 'шт'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedValue,
      decoration: InputDecoration(
        labelText: widget.labelText ?? 'Единица измерения',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: widget.isRequired
            ? const Text('*', style: TextStyle(color: Colors.red))
            : null,
      ),
      validator: widget.isRequired
          ? (value) => value == null ? 'Выберите единицу измерения' : null
          : null,
      items: _units.map((unit) {
        return DropdownMenuItem<String>(
          value: unit.symbol,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  unit.symbol,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unit.name,
                  style: TextStyle(color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedValue = value;
        });
        widget.onUnitSelected(value);
      },
    );
  }
}
