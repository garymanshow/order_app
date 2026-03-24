// lib/services/env_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:js' as js;

class EnvService {
  static final EnvService _instance = EnvService._internal();
  factory EnvService() => _instance;
  EnvService._internal();

  static bool _isInitialized = false;

  // 🔥 КЭШ ПЕРЕМЕННЫХ (независимо от dotenv)
  static final Map<String, String> _envCache = {};

  /// Инициализация (только для Web/PWA)
  static Future<void> init() async {
    if (_isInitialized) return;

    print('\n📁 ===== ИНИЦИАЛИЗАЦИЯ EnvService (Web) =====');

    // 🔥 ПОПЫТКА 1: Загрузить из assets/.env
    try {
      await dotenv.load(fileName: "assets/.env");
      print('✅ .env загружен из assets/.env');
      // Кэшируем значения из dotenv
      _cacheFromDotenv();
    } catch (e) {
      print('⚠️ assets/.env не найден: $e');
    }

    // 🔥 ПОПЫТКА 2: Загрузить из window.ENV (для продакшена)
    try {
      final jsEnv = js.context['ENV'];
      if (jsEnv != null) {
        final keys = [
          'APP_SCRIPT_URL',
          'APP_SCRIPT_SECRET',
          'VAPID_PUBLIC_KEY',
          'GOOGLE_DRIVE_IMAGES_FOLDER_ID'
        ];

        for (var key in keys) {
          final value = jsEnv[key]?.toString();
          if (value != null && value.isNotEmpty) {
            _envCache[key] = value; // 🔥 ПРЯМОЕ СОХРАНЕНИЕ В КЭШ!
            print('📌 $key: загружен из window.ENV');
          }
        }
      }
    } catch (e) {
      print('⚠️ window.ENV недоступен: $e');
    }

    // 🔥 ПРОВЕРКА ОБЯЗАТЕЛЬНЫХ ПЕРЕМЕННЫХ (из кэша!)
    final scriptUrl = get('APP_SCRIPT_URL');
    if (scriptUrl == null || scriptUrl.isEmpty) {
      print('❌ Доступные переменные в кэше: ${_envCache.keys.toList()}');
      throw Exception(
          '❌ APP_SCRIPT_URL не найден! Проверьте .env или window.ENV');
    }

    print('\n📋 ЗАГРУЖЕННЫЕ ПЕРЕМЕННЫЕ:');
    print('   APP_SCRIPT_URL: ${_maskUrl(scriptUrl)}');
    print(
        '   APP_SCRIPT_SECRET: ${get('APP_SCRIPT_SECRET') != null ? '✓' : '✗'}');
    print(
        '   VAPID_PUBLIC_KEY: ${get('VAPID_PUBLIC_KEY') != null ? '✓' : '✗'}');
    print(
        '   GOOGLE_DRIVE_IMAGES_FOLDER_ID: ${get('GOOGLE_DRIVE_IMAGES_FOLDER_ID') != null ? '✓' : '✗'}');

    _isInitialized = true;
    print('📁 ===== ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА =====\n');
  }

  // 🔥 КЭШИРОВАНИЕ ИЗ DOTENV
  static void _cacheFromDotenv() {
    final keys = [
      'APP_SCRIPT_URL',
      'APP_SCRIPT_SECRET',
      'VAPID_PUBLIC_KEY',
      'GOOGLE_DRIVE_IMAGES_FOLDER_ID'
    ];
    for (var key in keys) {
      final value = dotenv.env[key];
      if (value != null && value.isNotEmpty) {
        _envCache[key] = value;
      }
    }
  }

  // 🔥 ПУБЛИЧНЫЙ ГЕТТЕР (с приоритетом кэша)
  static String? get(String key) {
    // Сначала ищем в нашем кэше
    if (_envCache.containsKey(key)) {
      return _envCache[key];
    }
    // Фоллбэк на dotenv
    return dotenv.env[key];
  }

  // 🔥 УДОБНЫЕ ГЕТТЕРЫ
  static String get scriptUrl => get('APP_SCRIPT_URL') ?? '';
  static String get scriptSecret => get('APP_SCRIPT_SECRET') ?? '';
  static String get vapidPublicKey => get('VAPID_PUBLIC_KEY') ?? '';
  static String get googleDriveImagesFolderID =>
      get('GOOGLE_DRIVE_IMAGES_FOLDER_ID') ?? '';

  // 🔥 ВСПОМОГАТЕЛЬНЫЙ МЕТОД: маскировка URL для логов
  static String _maskUrl(String url) {
    if (url.length < 50) return url;
    return '${url.substring(0, 50)}...';
  }
}
