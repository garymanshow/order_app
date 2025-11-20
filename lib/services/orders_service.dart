// lib/services/orders_service.dart
//import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_item.dart';

class OrdersService {
  final String _url =
      'https://docs.google.com/spreadsheets/d/16LQhpJgAduO-g7V5pl9zXNuvPMUzs0vwoHZJlz_FXe8/gviz/tq?tqx=out:csv&gid=501996865';

  String _clean(String s) {
    s = s.trim().replaceAll('\r', '').replaceAll('\n', '');
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  List<String> _parseCsvLine(String line) {
    List<String> fields = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      String char = line[i];
      String nextChar = i + 1 < line.length ? line[i + 1] : '';

      if (char == '"' && !inQuotes) {
        inQuotes = true;
      } else if (char == '"' && inQuotes && nextChar == '"') {
        current.write('"');
        i++;
      } else if (char == '"' && inQuotes) {
        inQuotes = false;
      } else if (char == ',' && !inQuotes) {
        fields.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    fields.add(current.toString());
    return fields.map((f) => f.trim()).toList();
  }

  Future<List<OrderItem>> _fetchOrders() async {
    final response = await http.get(Uri.parse(_url));
    if (response.statusCode != 200) return [];

    final lines = response.body.split('\n');
    final List<OrderItem> orders = [];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = _parseCsvLine(line);
      if (columns.length < 7) continue;

      final status = _clean(columns[0]);
      final productName = _clean(columns[1]);
      final quantityStr = _clean(columns[2]);
      final totalPriceStr = _clean(columns[3]);
      final date = _clean(columns[4]); // ← Дата
      final clientPhone = _clean(columns[5]); // ← Телефон
      final clientName = _clean(columns[6]); // ← Клиент

      final quantity = int.tryParse(quantityStr) ?? 0;
      final totalPrice = double.tryParse(totalPriceStr) ?? 0.0;

      if (quantity > 0) {
        orders.add(OrderItem(
          status: status,
          productName: productName,
          quantity: quantity,
          totalPrice: totalPrice,
          date: date,
          clientPhone: clientPhone,
          clientName: clientName,
        ));
      }
    }
    return orders;
  }

  // Получить сумму по телефону И клиенту
  Future<double> getTotalForPhoneAndClient(
      String phone, String clientName) async {
    final orders = await _fetchOrders();
    return orders
        .where((o) =>
                o.status == 'заказ' &&
                o.clientPhone == phone &&
                o.clientName == clientName // ← фильтр по клиенту
            )
        .map((o) => o.totalPrice)
        .fold<double>(0.0, (a, b) => a + b);
  }

  // Получить заказы по телефону и адресу (clientName = адрес)
  Future<List<OrderItem>> getOrdersByPhoneAndAddress(
      String phone, String address) async {
    final orders = await _fetchOrders();
    return orders
        .where((o) =>
            o.status == 'заказ' &&
            o.clientPhone == phone &&
            o.clientName == address)
        .toList();
  }
}
