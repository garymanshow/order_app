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
  final ValueChanged<String?> onUnitSelected; // Изменено на String?
  final String? labelText;
  final bool isRequired;
  final bool showOnlyMetric; // только метрические

  const UnitSelector({
    Key? key,
    this.mode = UnitSelectorMode.all,
    this.selectedUnit,
    required this.onUnitSelected,
    this.labelText,
    this.isRequired = false,
    this.showOnlyMetric = false,
  }) : super(key: key);

  @override
  _UnitSelectorState createState() => _UnitSelectorState();
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
    final unitService = Provider.of<UnitService>(context, listen: false);
    await unitService.loadUnits();

    setState(() {
      _units = _getFilteredUnits(unitService);
      _isLoading = false;
    });
  }

  List<UnitOfMeasureSheet> _getFilteredUnits(UnitService unitService) {
    List<UnitOfMeasureSheet> units = [];

    switch (widget.mode) {
      case UnitSelectorMode.weight:
        units = unitService.getWeightUnits();
        break;
      case UnitSelectorMode.volume:
        units = unitService.getVolumeUnits();
        break;
      case UnitSelectorMode.piece:
        units = unitService.getPieceUnits();
        break;
      case UnitSelectorMode.warehouse:
        units = unitService.getWarehouseUnits();
        break;
      case UnitSelectorMode.all:
        units = unitService.allUnits;
        break;
    }

    // Фильтр по метрической системе если нужно
    if (widget.showOnlyMetric) {
      units = units
          .where((u) =>
              u.symbol == 'г' ||
              u.symbol == 'кг' ||
              u.symbol == 'мл' ||
              u.symbol == 'л' ||
              u.symbol == 'шт')
          .toList();
    }

    return units;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedValue,
      decoration: InputDecoration(
        labelText: widget.labelText ?? 'Единица измерения',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: widget.isRequired
            ? Text('*', style: TextStyle(color: Colors.red))
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
              Container(
                width: 40,
                child: Text(
                  unit.symbol,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 8),
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
