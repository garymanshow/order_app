// lib/models/client.dart
import 'user.dart';
import 'client_data.dart'; // ← ТОЛЬКО client_data нужен

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
      legalEntity: _parseBool(map['Юридическое лицо']?.toString()),
      city: map['Город']?.toString(),
      deliveryAddress: map['Адрес доставки']?.toString(),
      delivery: _parseBool(map['Доставка']?.toString()),
      comment: map['Комментарий']?.toString(),
      latitude: _parseDouble(map['latitude']?.toString()),
      longitude: _parseDouble(map['longitude']?.toString()),
      discount: _parseDiscount(map['Скидка']?.toString() ?? ''),
      minOrderAmount:
          double.tryParse(map['Сумма миним.заказа']?.toString() ?? '0') ?? 0.0,
    );
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      firm: json['firm'] as String?,
      postalCode: json['postalCode'] as String?,
      legalEntity: json['legalEntity'] as bool?,
      city: json['city'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      delivery: json['delivery'] as bool?,
      comment: json['comment'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      discount: json['discount'] as double?,
      minOrderAmount: json['minOrderAmount'] as double?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'firm': firm,
      'postalCode': postalCode,
      'legalEntity': legalEntity,
      'city': city,
      'deliveryAddress': deliveryAddress,
      'delivery': delivery,
      'comment': comment,
      'latitude': latitude,
      'longitude': longitude,
      'discount': discount,
      'minOrderAmount': minOrderAmount,
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
    };
  }

  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  static bool? _parseBool(String? value) {
    if (value == null) return null;
    final str = value.toLowerCase().trim();
    return str == 'true' || str == '1' || str == 'да' || str == 'yes';
  }

  static double? _parseDiscount(String raw) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^\d,]'), '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.replaceAll(',', '.');
    try {
      return double.parse(normalized);
    } catch (e) {
      return null;
    }
  }
}
