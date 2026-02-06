// lib/models/status_update.dart
class StatusUpdate {
  final String client;
  final String phone;
  final String newStatus;

  StatusUpdate({
    required this.client,
    required this.phone,
    required this.newStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'client': client,
      'phone': phone,
      'newStatus': newStatus,
    };
  }
}
