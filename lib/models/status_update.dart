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

  Map<String, dynamic> toJson() {
    return {
      'client': client,
      'phone': phone,
      'oldStatus': oldStatus,
      'newStatus': newStatus,
    };
  }
}
