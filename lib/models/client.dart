// lib/models/client.dart
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
  final String? fcmToken;

  Client({
    String? name,
    String? phone,
    this.firm,
    this.postalCode,
    this.legalEntity,
    this.city,
    this.deliveryAddress,
    this.delivery,
    this.comment,
    this.latitude,
    this.longitude,
    this.fcmToken,
    double? discount,
    double? minOrderAmount,
  }) : super(
            phone: phone,
            name: name,
            discount: discount,
            minOrderAmount: minOrderAmount);

  // 🔥 ГЕТТЕР ДЛЯ СУММЫ АКТИВНЫХ ЗАКАЗОВ
  double getActiveOrdersTotal(ClientData? clientData) {
    // Убираем избыточные ?.
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
      name: map['Клиент']?.toString(),
      phone: map['Телефон']?.toString(),
      firm: map['ФИРМА']?.toString(),
      postalCode: map['Почтовый индекс']?.toString(),
      legalEntity: ParsingUtils.parseBool(map['Юридическое лицо']?.toString()),
      city: map['Город']?.toString(),
      deliveryAddress: map['Адрес доставки']?.toString(),
      delivery: ParsingUtils.parseBool(map['Доставка']?.toString()),
      comment: map['Комментарий']?.toString(),
      latitude: ParsingUtils.parseDouble(map['latitude']?.toString()),
      longitude: ParsingUtils.parseDouble(map['longitude']?.toString()),
      discount: ParsingUtils.parseDiscount(map['Скидка']?.toString() ?? ''),
      minOrderAmount:
          double.tryParse(map['Сумма миним.заказа']?.toString() ?? '0') ?? 0.0,
    );
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    print('🔍 name: ${json['name']} (тип: ${json['name'].runtimeType})');
    print('🔍 phone: ${json['phone']} (тип: ${json['phone'].runtimeType})');
    print('🔍 firm: ${json['firm']} (тип: ${json['firm'].runtimeType})');
    print(
        '🔍 postalCode: ${json['postalCode']} (тип: ${json['postalCode'].runtimeType})');
    print(
        '🔍 isLegalEntity: ${json['isLegalEntity']} (тип: ${json['isLegalEntity'].runtimeType})');
    print('🔍 city: ${json['city']} (тип: ${json['city'].runtimeType})');
    print(
        '🔍 deliveryAddress: ${json['deliveryAddress']} (тип: ${json['deliveryAddress'].runtimeType})');
    print(
        '🔍 hasDelivery: ${json['hasDelivery']} (тип: ${json['hasDelivery'].runtimeType})');
    print(
        '🔍 comment: ${json['comment']} (тип: ${json['comment'].runtimeType})');
    print(
        '🔍 latitude: ${json['latitude']} (тип: ${json['latitude'].runtimeType})');
    print(
        '🔍 longitude: ${json['longitude']} (тип: ${json['longitude'].runtimeType})');
    print(
        '🔍 discount: ${json['discount']} (тип: ${json['discount'].runtimeType})');
    print(
        '🔍 minOrderAmount: ${json['minOrderAmount']} (тип: ${json['minOrderAmount'].runtimeType})');
    print(
        '🔍 fcmToken: ${json['fcmToken']} (тип: ${json['fcmToken'].runtimeType})');

    return Client(
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      firm: json['firm']?.toString(),
      postalCode: json['postalCode']?.toString(),
      legalEntity: ParsingUtils.parseBool(json['isLegalEntity']?.toString()),
      city: json['city']?.toString(),
      deliveryAddress: json['deliveryAddress']?.toString(),
      delivery: json['hasDelivery'] is bool
          ? json['hasDelivery'] as bool?
          : ParsingUtils.parseBool(json['hasDelivery']?.toString()),
      comment: json['comment']?.toString(),
      latitude: ParsingUtils.parseDouble(json['latitude']),
      longitude: ParsingUtils.parseDouble(json['longitude']),
      fcmToken: json['fcmToken']?.toString(),
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
      'fcmToken': fcmToken ?? '',
      'discount': discount?.toString() ?? '0',
      'minOrderAmount': minOrderAmount?.toString() ?? '3000',
    };
  }

  // 🔥 ДОБАВЛЕН МЕТОД toMap() для Google Таблиц
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
      'FCM': fcmToken ?? '', // ← ДОБАВЛЕНО!
    };
  }
}
