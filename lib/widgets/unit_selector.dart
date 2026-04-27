import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/unit_of_measure_sheet.dart';
import '../services/unit_service.dart';

enum UnitSelectorMode {
  all,
  weight,
  volume,
  piece,
  ingredients,
  warehouse,
  time,
}

class UnitSelector extends StatefulWidget {
  final UnitSelectorMode mode;
  final String? selectedUnit;
  final ValueChanged<String?> onUnitSelected;
  final String? labelText;
  final bool isRequired;
  final List<UnitOfMeasureSheet>? unitsList;

  const UnitSelector({
    super.key,
    this.mode = UnitSelectorMode.all,
    this.selectedUnit,
    required this.onUnitSelected,
    this.labelText,
    this.isRequired = false,
    this.unitsList,
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

  Future<void> _loadUnits() async {
    try {
      final unitService = Provider.of<UnitService>(context, listen: false);
      await unitService.loadUnits();

      if (mounted) {
        setState(() {
          _units = widget.unitsList ?? _filterUnitsByMode(unitService.allUnits);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ UnitSelector: ошибка загрузки: $e');
      if (mounted) {
        setState(() {
          _units = _getFallbackUnits();
          _isLoading = false;
        });
      }
    }
  }

  List<UnitOfMeasureSheet> _filterUnitsByMode(List<UnitOfMeasureSheet> units) {
    switch (widget.mode) {
      case UnitSelectorMode.weight:
        return units.where((u) => u.category == 'weight').toList();
      case UnitSelectorMode.volume:
        return units.where((u) => u.category == 'volume').toList();
      case UnitSelectorMode.piece:
        return units.where((u) => u.category == 'piece').toList();
      case UnitSelectorMode.ingredients:
        return units
            .where((u) =>
                u.category == 'weight' ||
                u.category == 'volume' ||
                u.category == 'piece')
            .toList();
      case UnitSelectorMode.time:
        return units.where((u) => u.category == 'time').toList();
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
        return units;
    }
  }

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
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedValue,
      // Возвращаем стандартные значения, убираем костыли
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
        // Формируем текст подсказки конвертации
        String conversionHint = '';
        if (unit.category != 'piece' && unit.category != 'time') {
          conversionHint =
              '  (${unit.toBase.toStringAsFixed(unit.toBase == unit.toBase.roundToDouble() ? 0 : 2)} ${unit.baseUnit})';
        } else if (unit.category == 'time') {
          conversionHint =
              '  (${unit.toBase.toStringAsFixed(0)} ${unit.baseUnit})';
        }

        return DropdownMenuItem<String>(
          value: unit.symbol,
          // Больше никаких Column! Используем RichText для двух стилей в одной строке
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(
                text: unit.symbol,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '  '),
              TextSpan(
                text: unit.name,
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (conversionHint.isNotEmpty)
                TextSpan(
                  text: conversionHint,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9E9E9E),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ]),
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
