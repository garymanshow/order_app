// lib/services/web_push_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:js_interop';

@JS('PushManager')
external JSPushManager? get pushManager;

@JS()
@staticInterop
class JSPushManager {}

extension JSPushManagerExtension on JSPushManager {
  external JSPromise<JSBoolean> init(String vapidKey);
  external JSPromise<JSString> requestPermission();
  external JSPromise<JSBoolean> subscribe(int userId);
  external JSPromise<JSObject> getSubscriptionData();
}

// Определяем JS функцию для проверки наличия PushManager
@JS('typeofPushManager')
external JSString get typeofPushManager;

class WebPushService {
  static final WebPushService _instance = WebPushService._internal();
  factory WebPushService() => _instance;
  WebPushService._internal();

  bool _isInitialized = false;
  bool _isSubscribed = false;
  String? _vapidPublicKey;

  Future<void> initialize(String vapidPublicKey) async {
    if (!kIsWeb) {
      print('📱 Push-уведомления работают только в веб-версии');
      return;
    }

    if (_isInitialized) return;

    _vapidPublicKey = vapidPublicKey;

    try {
      // Проверяем доступность PushManager
      final available = await _checkPushManager();
      if (!available) {
        print('❌ PushManager не доступен');
        return;
      }

      // Инициализируем
      final result = await _initJs();

      if (result) {
        _isInitialized = true;
        print('✅ WebPushService инициализирован');

        // Проверяем текущий статус
        await _checkSubscriptionStatus();
      }
    } catch (e) {
      print('❌ Ошибка инициализации WebPushService: $e');
    }
  }

  Future<bool> _initJs() async {
    try {
      if (pushManager == null) return false;
      final result = await pushManager!.init(_vapidPublicKey!).toDart;
      return result.toDart;
    } catch (e) {
      print('❌ Ошибка инициализации JS: $e');
      return false;
    }
  }

  Future<bool> _checkPushManager() async {
    try {
      // 🔧 ИСПРАВЛЕНО: используем JS функцию для проверки
      final type = typeofPushManager.toDart;
      return type != 'undefined';
    } catch (e) {
      print('❌ Ошибка проверки PushManager: $e');
      return false;
    }
  }

  Future<String?> _requestPermission() async {
    try {
      if (pushManager == null) return null;
      final result = await pushManager!.requestPermission().toDart;
      return result.toDart;
    } catch (e) {
      print('❌ Ошибка запроса разрешения: $e');
      return null;
    }
  }

  Future<bool> subscribe() async {
    if (!kIsWeb || !_isInitialized) return false;

    try {
      // Запрашиваем разрешение
      final permission = await _requestPermission();

      if (permission != 'granted') {
        print('❌ Разрешение не получено');
        return false;
      }

      // Подписываемся
      if (pushManager == null) return false;
      final result = await pushManager!.subscribe(0).toDart;
      final success = result.toDart;

      if (success) {
        _isSubscribed = true;

        // Сохраняем статус
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('push_subscribed', true);

        print('✅ Подписка на уведомления оформлена');

        // Получаем данные подписки для отправки на сервер
        try {
          final subscriptionResult =
              await pushManager!.getSubscriptionData().toDart;
          print('📦 Данные подписки: $subscriptionResult');

          // TODO: отправить subscriptionData на ваш сервер
        } catch (e) {
          print('⚠️ Не удалось получить данные подписки: $e');
        }
      }

      return success;
    } catch (e) {
      print('❌ Ошибка подписки: $e');
      return false;
    }
  }

  Future<bool> unsubscribe() async {
    if (!kIsWeb || !_isInitialized) return false;

    try {
      // TODO: реализовать отписку
      _isSubscribed = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('push_subscribed');

      print('✅ Отписка от уведомлений выполнена');
      return true;
    } catch (e) {
      print('❌ Ошибка отписки: $e');
      return false;
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isSubscribed = prefs.getBool('push_subscribed') ?? false;
    print('📱 Статус подписки: ${_isSubscribed ? 'подписан' : 'не подписан'}');
  }

  bool get isSubscribed => _isSubscribed;
  bool get isInitialized => _isInitialized;
}
