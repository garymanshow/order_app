// lib/services/web_push_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:js_interop';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/env_service.dart';

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
  external JSPromise<JSBoolean> unsubscribe();
}

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
      final available = await _checkPushManager();
      if (!available) {
        print('❌ PushManager не доступен');
        return;
      }

      final result = await _initJs();

      if (result) {
        _isInitialized = true;
        print('✅ WebPushService инициализирован');
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

  Future<bool> isSupported() async {
    if (!kIsWeb) return false;

    try {
      final available = await _checkPushManager();
      return available;
    } catch (e) {
      return false;
    }
  }

  // 🔥 Подписка на уведомления
  Future<bool> subscribe() async {
    if (!kIsWeb || !_isInitialized) return false;

    try {
      final permission = await _requestPermission();

      if (permission != 'granted') {
        print('❌ Разрешение не получено');
        return false;
      }

      if (pushManager == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('push_user_id') ?? 'unknown';
      final userId = phone.hashCode;

      final result = await pushManager!.subscribe(userId).toDart;
      final success = result.toDart;

      if (success) {
        _isSubscribed = true;

        await prefs.setBool('push_subscribed', true);
        print('✅ Подписка на уведомления оформлена для $phone');

        try {
          final subscriptionResult =
              await pushManager!.getSubscriptionData().toDart;
          await _sendSubscriptionToServer(phone, subscriptionResult);
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

  // 🔥 Отписка от уведомлений
  Future<bool> unsubscribe() async {
    if (!kIsWeb || !_isInitialized) return false;

    try {
      if (pushManager == null) return false;

      final result = await pushManager!.unsubscribe().toDart;
      final success = result.toDart;

      if (success) {
        _isSubscribed = false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('push_subscribed');

        final phone = prefs.getString('push_user_id');
        if (phone != null) {
          await _sendUnsubscribeToServer(phone);
        }

        print('✅ Отписка от уведомлений выполнена');
        return true;
      } else {
        print('❌ JS метод unsubscribe вернул false');
        return false;
      }
    } catch (e) {
      print('❌ Ошибка отписки: $e');
      return false;
    }
  }

  // 🔥 Отправка подписки на сервер
  Future<void> _sendSubscriptionToServer(
      String phone, JSObject subscriptionData) async {
    final scriptUrl = EnvService.scriptUrl;
    if (scriptUrl.isEmpty) {
      print('⚠️ URL скрипта не указан');
      return;
    }

    try {
      final subMap = subscriptionData.dartify() as Map<String, dynamic>;

      final response = await http.post(
        Uri.parse(scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'savePushSubscription',
          'phone': phone,
          'subscription': {
            'endpoint': subMap['endpoint'],
            'keys': subMap['keys'],
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Подписка отправлена на сервер для $phone');
      } else {
        print('❌ Ошибка отправки подписки: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Ошибка отправки подписки на сервер: $e');
    }
  }

  // 🔥 Уведомление сервера об отписке
  Future<void> _sendUnsubscribeToServer(String phone) async {
    final scriptUrl = EnvService.scriptUrl;
    if (scriptUrl.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'deletePushSubscription',
          'phone': phone,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Отписка отправлена на сервер для $phone');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('push_user_id');
      } else {
        print('⚠️ Ошибка отправки отписки: ${response.statusCode}');
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
