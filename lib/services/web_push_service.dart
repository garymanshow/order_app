// lib/services/web_push_service.dart
import 'package:flutter/foundation.dart';
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
        debugPrint('❌ PushManager не доступен');
        return;
      }

      final result = await _initJs();

      if (result) {
        _isInitialized = true;
        debugPrint('✅ WebPushService инициализирован');
        await _checkSubscriptionStatus();
        _setupNotificationHandler();
      }
    } catch (e) {
      debugPrint('❌ Ошибка инициализации WebPushService: $e');
    }
  }

  Future<bool> _initJs() async {
    try {
      if (pushManager == null) return false;
      final result = await pushManager!.init(_vapidPublicKey!).toDart;
      return result.toDart;
    } catch (e) {
      debugPrint('❌ Ошибка инициализации JS: $e');
      return false;
    }
  }

  Future<bool> _checkPushManager() async {
    try {
      final type = typeofPushManager.toDart;
      return type != 'undefined';
    } catch (e) {
      debugPrint('❌ Ошибка проверки PushManager: $e');
      return false;
    }
  }

  Future<String?> _requestPermission() async {
    try {
      if (pushManager == null) return null;
      final result = await pushManager!.requestPermission().toDart;
      return result.toDart;
    } catch (e) {
      debugPrint('❌ Ошибка запроса разрешения: $e');
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

  set onNotificationReceived(Function(Map<String, dynamic>) callback) {
    _onNotificationReceived = callback;
  }

  // 🔥 ИСПРАВЛЕНО: Безопасный каст типов внутри обработчика
  void _setupNotificationHandler() {
    if (pushManager == null) {
      debugPrint('⚠️ PushManager is null, cannot set notification handler');
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

              debugPrint('📨 Получено уведомление: $notificationData');

              if (_onNotificationReceived != null) {
                _onNotificationReceived!(notificationData);
              }
            }
          } catch (e) {
            debugPrint('❌ Ошибка обработки уведомления: $e');
          }
        }
      }.toJS;

      pushManager!.setNotificationHandler(handler);
    } catch (e) {
      debugPrint('❌ Ошибка установки обработчика уведомлений: $e');
    }
  }

  Future<bool> subscribe() async {
    if (!kIsWeb || !_isInitialized) return false;

    try {
      final permission = await _requestPermission();

      if (permission != 'granted') {
        debugPrint('❌ Разрешение не получено');
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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('push_subscribed', true);
        await prefs.setString('push_user_id', phone);
        debugPrint('✅ Подписка на уведомления оформлена для $phone');

        // 🔥 УДАЛЯЕМ ЭТОТ БЛОК! Сервер больше не ждет отдельных запросов на сохранение.
        // Подписка сохранится автоматически при СЛЕДУЮЩЕМ входе (login) через Piggybacking.
        /*
        try {
          final subscriptionResult = await pushManager!.getSubscriptionData().toDart;
          await _sendSubscriptionToServer(phone, 'Клиент', subscriptionResult);
        } catch (e) {
          debugPrint('⚠️ Не удалось получить данные подписки: $e');
        }
        */
      }

      return success;
    } catch (e) {
      debugPrint('❌ Ошибка подписки: $e');
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
      debugPrint('❌ Ошибка получения данных подписки: $e');
      return null;
    }
  }

  // 🔥 НОВЫЙ МЕТОД: Берет текущую подписку для "прикрепления" к запросу авторизации
  // Если подписки нет (отписался или чистил кэш) - вернет null
  Future<Map<String, dynamic>?> getSubscriptionForAuth() async {
    if (!kIsWeb || !_isInitialized || pushManager == null) return null;

    try {
      // Проверяем флаг из памяти
      if (!_isSubscribed) return null;

      // Берем сырые данные из JS
      final result = await pushManager!.getSubscriptionData().toDart;
      final dynamic rawMap = result.dartify();

      if (rawMap is Map) {
        final Map<String, dynamic> typedMap = {};
        rawMap.forEach((key, value) {
          typedMap[key.toString()] = value;
        });

        // Форматируем ТОЛЬКО то, что нужно серверу
        return {
          'endpoint': typedMap['endpoint'],
          'keys': typedMap['keys'], // GAS сам превратит это в JSON строку
        };
      }

      // Если браузер вернул пустоту (подписка сдохла), сбрасываем флаг
      _isSubscribed = false;
      return null;
    } catch (e) {
      debugPrint('⚠️ Ошибка получения подписки для Auth: $e');
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

        debugPrint('✅ Отписка от уведомлений выполнена');
        return true;
      } else {
        debugPrint('❌ JS метод unsubscribe вернул false');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Ошибка отписки: $e');
      return false;
    }
  }

  // 🔥 ИСПРАВЛЕНО: Безопасный каст аргументов
  Future<void> _sendSubscriptionToServer(
      String phone, String role, JSObject subscriptionData) async {
    try {
      final dynamic rawMap = subscriptionData.dartify();

      if (rawMap is! Map) {
        debugPrint('❌ Данные подписки не являются Map');
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
        debugPrint('✅ Подписка отправлена на сервер для $phone');
      } else {
        debugPrint('❌ Ошибка отправки подписки');
      }
    } catch (e) {
      debugPrint('❌ Ошибка отправки подписки на сервер: $e');
    }
  }

  Future<void> _sendUnsubscribeToServer(String phone) async {
    try {
      final success = await _apiService.deletePushSubscription(phone);

      if (success) {
        debugPrint('✅ Отписка отправлена на сервер для $phone');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('push_user_id');
      } else {
        debugPrint('⚠️ Ошибка отправки отписки');
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка отправки отписки: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDriverSubscriptions() async {
    try {
      return await _apiService.getDriverSubscriptions();
    } catch (e) {
      debugPrint('❌ Ошибка получения подписок: $e');
      return [];
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isSubscribed = prefs.getBool('push_subscribed') ?? false;
    debugPrint(
        '📱 Статус подписки: ${_isSubscribed ? 'подписан' : 'не подписан'}');
  }

  bool get isSubscribed => _isSubscribed;
  bool get isInitialized => _isInitialized;
}
