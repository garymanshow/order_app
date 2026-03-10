import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Для Web
import 'dart:js' as js;

class EnvService {
  static String get(String key, {String defaultValue = ''}) {
    // 🔥 Для Web: читаем из window.ENV
    if (kIsWeb) {
      try {
        final env = js.context['ENV'];
        if (env != null) {
          final value = env[key];
          if (value != null && value.toString().isNotEmpty) {
            return value.toString();
          }
        }
      } catch (e) {
        print('⚠️ Ошибка чтения $key из window.ENV: $e');
      }
    }

    // 🔥 Fallback: из dotenv (для мобильных)
    final value = dotenv.env[key];
    if (value != null && value.isNotEmpty) {
      return value;
    }

    return defaultValue;
  }

  static bool has(String key) => get(key).isNotEmpty;
}
