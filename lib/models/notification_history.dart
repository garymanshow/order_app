// lib/models/notification_history.dart
import '../utils/parsing_utils.dart';

class NotificationHistory {
  final String id;
  final String clientPhone;
  final String orderId;
  final String title;
  final String body;
  final DateTime sentAt;
  bool isRead; // ← изменяемое поле
  final String type;

  NotificationHistory({
    required this.id,
    required this.clientPhone,
    required this.orderId,
    required this.title,
    required this.body,
    required this.sentAt,
    this.isRead = false,
    required this.type,
  });

  factory NotificationHistory.fromJson(Map<String, dynamic> json) {
    return NotificationHistory(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      clientPhone: json['clientPhone']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      sentAt:
          ParsingUtils.parseDate(json['sentAt']?.toString()) ?? DateTime.now(),
      isRead: ParsingUtils.parseBool(json['isRead']) ?? false,
      type: json['type']?.toString() ?? 'order_status',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientPhone': clientPhone,
      'orderId': orderId,
      'title': title,
      'body': body,
      'sentAt': sentAt.toIso8601String(),
      'isRead': isRead,
      'type': type,
    };
  }

  // Для сохранения в SharedPreferences
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientPhone': clientPhone,
      'orderId': orderId,
      'title': title,
      'body': body,
      'sentAt':
          '${sentAt.day}.${sentAt.month}.${sentAt.year} ${sentAt.hour}:${sentAt.minute}',
      'isRead': isRead ? '1' : '0',
      'type': type,
    };
  }

  factory NotificationHistory.fromMap(Map<String, dynamic> map) {
    return NotificationHistory(
      id: map['id']?.toString() ?? '',
      clientPhone: map['clientPhone']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      sentAt: _parseDateTime(map['sentAt']?.toString() ?? ''),
      isRead: map['isRead']?.toString() == '1',
      type: map['type']?.toString() ?? 'order_status',
    );
  }

  static DateTime _parseDateTime(String dateTimeStr) {
    try {
      final parts = dateTimeStr.split(' ');
      if (parts.length == 2) {
        final dateParts = parts[0].split('.');
        final timeParts = parts[1].split(':');
        if (dateParts.length == 3 && timeParts.length == 2) {
          return DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        }
      }
    } catch (e) {
      print('Ошибка парсинга даты: $e');
    }
    return DateTime.now();
  }
}
