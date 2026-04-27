import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Теперь этот импорт нужен
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
    // Откладываем загрузку на первый кадр, чтобы context был доступен
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnits();
    });
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
      // 🔥 Получаем экземпляр UnitService из Provider
      final unitService = Provider.of<UnitService>(context, listen: false);

      // Вызываем загрузку (она сама решит, брать из кэша или с сервера)
      await unitService.loadUnits();

      if (mounted) {
        setState(() {
          // 🔥 Используем экземпляр сервиса для получения данных
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

  // 🔥 Убрали ключевое слово const перед конструкторами (если в модели оно не задано)
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

    // 🔥 Берем primaryColor безопасно (с дефолтным фоллбэком, если null)
    final Color activeBgColor = Theme.of(context).colorScheme.primary;

    return DropdownButtonFormField<String>(
      // 🔥 Используем initialValue вместо устаревшего value
      initialValue: (_selectedValue != null &&
              _selectedValue!.isNotEmpty &&
              _units.any((u) => u.symbol == _selectedValue))
          ? _selectedValue
          : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.labelText ?? 'Единица измерения',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        suffixIcon: widget.isRequired
            ? const Text('*', style: TextStyle(color: Colors.red))
            : null,
      ),
      validator: widget.isRequired
          ? (value) => value == null ? 'Выберите единицу измерения' : null
          : null,
      selectedItemBuilder: (context) {
        return _units.map((unit) {
          return DropdownMenuItem<String>(
            value: unit.symbol,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                '${unit.symbol}  ${unit.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }).toList();
      },
      items: _units.map((unit) {
        // Проверяем, является ли эта единица текущим выбором
        final bool isSelected = unit.symbol == _selectedValue;

        // Определяем цвета: для выбранного - инверсия, для остальных - обычные
        final Color textColor = isSelected ? Colors.white : Colors.black87;
        final Color nameColor = isSelected ? Colors.white70 : Colors.grey[600]!;

        return DropdownMenuItem<String>(
          value: unit.symbol,
          // Параметр style убран, цвета задаются напрямую через TextSpan
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? activeBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(children: [
                    TextSpan(
                      text: unit.symbol,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: unit.name,
                      style: TextStyle(color: nameColor),
                    ),
                  ]),
                ),
              ),
            ),
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
