// lib/models/status_update.dart
class StatusUpdate {
  final String client;
  final String phone;
  final String oldStatus;
  final String newStatus;

  StatusUpdate({
    required this.client,
    required this.phone,
    required this.oldStatus,
    required this.newStatus,
  });

  // 🔥 ИСПРАВЛЕНО: безопасный toJson
  Map<String, dynamic> toJson() {
    return {
      'client': client ?? '',
      'phone': phone ?? '',
      'oldStatus': oldStatus ?? '',
      'newStatus': newStatus ?? '',
    };
  }

  // 🔥 ДОБАВЛЕНО: фабричный конструктор fromJson (на всякий случай)
  factory StatusUpdate.fromJson(Map<String, dynamic> json) {
    return StatusUpdate(
      client: json['client']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      oldStatus: json['oldStatus']?.toString() ?? '',
      newStatus: json['newStatus']?.toString() ?? '',
    );
  }
}
