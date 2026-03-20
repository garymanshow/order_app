// lib/widgets/unit_search_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/unit_of_measure_sheet.dart';
import '../services/unit_service.dart';
import 'unit_selector.dart'; // Импортируем для UnitSelectorMode

class UnitSearchSelector extends StatefulWidget {
  final String? selectedUnit;
  final ValueChanged<String> onUnitSelected;
  final UnitSelectorMode mode;

  const UnitSearchSelector({
    Key? key,
    this.selectedUnit,
    required this.onUnitSelected,
    this.mode = UnitSelectorMode.all,
  }) : super(key: key);

  @override
  _UnitSearchSelectorState createState() => _UnitSearchSelectorState();
}

class _UnitSearchSelectorState extends State<UnitSearchSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<UnitOfMeasureSheet> _allUnits = [];
  List<UnitOfMeasureSheet> _filteredUnits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _searchController.addListener(_filterUnits);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    final unitService = Provider.of<UnitService>(context, listen: false);
    await unitService.loadUnits();

    setState(() {
      _allUnits = _getFilteredUnits(unitService);
      _filteredUnits = _allUnits;
      _isLoading = false;
    });
  }

  List<UnitOfMeasureSheet> _getFilteredUnits(UnitService unitService) {
    switch (widget.mode) {
      case UnitSelectorMode.weight:
        return unitService.getWeightUnits();
      case UnitSelectorMode.volume:
        return unitService.getVolumeUnits();
      case UnitSelectorMode.piece:
        return unitService.getPieceUnits();
      case UnitSelectorMode.warehouse:
        return unitService.getWarehouseUnits();
      case UnitSelectorMode.all:
        return unitService.allUnits;
      default:
        return unitService.allUnits;
    }
  }

  void _filterUnits() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUnits = _allUnits;
      } else {
        _filteredUnits = _allUnits
            .where((unit) =>
                unit.symbol.toLowerCase().contains(query) ||
                unit.name.toLowerCase().contains(query) ||
                unit.code.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск единиц измерения...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredUnits.length,
            itemBuilder: (context, index) {
              final unit = _filteredUnits[index];
              final isSelected = unit.symbol == widget.selectedUnit;

              return ListTile(
                selected: isSelected,
                leading: Container(
                  width: 50,
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(
                            alpha:
                                0.1) // Исправлено с withOpacity на withValues
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    unit.symbol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                title: Text(unit.name),
                subtitle: Text('Категория: ${unit.category}'),
                trailing: Text(unit.code),
                onTap: () {
                  widget.onUnitSelected(unit.symbol);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
