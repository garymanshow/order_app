// lib/services/env_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:js' as js;

class EnvService {
  static final EnvService _instance = EnvService._internal();
  factory EnvService() => _instance;
  EnvService._internal();

  static bool _isInitialized = false;

  /// Инициализация EnvService (вызывается в main.dart)
  static Future<void> init() async {
    if (_isInitialized) return;

    print('\n📁 ===== ИНИЦИАЛИЗАЦИЯ EnvService =====');

    if (kIsWeb) {
      // Для веба: пробуем загрузить из assets/.env или window.ENV
      try {
        await dotenv.load(fileName: "assets/.env");
        print('✅ .env файл загружен из assets/.env');
      } catch (e) {
        print('⚠️ assets/.env не найден, пробуем window.ENV...');

        // Если файла нет, пытаемся получить из window.ENV
        final jsEnv = js.context['ENV'];
        if (jsEnv != null) {
          // Загружаем в dotenv для единого интерфейса
          final envMap = <String, String>{};
          final keys = [
            'APP_SCRIPT_URL',
            'APP_SCRIPT_SECRET',
            'VAPID_PUBLIC_KEY',
            'GOOGLE_DRIVE_IMAGES_FOLDER_ID'
          ];

          for (var key in keys) {
            final value = jsEnv[key]?.toString();
            if (value != null && value.isNotEmpty) {
              envMap[key] = value;
            }
          }

          if (envMap.isNotEmpty) {
            dotenv..load(mergeWith: envMap);
            print('✅ Переменные загружены из window.ENV');
          } else {
            print('⚠️ window.ENV не содержит переменных');
          }
        }
      }
    } else {
      // Для мобильных/десктопа
      await dotenv.load(fileName: ".env");
      print('✅ .env файл успешно загружен');
    }

    // Проверяем наличие ключей
    final scriptUrl = dotenv.env['APP_SCRIPT_URL'];
    final secret = dotenv.env['APP_SCRIPT_SECRET'];
    final vapidKey = dotenv.env['VAPID_PUBLIC_KEY'];
    final googleDriveImagesFolderID =
        dotenv.env['GOOGLE_DRIVE_IMAGES_FOLDER_ID'];

    print('📌 APP_SCRIPT_URL: ${scriptUrl ?? '❌ НЕ НАЙДЕН'}');
    print(
        '📌 APP_SCRIPT_SECRET: ${secret != null ? '✓ найден' : '❌ НЕ НАЙДЕН'}');
    print(
        '📌 VAPID_PUBLIC_KEY: ${vapidKey != null ? '✓ найден' : '❌ НЕ НАЙДЕН'}');
    print(
        '📌 GOOGLE_DRIVE_IMAGES_FOLDER_ID: ${googleDriveImagesFolderID != null ? '✓ найден' : '❌ НЕ НАЙДЕН'}');

    _isInitialized = true;
    print('📁 ===== КОНЕЦ ИНИЦИАЛИЗАЦИИ EnvService =====\n');
  }

  static String get(String key) {
    return dotenv.env[key] ?? '';
  }

  static String get scriptUrl => get('APP_SCRIPT_URL');
  static String get scriptSecret => get('APP_SCRIPT_SECRET');
  static String get vapidPublicKey => get('VAPID_PUBLIC_KEY');
  static String get googleDriveImagesFolderID =>
      get('GOOGLE_DRIVE_IMAGES_FOLDER_ID');
}
