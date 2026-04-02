// lib/services/env_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
// 🔥 Используем dart:js для надежного доступа к window
import 'dart:js' as js;

class EnvService {
  static final EnvService _instance = EnvService._internal();
  factory EnvService() => _instance;
  EnvService._internal();

  static bool _isInitialized = false;
  static final Map<String, String> _envCache = {};

  /// Главный метод инициализации
  static Future<void> init() async {
    if (_isInitialized) return;

    print('\n📁 ===== ИНИЦИАЛИЗАЦИЯ EnvService =====');

    // 1. Попытка загрузить из Flutter Dotenv
    await _loadFromDotenv();

    // 2. Попытка загрузить из window.ENV
    if (kIsWeb) {
      _loadFromWindowEnv();
    }

    // 3. Проверка обязательных переменных
    final scriptUrl = get('APP_SCRIPT_URL');
    if (scriptUrl == null || scriptUrl.isEmpty) {
      print('❌ Доступные переменные: ${_envCache.keys.toList()}');
      throw Exception('APP_SCRIPT_URL не найден!');
    }

    _printLoadedVars();
    _isInitialized = true;
    print('📁 ===== ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА =====\n');
  }

  /// Загрузка из файла .env
  static Future<void> _loadFromDotenv() async {
    try {
      await dotenv.load(fileName: "assets/.env");
      print('✅ .env загружен из assets');
      dotenv.env.forEach((key, value) {
        if (value.isNotEmpty) {
          _envCache[key] = value;
        }
      });
    } catch (e) {
      print('⚠️ .env файл не найден (нормально для GitHub Pages)');
    }
  }

  /// Загрузка из window.ENV (Браузер)
  static void _loadFromWindowEnv() {
    try {
      // 🔥 ПРОВЕРЯЕМ СУЩЕСТВОВАНИЕ ОБЪЕКТА
      if (js.context['ENV'] == null) {
        print('⚠️ window.ENV не определен');
        return;
      }

      final keys = [
        'APP_SCRIPT_URL',
        'APP_SCRIPT_SECRET',
        'VAPID_PUBLIC_KEY',
        'GOOGLE_DRIVE_IMAGES_FOLDER_ID'
      ];

      for (var key in keys) {
        try {
          // 🔥 БЕЗОПАСНЫЙ ДОСТУП К СВОЙСТВАМ
          final dynamic value = js.context['ENV'][key];

          if (value != null && value is String && value.isNotEmpty) {
            _envCache[key] = value;
            print('📌 $key: загружен из window.ENV');
          }
        } catch (e) {
          // Игнорируем ошибки чтения конкретного ключа
        }
      }
    } catch (e) {
      print('⚠️ Ошибка чтения window.ENV: $e');
    }
  }

  /// Получение значения (синхронно, из кэша)
  static String? get(String key) => _envCache[key];

  /// Удобные геттеры
  static String get scriptUrl => get('APP_SCRIPT_URL') ?? '';
  static String get scriptSecret => get('APP_SCRIPT_SECRET') ?? '';
  static String get vapidPublicKey => get('VAPID_PUBLIC_KEY') ?? '';
  static String get googleDriveImagesFolderID =>
      get('GOOGLE_DRIVE_IMAGES_FOLDER_ID') ?? '';

  static void _printLoadedVars() {
    print('\n📋 ЗАГРУЖЕННЫЕ ПЕРЕМЕННЫЕ:');
    print('   APP_SCRIPT_URL: ${_maskUrl(scriptUrl)}');
    print('   APP_SCRIPT_SECRET: ${scriptSecret.isNotEmpty ? '✓' : '✗'}');
    print('   VAPID_PUBLIC_KEY: ${vapidPublicKey.isNotEmpty ? '✓' : '✗'}');
    print(
        '   GOOGLE_DRIVE_IMAGES_FOLDER_ID: ${googleDriveImagesFolderID.isNotEmpty ? '✓' : '✗'}');
  }

  static String _maskUrl(String url) {
    if (url.length < 50) return url;
    return '${url.substring(0, 50)}...';
  }
}
