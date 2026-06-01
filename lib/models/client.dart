import 'package:flutter/foundation.dart';
import 'user.dart';
import 'client_data.dart';
import '../utils/parsing_utils.dart';

class Client extends User {
  final String? firm;
  final String? postalCode;
  final bool? legalEntity;
  final String? city;
  final String? deliveryAddress;
  final bool? delivery;
  final String? comment;
  final double? latitude;
  final double? longitude;

  // 🔥 ЗАМЕНА: fcmToken переименован в email
  final String? email;

  Client({
    super.name,
    super.phone,
    this.firm,
    this.postalCode,
    this.legalEntity,
    this.city,
    this.deliveryAddress,
    this.delivery,
    this.comment,
    this.latitude,
    this.longitude,
    this.email, // 🔥 ЗАМЕНА
    super.discount,
    super.minOrderAmount,
  });

  double getActiveOrdersTotal(ClientData? clientData) {
    final orders = clientData?.orders;
    if (orders == null) return 0.0;

    final activeOrders = orders
        .where((order) =>
            order.clientPhone == phone &&
            order.clientName == name &&
            order.status == 'оформлен')
        .toList();

    double total = 0;
    for (var order in activeOrders) {
      total += order.totalPrice;
    }
    return total;
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      name: ParsingUtils.safeString(map['Клиент']),
      phone: ParsingUtils.safeString(map['Телефон']),
      firm: ParsingUtils.safeString(map['ФИРМА']),
      postalCode: ParsingUtils.safeString(map['Почтовый индекс']),
      legalEntity: ParsingUtils.parseBool(map['Юридическое лицо']),
      city: ParsingUtils.safeString(map['Город']),
      deliveryAddress: ParsingUtils.safeString(map['Адрес доставки']),
      delivery: ParsingUtils.parseBool(map['Доставка']),
      comment: ParsingUtils.safeString(map['Комментарий']),
      latitude: ParsingUtils.parseDouble(map['latitude']),
      longitude: ParsingUtils.parseDouble(map['longitude']),
      // 🔥 УНИВЕРСАЛЬНОЕ ЧТЕНИЕ: Ищем в 'FCM' (из таблицы) ИЛИ в 'fcmToken' (от функции getUserData в GAS)
      email: ParsingUtils.safeString(map['FCM']) ??
          ParsingUtils.safeString(map['fcmToken']),
      discount: ParsingUtils.parseDiscount(map['Скидка']),
      minOrderAmount:
          ParsingUtils.parseDouble(map['Сумма миним.заказа']) ?? 3000.0,
    );
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      name: ParsingUtils.safeString(json['name']),
      phone: ParsingUtils.safeString(json['phone']),
      firm: ParsingUtils.safeString(json['firm']),
      postalCode: ParsingUtils.safeString(json['postalCode']),
      legalEntity: ParsingUtils.parseBool(json['isLegalEntity']),
      city: ParsingUtils.safeString(json['city']),
      deliveryAddress: ParsingUtils.safeString(json['deliveryAddress']),
      delivery: ParsingUtils.parseBool(json['hasDelivery']),
      comment: ParsingUtils.safeString(json['comment']),
      latitude: ParsingUtils.parseDouble(json['latitude']),
      longitude: ParsingUtils.parseDouble(json['longitude']),
      // 🔥 ЗАМЕНА
      email: ParsingUtils.safeString(json['email']),
      discount: ParsingUtils.parseDouble(json['discount']),
      minOrderAmount:
          ParsingUtils.parseDouble(json['minOrderAmount']) ?? 3000.0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name ?? '',
      'phone': phone ?? '',
      'firm': firm ?? '',
      'postalCode': postalCode ?? '',
      'legalEntity': legalEntity?.toString() ?? 'false',
      'city': city ?? '',
      'deliveryAddress': deliveryAddress ?? '',
      'delivery': delivery?.toString() ?? 'false',
      'comment': comment ?? '',
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
      // 🔥 ЗАМЕНА
      'email': email ?? '',
      'discount': discount?.toString() ?? '0',
      'minOrderAmount': minOrderAmount?.toString() ?? '3000',
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'Клиент': name ?? '',
      'Телефон': phone ?? '',
      'ФИРМА': firm ?? '',
      'Почтовый индекс': postalCode ?? '',
      'Юридическое лицо': legalEntity?.toString() ?? '',
      'Город': city ?? '',
      'Адрес доставки': deliveryAddress ?? '',
      'Доставка': delivery?.toString() ?? '',
      'Комментарий': comment ?? '',
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
      'Скидка': discount?.toString() ?? '',
      'Сумма миним.заказа': minOrderAmount?.toString() ?? '0',
      // 🔥 ЗАМЕНА: Пишем обратно в колонку FCM
      'FCM': email ?? '',
    };
  }
}
