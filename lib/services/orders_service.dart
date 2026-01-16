// lib/services/orders_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order_item.dart';
import './google_sheets_service.dart';

class OrdersService {
  Future<List<OrderItem>> _fetchOrders() async {
    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    // Читаем все строки из листа "Заказы"
    final rawData = await service.read(sheetName: 'Заказы');

    return rawData.map((row) {
      return OrderItem(
        status: row['Статус']?.toString() ?? '',
        productName: row['Название']?.toString() ?? '',
        quantity: int.tryParse(row['Количество']?.toString() ?? '0') ?? 0,
        totalPrice:
            double.tryParse(row['Итоговая цена']?.toString() ?? '0') ?? 0.0,
        date: row['Дата']?.toString() ?? '',
        clientPhone: row['Телефон']?.toString() ?? '',
        clientName: row['Клиент']?.toString() ?? '',
      );
    }).toList();
  }

  Future<double> getTotalForPhoneAndClient(
      String phone, String clientName) async {
    final orders = await _fetchOrders();
    return orders
        .where((o) =>
            o.status == 'оформлен' &&
            o.clientPhone == phone &&
            o.clientName == clientName)
        .map((o) => o.totalPrice)
        .fold<double>(0.0, (double a, double b) => a + b);
  }

  Future<List<OrderItem>> getOrdersByPhoneAndAddress(
      String phone, String address) async {
    final orders = await _fetchOrders();
    return orders
        .where((o) =>
            o.status == 'оформлен' && // ← важно: оформленные заказы
            o.clientPhone == phone &&
            o.clientName == address)
        .toList();
  }
}
