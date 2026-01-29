// lib/widgets/order_card.dart
import 'package:flutter/material.dart';
import '../models/order_item.dart';

class OrderCard extends StatelessWidget {
  final OrderItem order;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const OrderCard({
    Key? key,
    required this.order,
    this.onApprove,
    this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final statusText = _getStatusText(order.status);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с информацией о заказе
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Клиент: ${order.clientName}'),
                      Text('Телефон: ${order.clientPhone}'),
                      Text('Дата: ${order.date}'),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Детали заказа
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Количество: ${order.quantity} шт'),
                Text('${order.totalPrice.toStringAsFixed(2)} ₽',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),

            // Информация об оплате
            if (order.paymentAmount > 0 || order.paymentDocument.isNotEmpty)
              Column(
                children: [
                  SizedBox(height: 8),
                  Divider(),
                  SizedBox(height: 8),
                  if (order.paymentAmount > 0)
                    Text(
                        'Оплачено: ${order.paymentAmount.toStringAsFixed(2)} ₽',
                        style: TextStyle(color: Colors.green)),
                  if (order.paymentDocument.isNotEmpty)
                    Text('Платёжный документ: ${order.paymentDocument}'),
                ],
              ),

            // Кнопки действий (только для оформленных заказов)
            if (order.status == 'оформлен' &&
                (onApprove != null || onReject != null))
              _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onReject != null)
          TextButton(
            onPressed: onReject,
            child: Text('Отклонить', style: TextStyle(color: Colors.red)),
          ),
        if (onApprove != null)
          ElevatedButton(
            onPressed: onApprove,
            child: Text('В производство'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'оформлен':
        return Colors.blue;
      case 'в производстве':
        return Colors.orange;
      case 'в работе':
        return Colors.orange;
      case 'готов к отправке':
        return Colors.purple;
      case 'доставлен':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'оформлен':
        return 'Оформлен';
      case 'в производстве':
        return 'В производстве';
      case 'в работе':
        return 'В работе';
      case 'готов к отправке':
        return 'Готов к отправке';
      case 'доставлен':
        return 'Доставлен';
      default:
        return status;
    }
  }
}
