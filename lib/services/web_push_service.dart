// lib/services/web_push_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:js_interop';
import '../services/api_service.dart';

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
  external void setNotificationHandler(JSFunction handler);
}

@JS('typeofPushManager')
external JSString get typeofPushManager;

class WebPushService {
  static final WebPushService _instance = WebPushService._internal();
  factory WebPushService() => _instance;
  WebPushService._internal();

  final ApiService _apiService = ApiService();

  bool _isInitialized = false;
  bool _isSubscribed = false;
  String? _vapidPublicKey;
  Function(Map<String, dynamic>)? _onNotificationReceived;

  Future<void> initialize(String vapidPublicKey) async {
    if (!kIsWeb) return;
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
        _setupNotificationHandler();
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

  void set onNotificationReceived(Function(Map<String, dynamic>) callback) {
    _onNotificationReceived = callback;
  }

  // 🔥 ИСПРАВЛЕНО: Безопасный каст типов внутри обработчика
  void _setupNotificationHandler() {
    if (pushManager == null) {
      print('⚠️ PushManager is null, cannot set notification handler');
      return;
    }

    try {
      final handler = (JSAny? data) {
        if (data != null) {
          try {
            final dynamic rawMap = data.dartify();

            // 🔥 ВОЗВРАЩАЕМ КОСТЫЛЬ (он необходим для Web)
            // dartify возвращает LinkedMap<Object?, Object?>, нельзя кастовать напрямую
            if (rawMap is Map) {
              final Map<String, dynamic> notificationData = {};
              rawMap.forEach((key, value) {
                notificationData[key.toString()] = value;
              });

              print('📨 Получено уведомление: $notificationData');

              if (_onNotificationReceived != null) {
                _onNotificationReceived!(notificationData);
              }
            }
          } catch (e) {
            print('❌ Ошибка обработки уведомления: $e');
          }
        }
      }.toJS;

      pushManager!.setNotificationHandler(handler);
    } catch (e) {
      print('❌ Ошибка установки обработчика уведомлений: $e');
    }
  }

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
        await prefs.setString('push_user_id', phone);
        print('✅ Подписка на уведомления оформлена для $phone');

        try {
          final subscriptionResult =
              await pushManager!.getSubscriptionData().toDart;
          await _sendSubscriptionToServer(
              phone, 'Клиент', subscriptionResult); // Исправил роль на Клиент
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

  Future<Map<String, dynamic>?> getSubscriptionData() async {
    if (!kIsWeb || !_isInitialized || pushManager == null) return null;

    try {
      final result = await pushManager!.getSubscriptionData().toDart;
      final dynamic rawMap = result.dartify();

      // 🔥 Безопасный каст
      if (rawMap is Map) {
        final Map<String, dynamic> typedMap = {};
        rawMap.forEach((key, value) {
          typedMap[key.toString()] = value;
        });
        return typedMap;
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения данных подписки: $e');
      return null;
    }
  }

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

  // 🔥 ИСПРАВЛЕНО: Безопасный каст аргументов
  Future<void> _sendSubscriptionToServer(
      String phone, String role, JSObject subscriptionData) async {
    try {
      final dynamic rawMap = subscriptionData.dartify();

      if (rawMap is! Map) {
        print('❌ Данные подписки не являются Map');
        return;
      }

      // Создаем правильно типизированную Map
      final Map<String, dynamic> subMap = {};
      rawMap.forEach((key, value) {
        subMap[key.toString()] = value;
      });

      final success = await _apiService.savePushSubscription(
        phone: phone,
        role: role,
        subscription: {
          'endpoint': subMap['endpoint'],
          'keys': subMap['keys'],
        },
      );

      if (success) {
        print('✅ Подписка отправлена на сервер для $phone');
      } else {
        print('❌ Ошибка отправки подписки');
      }
    } catch (e) {
      print('❌ Ошибка отправки подписки на сервер: $e');
    }
  }

  Future<void> _sendUnsubscribeToServer(String phone) async {
    try {
      final success = await _apiService.deletePushSubscription(phone);

      if (success) {
        print('✅ Отписка отправлена на сервер для $phone');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('push_user_id');
      } else {
        print('⚠️ Ошибка отправки отписки');
      }
    } catch (e) {
      print('⚠️ Ошибка отправки отписки: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDriverSubscriptions() async {
    try {
      return await _apiService.getDriverSubscriptions();
    } catch (e) {
      print('❌ Ошибка получения подписок: $e');
      return [];
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
