// lib/models/order_item.dart
class OrderItem {
  final String status; // Статус
  final String productName; // Наименование
  final int quantity; // Количество
  final double totalPrice; // Итоговая цена
  final String date; // Дата
  final String clientPhone; // Телефон клиента
  final String clientName; // Клиент (адрес доставки)

  OrderItem({
    required this.status,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    required this.date,
    required this.clientPhone,
    required this.clientName,
  });
}
