// lib/services/env_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:js' as js;

class EnvService {
  static final EnvService _instance = EnvService._internal();
  factory EnvService() => _instance;
  EnvService._internal();

  static String get(String key) {
    if (kIsWeb) {
      // Для веба берем из window.ENV
      try {
        final jsEnv = js.context['ENV'];
        if (jsEnv != null) {
          return jsEnv[key]?.toString() ?? '';
        }
      } catch (e) {
        print('⚠️ Ошибка доступа к window.ENV: $e');
      }
      return '';
    } else {
      // Для мобильных берем из dotenv
      return dotenv.env[key] ?? '';
    }
  }

  static String get scriptUrl => get('APP_SCRIPT_URL');
  static String get scriptSecret => get('APP_SCRIPT_SECRET');
  static String get vapidPublicKey => get('VAPID_PUBLIC_KEY');
  static String get googleDriveImagesFolderID =>
      get('GOOGLE_DRIVE_IMAGES_FOLDER_ID');
}
