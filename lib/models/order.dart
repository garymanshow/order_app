// lib/models/order.dart
import '../utils/parsing_utils.dart';

class Order {
  final String id;
  final String status;
  final String name;
  final int quantity;
  final double totalPrice;
  final DateTime date;
  final String phone;
  final String client;
  final double payment;
  final String? paymentDoc;
  final bool notificationSent;
  final int priceListItemId;

  // Служебные поля
  final bool writeOffPerformed;
  final DateTime? writeOffDate;

  Order({
    required this.id,
    required this.status,
    required this.name,
    required this.quantity,
    required this.totalPrice,
    required this.date,
    required this.phone,
    required this.client,
    required this.payment,
    this.paymentDoc,
    required this.notificationSent,
    required this.priceListItemId,
    this.writeOffPerformed = false,
    this.writeOffDate,
  });

  // Статусы, при которых можно списывать
  bool get canWriteOff => status == 'готов' && !writeOffPerformed;

  // Статусы, при которых нельзя менять состав
  bool get isLocked =>
      status == 'производство' || status == 'готов' || status == 'доставлен';

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      status: json['status']?.toString() ?? 'оформлен',
      name: json['name']?.toString() ?? '',
      quantity: ParsingUtils.parseInt(json['quantity']) ?? 0,
      totalPrice: ParsingUtils.parseDouble(json['totalPrice']) ?? 0.0,
      date: _parseDate(json['date']),
      phone: json['phone']?.toString() ?? '',
      client: json['client']?.toString() ?? '',
      payment: ParsingUtils.parseDouble(json['payment']) ?? 0.0,
      paymentDoc: json['paymentDoc']?.toString(),
      notificationSent:
          ParsingUtils.parseBool(json['notificationSent']) ?? false,
      priceListItemId: ParsingUtils.parseInt(json['priceListItemId']) ?? 0,
      writeOffPerformed:
          ParsingUtils.parseBool(json['writeOffPerformed']) ?? false,
      writeOffDate: _parseDate(json['writeOffDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'name': name,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'date': date.toIso8601String(),
      'phone': phone,
      'client': client,
      'payment': payment,
      'paymentDoc': paymentDoc,
      'notificationSent': notificationSent,
      'priceListItemId': priceListItemId,
      'writeOffPerformed': writeOffPerformed,
      'writeOffDate': writeOffDate?.toIso8601String(),
    };
  }

  // Для Google Sheets
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Статус': status,
      'Название': name,
      'Количество': quantity,
      'Итоговая цена': totalPrice.toStringAsFixed(2).replaceAll('.', ','),
      'Дата': _formatDate(date),
      'Телефон': phone,
      'Клиент': client,
      'Оплата': payment.toStringAsFixed(2).replaceAll('.', ','),
      'Платежный документ': paymentDoc ?? '',
      'Уведомление отправлено': notificationSent ? '1' : '0',
      'ID Прайс-лист': priceListItemId,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['ID']?.toString() ?? '',
      status: map['Статус']?.toString() ?? 'оформлен',
      name: map['Название']?.toString() ?? '',
      quantity: int.tryParse(map['Количество']?.toString() ?? '0') ?? 0,
      totalPrice: double.tryParse(
              map['Итоговая цена']?.toString().replaceAll(',', '.') ?? '0') ??
          0.0,
      date: _parseDate(map['Дата']),
      phone: map['Телефон']?.toString() ?? '',
      client: map['Клиент']?.toString() ?? '',
      payment: double.tryParse(
              map['Оплата']?.toString().replaceAll(',', '.') ?? '0') ??
          0.0,
      paymentDoc: map['Платежный документ']?.toString(),
      notificationSent: map['Уведомление отправлено']?.toString() == '1',
      priceListItemId:
          int.tryParse(map['ID Прайс-лист']?.toString() ?? '0') ?? 0,
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    try {
      if (date is DateTime) return date;
      if (date is String) {
        // Пробуем разные форматы
        try {
          return DateTime.parse(date);
        } catch (e) {
          // Формат DD.MM.YYYY
          final parts = date.split('.');
          if (parts.length == 3) {
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
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
