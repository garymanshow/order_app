// lib/models/admin_order.dart
import 'package:flutter/material.dart';

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

  // Доступные переходы статусов
  List<String> getAvailableStatuses() {
    switch (status) {
      case 'оформлен':
        return ['производство'];
      case 'производство':
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
      case 'готов':
        return Colors.purple;
      case 'доставлен':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
