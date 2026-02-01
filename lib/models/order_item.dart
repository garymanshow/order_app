// lib/models/order_item.dart
// Заказы
class OrderItem {
  final String status;
  final String productName;
  final int quantity;
  final double totalPrice;
  final String date;
  final String clientPhone;
  final String clientName;
  final double paymentAmount;
  final String paymentDocument;
  final bool notificationSent;
  final String priceListId; // ← НОВОЕ ПОЛЕ

  OrderItem({
    required this.status,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    required this.date,
    required this.clientPhone,
    required this.clientName,
    this.paymentAmount = 0.0,
    this.paymentDocument = '',
    this.notificationSent = false,
    this.priceListId = '',
  });

  // 🔥 НОВЫЙ МЕТОД copyWith
  OrderItem copyWith({
    String? status,
    String? productName,
    int? quantity,
    double? totalPrice,
    String? date,
    String? clientPhone,
    String? clientName,
    double? paymentAmount,
    String? paymentDocument,
    bool? notificationSent,
    String? priceListId,
  }) {
    return OrderItem(
      status: status ?? this.status,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      date: date ?? this.date,
      clientPhone: clientPhone ?? this.clientPhone,
      clientName: clientName ?? this.clientName,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentDocument: paymentDocument ?? this.paymentDocument,
      notificationSent: notificationSent ?? this.notificationSent,
      priceListId: priceListId ?? this.priceListId,
    );
  }

  // 🔥 ДОБАВЛЕН МЕТОД fromJson
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      status: json['status'] as String? ?? 'оформлен',
      productName: json['productName'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      totalPrice: json['totalPrice'] as double? ?? 0.0,
      date: json['date'] as String? ?? '',
      clientPhone: json['clientPhone'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      paymentAmount: json['paymentAmount'] as double? ?? 0.0,
      paymentDocument: json['paymentDocument'] as String? ?? '',
      notificationSent: json['notificationSent'] as bool? ?? false,
      priceListId: json['priceListId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'productName': productName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'date': date,
      'clientPhone': clientPhone,
      'clientName': clientName,
      'paymentAmount': paymentAmount,
      'paymentDocument': paymentDocument,
      'notificationSent': notificationSent,
      'priceListId': priceListId,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    // Проверяем, откуда пришли данные - из Google или из кэша
    if (map.containsKey('Статус') || map.containsKey('Телефон')) {
      // Данные из Google Таблиц
      return OrderItem(
        status: map['Статус']?.toString() ?? 'оформлен',
        productName: map['Название']?.toString() ?? '',
        quantity: int.tryParse(map['Количество']?.toString() ?? '0') ?? 0,
        totalPrice:
            double.tryParse(map['Итоговая цена']?.toString() ?? '0') ?? 0.0,
        date: map['Дата']?.toString() ?? '',
        clientPhone: map['Телефон']?.toString() ?? '',
        clientName: map['Клиент']?.toString() ?? '',
        paymentAmount: double.tryParse(map['Оплата']?.toString() ?? '0') ?? 0.0,
        paymentDocument: map['Платежный документ']?.toString() ?? '',
        notificationSent: (map['Уведомление отправлено']?.toString() == 'true'),
        priceListId: map['ID Прайс-лист']?.toString() ?? '', // ← ИЗ GOOGLE
      );
    } else {
      // Данные из кэша (JSON) - теперь можно использовать fromJson
      return OrderItem.fromJson(map);
    }
  }

  // Бизнес-логика
  bool get isDelivered => status == 'доставлен';
  bool get isPaid => paymentAmount >= totalPrice && paymentDocument.isNotEmpty;
  bool get needsPayment => isDelivered && !isPaid;
  bool get isCompleted => isDelivered && isPaid;

  bool get isPendingApproval => status == 'оформлен';
  bool get isSentToProduction => status == 'в производство';
  bool get isInProgress => status == 'в работе';
  bool get isReadyForDelivery => status == 'готов к отправке';

  bool get canBeApprovedByAdmin => isPendingApproval;
  bool get canBeStartedByManager => isSentToProduction;
  bool get canBeCompletedByManager => isInProgress;
}
