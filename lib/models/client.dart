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
    this.fcmToken,
    super.discount,
    super.minOrderAmount,
  });

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
      fcmToken: ParsingUtils.safeString(map['FCM']),
      discount: ParsingUtils.parseDiscount(map['Скидка']),
      minOrderAmount:
          ParsingUtils.parseDouble(map['Сумма миним.заказа']) ?? 3000.0,
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

    // 🔥 УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ДЛЯ БЕЗОПАСНОГО ПОЛУЧЕНИЯ СТРОКИ
    String? safeString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value.isEmpty ? null : value;
      return value.toString();
    }

    // 🔥 УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ДЛЯ БЕЗОПАСНОГО ПОЛУЧЕНИЯ ЧИСЛА
    double? safeDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return double.tryParse(trimmed);
      }
      return null;
    }

    // 🔥 УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ДЛЯ БЕЗОПАСНОГО ПОЛУЧЕНИЯ BOOL
    bool? safeBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value == 1;
      if (value is String) {
        final str = value.toLowerCase().trim();
        if (str.isEmpty) return null;
        return str == 'true' || str == '1' || str == 'да' || str == 'yes';
      }
      return null;
    }

    return Client(
      name: safeString(json['name']),
      phone: safeString(json['phone']),
      firm: safeString(json['firm']),
      postalCode: safeString(json['postalCode']),
      legalEntity: safeBool(json['isLegalEntity']),
      city: safeString(json['city']),
      deliveryAddress: safeString(json['deliveryAddress']),
      delivery: safeBool(json['hasDelivery']),
      comment: safeString(json['comment']),
      latitude: safeDouble(json['latitude']),
      longitude: safeDouble(json['longitude']),
      fcmToken: safeString(json['fcmToken']),
      discount: safeDouble(json['discount']),
      minOrderAmount: safeDouble(json['minOrderAmount']) ?? 3000.0,
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
