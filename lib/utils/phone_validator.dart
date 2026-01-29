// lib/utils/phone_validator.dart
import 'package:firebase_messaging/firebase_messaging.dart';

class PhoneValidator {
  /// Нормализует телефонный номер (поддержка российских форматов)
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

  /// Валидация телефона для формы
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final normalized = normalizePhone(value);
    if (normalized == null) return 'Неверный формат телефона';

    // Проверка российского формата
    final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 11 || !digitsOnly.startsWith('7')) {
      return 'Телефон должен быть в формате +7 XXX XXX XX XX';
    }

    return null;
  }

  /// Проверка телефона для авторизации (более строгая)
  static bool isValidAuthPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;

    final normalized = normalizePhone(phone);
    if (normalized == null) return false;

    final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length == 11 && digitsOnly.startsWith('7');
  }

  // 🔥 ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ ДЛЯ АВТОРИЗАЦИИ

  /// Получение FCM токена (требуется firebase_messaging)
  static Future<String?> getFcmToken() async {
    try {
      // Импортируйте firebase_messaging в файле, где используете этот метод
      // import 'package:firebase_messaging/firebase_messaging.dart';
      final fcmToken = await FirebaseMessaging.instance.getToken();
      return fcmToken;
    } catch (e) {
      print('Ошибка получения FCM токена: $e');
      return null;
    }
  }

  // Попытка получить номер телефона устройства (только Android, требует telephony)
  static Future<String?> getDevicePhoneNumber() async {
    // Эта функция будет реализована в экране авторизации,
    // так как требует специфических зависимостей и разрешений
    return null;
  }
}
