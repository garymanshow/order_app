// lib/models/order_item.dart
import '../utils/parsing_utils.dart';

// Заказы
class OrderItem {
  final String status;
  final String productName; // Исходное название из прайса
  final String displayName; // ← ДОБАВЛЯЕМ отформатированное название
  final int quantity;
  final double totalPrice;
  final String date;
  final String clientPhone;
  final String clientName;
  final double paymentAmount;
  final String paymentDocument;
  final bool notificationSent;
  final String priceListId;

  // 🔥 ИСПРАВЛЕНО: добавляем displayName в конструктор
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
    String? displayName, // ← добавляем опциональный параметр
  }) : displayName = displayName ??
            productName; // ← если не передан, используем productName

  // 🔥 КОНСТРУКТОР С ЯВНЫМ DISPLAYNAME (опционально)
  OrderItem.withDisplayName({
    required this.status,
    required this.productName,
    required this.displayName,
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

  // 🔥 ИСПРАВЛЕННЫЙ fromJson
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      status: json['status']?.toString() ?? 'оформлен',
      productName: json['productName']?.toString() ?? '',
      quantity: ParsingUtils.parseInt(json['quantity']) ?? 0,
      totalPrice: ParsingUtils.parseDouble(json['totalPrice']) ?? 0.0,
      date: json['date']?.toString() ?? '',
      clientPhone: json['clientPhone']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      paymentAmount: ParsingUtils.parseDouble(json['paymentAmount']) ?? 0.0,
      paymentDocument: json['paymentDocument']?.toString() ?? '',
      notificationSent:
          ParsingUtils.parseBool(json['notificationSent']) ?? false,
      priceListId: json['priceListId']?.toString() ?? '',
      displayName:
          json['displayName']?.toString(), // ← восстанавливаем displayName
    );
  }

  // 🔥 ИСПРАВЛЕННЫЙ fromMap с поддержкой displayNames
  factory OrderItem.fromMap(
    Map<String, dynamic> map, {
    Map<String, String>? productDisplayNames, // ← карта ID → displayName
  }) {
    final productName = map['Название']?.toString() ?? '';
    final priceListId = map['ID Прайс-лист']?.toString() ?? '';

    // Получаем отформатированное название, если есть
    final displayName = productDisplayNames?[priceListId] ?? productName;

    return OrderItem(
      status: map['Статус']?.toString() ?? 'оформлен',
      productName: productName,
      quantity: int.tryParse(map['Количество']?.toString() ?? '0') ?? 0,
      totalPrice:
          double.tryParse(map['Итоговая цена']?.toString() ?? '0') ?? 0.0,
      date: map['Дата']?.toString() ?? '',
      clientPhone: map['Телефон']?.toString() ?? '',
      clientName: map['Клиент']?.toString() ?? '',
      paymentAmount: double.tryParse(map['Оплата']?.toString() ?? '0') ?? 0.0,
      paymentDocument: map['Платежный документ']?.toString() ?? '',
      notificationSent: map['Уведомление отправлено']?.toString() == 'true',
      priceListId: priceListId,
      displayName: displayName, // ← передаем отформатированное
    );
  }

  // 🔥 toJson с displayName
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'productName': productName,
      'displayName': displayName,
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

  // toMap для Google Таблиц (без displayName, так как там нужно исходное название)
  Map<String, dynamic> toMap() {
    return {
      'Статус': status,
      'Название': productName, // ← отправляем исходное название
      'Количество': quantity.toString(),
      'Итоговая цена': totalPrice.toString(),
      'Дата': date,
      'Телефон': clientPhone,
      'Клиент': clientName,
      'Оплата': paymentAmount.toString(),
      'Платежный документ': paymentDocument,
      'Уведомление отправлено': notificationSent.toString(),
      'ID Прайс-лист': priceListId,
    };
  }

  // 🔥 copyWith с поддержкой displayName
  OrderItem copyWith({
    String? status,
    String? productName,
    String? displayName,
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
      displayName: displayName ?? this.displayName,
    );
  }

  // 🔥 ДОБАВЛЕНО: доступные следующие статусы (С УЧЕТОМ РОЛИ ВЛАДЕЛЬЦА)
  List<String> getAvailableStatuses({String userRole = 'client'}) {
    // Логика для Владельца (Видит всё, но быстрые кнопки только по воронке)
    if (userRole == 'owner') {
      switch (status) {
        case 'оформлен':
          return ['производство', 'отменен'];
        case 'производство':
          return ['готов', 'отменен'];
        case 'запас':
          return ['готов', 'отменен'];
        case 'в работе':
        case 'изготовление':
          return ['готов', 'запас', 'отменен'];
        case 'готов':
          return ['доставлен', 'запас', 'отменен'];
        case 'доставлен':
          return ['оплачен', 'отменен'];
        case 'оплачен':
          return [];
        case 'отменен':
          return [];
        default:
          return [];
      }
    }

    // Логика по умолчанию (для клиентов или других ролей)
    switch (status) {
      case 'оформлен':
        return ['производство', 'отменен'];
      case 'производство':
        return ['готов', 'отменен'];
      case 'готов':
        return ['доставлен', 'отменен'];
      case 'доставлен':
        return ['оплачен', 'отменен'];
      case 'оплачен':
        return [];
      case 'отменен':
        return [];
      default:
        return [];
    }
  }

  // Бизнес-логика (без изменений)
  bool get isDelivered => status == 'доставлен';
  bool get isPaid => paymentAmount >= totalPrice && paymentDocument.isNotEmpty;
  bool get needsPayment => isDelivered && !isPaid;
  bool get isCompleted => isDelivered && isPaid;

  bool get isPendingApproval => status == 'оформлен';
  bool get isSentToProduction => status == 'производство';
  bool get isInProgress => status == 'в работе';
  bool get isReadyForDelivery => status == 'готов';
  bool get isManufacturing => status == 'изготовление';
  bool get isInReserve => status == 'запас';

  bool get canBeApprovedByAdmin => isPendingApproval;
  bool get canBeStartedByManager => isSentToProduction;
  bool get canBeCompletedByManager => isInProgress;
}
