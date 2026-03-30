// lib/utils/auth_validator.dart
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthValidator {
  // ================= EMAIL =================

  /// Валидация email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Некорректный email';
    }
    return null;
  }

  /// Валидация соцсетей
  static String? validateSocialLink(String? value, String socialType) {
    if (value == null || value.trim().isEmpty) return null;
    final link = value.trim();

    switch (socialType.toLowerCase()) {
      case 'telegram':
        if (!link.contains('t.me') && !link.startsWith('@')) {
          return 'Введите @username или ссылку';
        }
        break;
      case 'vk':
        if (!link.contains('vk.com')) {
          return 'Ссылка должна содержать vk.com';
        }
        break;
    }
    return null;
  }

  /// Нормализация Telegram: @username -> https://t.me/username
  static String normalizeTelegram(String input) {
    if (input.startsWith('@')) {
      return 'https://t.me/${input.substring(1)}';
    }
    return input;
  }

  /// Проверка юзернейма Telegram (пример специфичной валидации)
  static bool isValidTelegram(String? value) {
    if (value == null || value.isEmpty) return false;
    // Допускаем @username или https://t.me/username
    if (value.startsWith('@')) return value.length > 1;
    if (value.contains('t.me')) return true;
    return false;
  }

  // ================= СЕРВИСЫ (OPINIONATED) =================
  // Перенесем FCM сюда, чтобы не засорять валидаторы телефона

  static Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print('Ошибка FCM: $e');
      return null;
    }
  }
}
