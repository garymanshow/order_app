// lib/utils/env_loader.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class EnvLoader {
  static Future<void> load() async {
    if (kIsWeb) {
      // Для веба - используем значения по умолчанию
      print('🌐 Веб-платформа: пропускаем загрузку .env файла');
      return;
    }

    try {
      final envPath = Directory.current.path;
      final envFile = File('$envPath/.env');

      if (await envFile.exists()) {
        await dotenv.load(fileName: '$envPath/.env');
        print('✅ .env файл загружен');
      } else {
        print('⚠️ .env файл не найден. Используются значения по умолчанию.');
      }
    } catch (e) {
      print('⚠️ Ошибка загрузки .env: $e');
    }
  }
}
