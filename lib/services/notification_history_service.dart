// lib/services/notification_history_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_history.dart';

class NotificationHistoryService {
  static const String _storageKey = 'notification_history';

  // Сохранить уведомление
  static Future<void> saveNotification(NotificationHistory notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> saved = prefs.getStringList(_storageKey) ?? [];

      saved.add(jsonEncode(notification.toJson()));
      await prefs.setStringList(_storageKey, saved);

      print('✅ Уведомление сохранено в историю');
    } catch (e) {
      print('❌ Ошибка сохранения уведомления: $e');
    }
  }

  // Получить историю для клиента
  static Future<List<NotificationHistory>> getClientHistory(
      String clientPhone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> saved = prefs.getStringList(_storageKey) ?? [];

      return saved
          .map((item) => NotificationHistory.fromJson(jsonDecode(item)))
          .where((n) => n.clientPhone == clientPhone)
          .toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    } catch (e) {
      print('❌ Ошибка загрузки истории: $e');
      return [];
    }
  }

  // Отметить как прочитанное
  static Future<void> markAsRead(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> saved = prefs.getStringList(_storageKey) ?? [];

      final updated = saved.map((item) {
        final notification = NotificationHistory.fromJson(jsonDecode(item));
        if (notification.id == notificationId) {
          notification.isRead = true;
          return jsonEncode(notification.toJson());
        }
        return item;
      }).toList();

      await prefs.setStringList(_storageKey, updated);
    } catch (e) {
      print('❌ Ошибка обновления статуса: $e');
    }
  }

  // Очистить историю
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('❌ Ошибка очистки истории: $e');
    }
  }
}
