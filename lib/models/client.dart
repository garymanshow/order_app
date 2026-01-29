// lib/models/client.dart
import 'user.dart';

class Client extends User {
  final String? client;
  final String? firm;
  final String? postalCode;
  final bool? legalEntity;
  final String? city;
  final String? deliveryAddress;
  final bool? delivery;
  final String? comment;
  final double? latitude;
  final double? longitude;
  final double? discount;
  final double? minOrderAmount;
  String? fcm;

  Client({
    String? phone,
    String? name,
    this.client,
    this.firm,
    this.postalCode,
    this.legalEntity,
    this.city,
    this.deliveryAddress,
    this.delivery,
    this.comment,
    this.latitude,
    this.longitude,
    this.discount,
    this.minOrderAmount,
    this.fcm,
  }) : super(phone: phone, name: name); // ← вызываем конструктор User;

  factory Client.fromMap(Map<String, dynamic> map) {
    final clientName = map['Клиент']?.toString().isNotEmpty == true
        ? map['Клиент']?.toString()
        : null;
    final firmName = map['ФИРМА']?.toString().isNotEmpty == true
        ? map['ФИРМА']?.toString()
        : null;

    final displayName = clientName != null && firmName != null
        ? '$clientName ($firmName)'
        : clientName ?? firmName ?? '';

    return Client(
      client: map['Клиент']?.toString().isNotEmpty == true
          ? map['Клиент']?.toString()
          : null,
      firm: map['ФИРМА']?.toString().isNotEmpty == true
          ? map['ФИРМА']?.toString()
          : null,
      postalCode: map['Почтовый индекс']?.toString().isNotEmpty == true
          ? map['Почтовый индекс']?.toString()
          : null,
      // 🔥 Используем публичный метод нормализации
      phone: normalizePhone(map['Телефон']?.toString()),
      legalEntity: _parseBool(map['Юридическое лицо']),
      city: map['Город']?.toString().isNotEmpty == true
          ? map['Город']?.toString()
          : null,
      deliveryAddress: map['Адрес доставки']?.toString().isNotEmpty == true
          ? map['Адрес доставки']?.toString()
          : null,
      delivery: _parseBool(map['Доставка']),
      comment: map['Комментарий']?.toString().isNotEmpty == true
          ? map['Комментарий']?.toString()
          : null,
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      discount: _parseDouble(map['Скидка']),
      minOrderAmount: _parseDouble(map['Сумма миним.заказа']),
      fcm: map['FCM']?.toString().isNotEmpty == true
          ? map['FCM']?.toString()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Клиент': client ?? '',
      'ФИРМА': firm ?? '',
      'Почтовый индекс': postalCode ?? '',
      'Телефон': phone ?? '',
      'Юридическое лицо': legalEntity?.toString() ?? 'false',
      'Город': city ?? '',
      'Адрес доставки': deliveryAddress ?? '',
      'Доставка': delivery?.toString() ?? 'false',
      'Комментарий': comment ?? '',
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
      'Скидка': discount?.toString() ?? '',
      'Сумма миним.заказа': minOrderAmount?.toString() ?? '',
      'FCM': fcm ?? '',
    };
  }

  // 🔥 Публичный статический метод для нормализации телефона
  static String? normalizePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;

    // Удаляем все нецифровые символы
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Российский формат: +7 XXX XXX XX XX
    if (digitsOnly.length == 11 && digitsOnly.startsWith('7')) {
      return '+7${digitsOnly.substring(1)}';
    }
    if (digitsOnly.length == 10) {
      return '+7$digitsOnly';
    }
    if (digitsOnly.length == 11 && digitsOnly.startsWith('8')) {
      return '+7${digitsOnly.substring(1)}';
    }

    return phone; // возвращаем как есть, если не соответствует формату
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty) return null;
    return double.tryParse(str);
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return false;
    final str = value.toString().toLowerCase().trim();
    return str == 'true' || str == '1' || str == 'да' || str == 'yes';
  }

  // Для отображения в списке
  String get getDisplayName {
    if (client != null && firm != null) {
      return '$client ($firm)';
    }
    return client ?? firm ?? 'Без имени';
  }
}
