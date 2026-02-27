// lib/models/admin_order.dart
import 'package:flutter/material.dart';
import '../utils/parsing_utils.dart';

class AdminOrder {
  final String id;
  final String status;
  final String productName;
  final int quantity;
  final double totalPrice;
  final String date;
  final String phone;
  final String clientName;

  AdminOrder({
    required this.id,
    required this.status,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    required this.date,
    required this.phone,
    required this.clientName,
  });

  // 🔥 ИСПРАВЛЕНО: безопасный fromJson
  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    return AdminOrder(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'оформлен',
      productName: json['productName']?.toString() ?? '',
      quantity: ParsingUtils.parseInt(json['quantity']) ?? 0,
      totalPrice: ParsingUtils.parseDouble(json['totalPrice']) ?? 0.0,
      date: json['date']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toJson (всегда возвращаем строки, а не null)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'productName': productName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'date': date,
      'phone': phone,
      'clientName': clientName,
    };
  }

  // 🔥 ИСПРАВЛЕНО: безопасный fromMap
  factory AdminOrder.fromMap(Map<String, dynamic> map) {
    // Поддержка данных из Google Таблиц
    if (map.containsKey('ID') || map.containsKey('Статус')) {
      return AdminOrder(
        id: map['ID']?.toString() ?? '',
        status: map['Статус']?.toString() ?? 'оформлен',
        productName: map['Название']?.toString() ?? '',
        quantity: int.tryParse(map['Количество']?.toString() ?? '0') ?? 0,
        totalPrice:
            double.tryParse(map['Итоговая цена']?.toString() ?? '0') ?? 0.0,
        date: map['Дата']?.toString() ?? '',
        phone: map['Телефон']?.toString() ?? '',
        clientName: map['Клиент']?.toString() ?? '',
      );
    } else {
      // Данные из кэша
      return AdminOrder.fromJson(map);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Статус': status,
      'Название': productName,
      'Количество': quantity.toString(),
      'Итоговая цена': totalPrice.toString(),
      'Дата': date,
      'Телефон': phone,
      'Клиент': clientName,
    };
  }

  // 🔥 ОБНОВЛЕННЫЕ СТАТУСЫ (соответствуют вашей бизнес-логике)
  List<String> getAvailableStatuses() {
    switch (status) {
      case 'оформлен':
        return ['производство'];
      case 'производство':
        return ['в работе'];
      case 'в работе':
        return ['готов'];
      case 'готов':
        return ['доставлен'];
      case 'доставлен':
        return [];
      default:
        return [];
    }
  }

  Color getStatusColor() {
    switch (status) {
      case 'оформлен':
        return Colors.orange;
      case 'производство':
        return Colors.blue;
      case 'в работе':
        return Colors.cyan;
      case 'готов':
        return Colors.purple;
      case 'доставлен':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Вспомогательные методы
  bool get canBeUpdated => status != 'доставлен';
  String get statusLabel {
    switch (status) {
      case 'оформлен':
        return 'Оформлен';
      case 'производство':
        return 'производство';
      case 'в работе':
        return 'В работе';
      case 'готов':
        return 'Готов';
      case 'доставлен':
        return 'Доставлен';
      default:
        return status;
    }
  }
}
