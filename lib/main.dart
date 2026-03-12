// lib/services/web_push_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:js_interop';
import 'dart:js' as js;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/env_service.dart'; // 👈 ДЛЯ ДОСТУПА К ПЕРЕМЕННЫМ

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

  // 🔥 Подписка на уведомления с отправкой на сервер
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

          // 🔥 ОТПРАВЛЯЕМ НА СЕРВЕР
          await _sendSubscriptionToServer(subscriptionResult);
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

  // 🔥 ОТПРАВКА ПОДПИСКИ НА GAS
  Future<void> _sendSubscriptionToServer(JSObject subscriptionData) async {
    final scriptUrl = EnvService.scriptUrl;
    if (scriptUrl.isEmpty) {
      print('⚠️ URL скрипта не указан');
      return;
    }

    try {
      // Конвертируем JS объект в Map
      final subMap = subscriptionData.dartify() as Map<String, dynamic>;

      // Получаем userId из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('push_user_id') ?? 'unknown';

      // Формируем запрос
      final response = await http.post(
        Uri.parse(scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'savePushSubscription',
          'secret': EnvService.scriptSecret,
          'phone': userId,
          'subscription': {
            'endpoint': subMap['endpoint'],
            'keys': subMap['keys'],
            'userAgent': _getUserAgent(),
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Подписка отправлена на сервер');
      } else {
        print('❌ Ошибка отправки подписки: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Ошибка отправки подписки на сервер: $e');
    }
  }

  // 🔥 ПОЛУЧЕНИЕ USER-AGENT
  String _getUserAgent() {
    try {
      final navigator = js.context['navigator'];
      return navigator['userAgent'].toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  // 🔥 Отписка от уведомлений
  Future<bool> unsubscribe() async {
    if (!kIsWeb || !_isInitialized) return false;

    try {
      // TODO: реализовать отписку в JS
      _isSubscribed = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('push_subscribed');

      // 🔥 Уведомляем сервер об отписке
      await _sendUnsubscribeToServer();

      print('✅ Отписка от уведомлений выполнена');
      return true;
    } catch (e) {
      print('❌ Ошибка отписки: $e');
      return false;
    }
  }

  // 🔥 УВЕДОМЛЕНИЕ СЕРВЕРА ОБ ОТПИСКЕ
  Future<void> _sendUnsubscribeToServer() async {
    final scriptUrl = EnvService.scriptUrl;
    if (scriptUrl.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('push_user_id');

      if (userId != null) {
        await http.post(
          Uri.parse(scriptUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'deletePushSubscription',
            'secret': EnvService.scriptSecret,
            'phone': userId,
          }),
        );
        print('✅ Отписка отправлена на сервер');
      }
    } catch (e) {
      print('⚠️ Ошибка отправки отписки: $e');
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
