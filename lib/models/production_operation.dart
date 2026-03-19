class ProductionOperation {
  final int? rowId; // ID строки в таблице (для обновления/удаления)
  final String sheet; // "Начинки" или "Прайс-лист"
  final int entityId; // ID сущности
  final String name; // Наименование
  final double quantity; // Количество
  final String? unit; // Единица измерения (если есть)
  final DateTime date; // Дата производства

  // Производные поля
  bool get isFilling => sheet == 'Начинки';
  bool get isProduct => sheet == 'Прайс-лист';
  bool get isProduction => unit != null && unit!.isNotEmpty;
  bool get isFinished => unit == null || unit!.isEmpty;

  ProductionOperation({
    this.rowId,
    required this.sheet,
    required this.entityId,
    required this.name,
    required this.quantity,
    this.unit,
    required this.date,
  });

  factory ProductionOperation.fromJson(Map<String, dynamic> json) {
    return ProductionOperation(
      rowId:
          json['rowId'] != null ? int.tryParse(json['rowId'].toString()) : null,
      sheet: json['Лист']?.toString() ?? '',
      entityId: int.tryParse(json['ID сущности']?.toString() ?? '0') ?? 0,
      name: json['Наименование']?.toString() ?? '',
      quantity: double.tryParse(
              json['Количество']?.toString().replaceAll(',', '.') ?? '0') ??
          0,
      unit: json['Ед.изм']?.toString(),
      date: _parseDate(json['Дата']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (rowId != null) 'rowId': rowId,
      'Лист': sheet,
      'ID сущности': entityId,
      'Наименование': name,
      'Количество': quantity,
      if (unit != null && unit!.isNotEmpty) 'Ед.изм': unit,
      'Дата': _formatDate(date),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'sheet': sheet,
      'entityId': entityId,
      'name': name,
      'quantity': quantity,
      if (unit != null && unit!.isNotEmpty) 'unit': unit,
      'date': date.toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    try {
      if (date is DateTime) return date;
      if (date is String) {
        // Формат: "DD.MM.YYYY"
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

  static String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
