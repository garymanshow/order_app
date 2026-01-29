// lib/models/employee.dart
import 'user.dart';

class Employee extends User {
  final String? role;
  final bool twoFactorAuth; // ← теперь boolean
  String? fcm;

  Employee({
    String? name,
    required String phone,
    this.role,
    this.twoFactorAuth = false, // ← значение по умолчанию
    this.fcm,
  }) : super(phone: phone, name: name);

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      phone: map['Телефон']?.toString() ?? '',
      name: map['Сотрудник']?.toString().isNotEmpty == true
          ? map['Сотрудник']?.toString()
          : null,
      role: map['Роль']?.toString().isNotEmpty == true
          ? map['Роль']?.toString()
          : null,
      twoFactorAuth: _parseBool(map['2FA']), // ← парсим boolean
      fcm: map['FCM']?.toString().isNotEmpty == true
          ? map['FCM']?.toString()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Сотрудник': name ?? '',
      'Телефон': phone ?? '',
      'Роль': role ?? '',
      '2FA': twoFactorAuth.toString(), // ← сохраняем как строку "true"/"false"
      'FCM': fcm ?? '',
    };
  }

  // Вспомогательный метод для парсинга boolean
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    final str = value.toString().toLowerCase().trim();
    return str == 'true' || str == '1' || str == 'да' || str == 'yes';
  }

  // Проверка, требуется ли 2FA
  bool get requiresTwoFactorAuth => twoFactorAuth;

  // Для отображения в списке
  String get getDisplayName {
    if (name != null && role != null) {
      return '$name ($role)';
    }
    return name ?? 'Без имени';
  }
}
