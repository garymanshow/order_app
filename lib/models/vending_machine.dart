import 'package:flutter/foundation.dart';

// Модель самого автомата
class VendingMachine {
  final String id;
  final String name;
  final String address;
  final String status;
  final String responsibleContact;
  final int checkFrequency;
  final String checkUnit; // 'д', 'ч' и т.д.

  VendingMachine({
    required this.id,
    required this.name,
    this.address = '',
    this.status = 'Работает',
    this.responsibleContact = '',
    this.checkFrequency = 2,
    this.checkUnit = 'д',
  });

  factory VendingMachine.fromJson(Map<String, dynamic> json) {
    return VendingMachine(
      id: json['ID']?.toString() ?? '',
      name: json['Название']?.toString() ?? '',
      address: json['Адрес']?.toString() ?? '',
      status: json['Статус']?.toString() ?? 'Работает',
      responsibleContact: json['Контакт ответственного']?.toString() ?? '',
      checkFrequency:
          int.tryParse(json['Частота проверки']?.toString() ?? '2') ?? 2,
      checkUnit: json['Ед.измерения']?.toString() ?? 'д',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'Название': name,
      'Адрес': address,
      'Статус': status,
      'Контакт ответственного': responsibleContact,
      'Частота проверки': checkFrequency.toString(),
      'Ед.измерения': checkUnit,
    };
  }
}

// Модель записи о загрузке товара в автомат
class VendingLoad {
  final String machineId;
  final String productId;
  final DateTime productionDate;
  final int loadedQty;
  final DateTime loadTimestamp;
  final String adminContact;

  VendingLoad({
    required this.machineId,
    required this.productId,
    required this.productionDate,
    required this.loadedQty,
    required this.loadTimestamp,
    this.adminContact = '',
  });

  factory VendingLoad.fromJson(Map<String, dynamic> json) {
    return VendingLoad(
      machineId: json['ID']?.toString() ?? '',
      productId: json['ID Прайс-лист']?.toString() ?? '',
      productionDate:
          _parseDate(json['Дата выработки']?.toString()) ?? DateTime.now(),
      loadedQty: int.tryParse(json['Кол-во загружено']?.toString() ?? '0') ?? 0,
      loadTimestamp:
          _parseDate(json['ДатаВремя загрузки']?.toString()) ?? DateTime.now(),
      adminContact: json['Администратор']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': machineId,
      'ID Прайс-лист': productId,
      'Дата выработки': _formatDate(productionDate),
      'Кол-во загружено': loadedQty.toString(),
      'ДатаВремя загрузки': _formatDateTime(loadTimestamp),
      'Администратор': adminContact,
    };
  }
}

// Модель записи о продаже/списании
class VendingOperation {
  final String machineId;
  final String productId;
  final String operationType; // Продажа, Брак, Просрочка
  final int qty;
  final DateTime timestamp;

  VendingOperation({
    required this.machineId,
    required this.productId,
    required this.operationType,
    required this.qty,
    required this.timestamp,
  });

  factory VendingOperation.fromJson(Map<String, dynamic> json) {
    return VendingOperation(
      machineId: json['ID']?.toString() ?? '',
      productId: json['ID Прайс-лист']?.toString() ?? '',
      operationType: json['Операция']?.toString() ?? 'Продажа',
      qty: int.tryParse(json['Кол-во']?.toString() ?? '0') ?? 0,
      timestamp: _parseDate(json['ДатаВремя']?.toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': machineId,
      'ID Прайс-лист': productId,
      'Операция': operationType,
      'Кол-во': qty.toString(),
      'ДатаВремя': _formatDateTime(timestamp),
    };
  }
}

// Агрегированная модель остатка товара в автомате
class VendingStockItem {
  final String productId;
  final String productName; // Берем из Product.displayName
  final int currentQty;
  final DateTime productionDate; // Берем из VendingLoad
  final int shelfLifeDays; // Вычисляем при создании из StorageCondition

  VendingStockItem({
    required this.productId,
    required this.productName,
    required this.currentQty,
    required this.productionDate,
    this.shelfLifeDays = 90, // Значение по умолчанию (как в вашем листе)
  });

  // Логика просрочки
  bool get isExpired {
    final expiryDate = productionDate.add(Duration(days: shelfLifeDays));
    return DateTime.now().isAfter(expiryDate);
  }

  bool get isExpiringSoon {
    final expiryDate = productionDate.add(Duration(days: shelfLifeDays));
    return DateTime.now().isAfter(expiryDate.subtract(const Duration(days: 2)));
  }

  // ИСПРАВЛЕНО: Возвращаем строку вместо Color, чтобы не зависеть от UI
  String get statusLevel {
    if (currentQty <= 0) return 'red';
    if (isExpired) return 'red';
    if (isExpiringSoon || currentQty <= 3) return 'orange';
    return 'green';
  }
}

// Вспомогательная функция парсинга дат из таблицы
DateTime? _parseDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;
  try {
    // Пробуем формат dd.MM.yyyy HH:mm
    if (dateStr.contains('.')) {
      final parts = dateStr.split(' ');
      final dateParts = parts[0].split('.');
      final timeParts = parts.length > 1 ? parts[1].split(':') : ['0', '0'];
      return DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    }
    // Пробуем ISO формат (yyyy-MM-dd)
    return DateTime.parse(dateStr);
  } catch (e) {
    debugPrint('Ошибка парсинга даты: $dateStr - $e');
    return null;
  }
}

// Вспомогательные функции для форматирования дат при сохранении
String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
