// lib/models/employee.dart
import 'user.dart';

class Employee extends User {
  final String? role;
  final bool twoFactorAuth;
  String? fcm;

  Employee({
    String? name,
    String? phone,
    this.role,
    this.twoFactorAuth = false,
    this.fcm,
  }) : super(phone: phone, name: name);

  // 🔥 ИСПРАВЛЕННЫЙ fromMap для Google Таблиц
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      name: map['Сотрудник']?.toString(),
      phone: map['Телефон']?.toString(),
      role: map['Роль']?.toString(),
      twoFactorAuth: _parseBool(map['2FA']?.toString()) ?? false,
      fcm: map['FCM']?.toString(),
    );
  }

  // 🔥 fromJson для восстановления из кэша
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      twoFactorAuth: json['twoFactorAuth'] as bool? ?? false,
      fcm: json['fcm'] as String?,
    );
  }

  // 🔥 toJson для сохранения в кэш
  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'role': role, // ← ключевое поле для отличия от Client
      'twoFactorAuth': twoFactorAuth,
      'fcm': fcm,
    };
  }

  // Вспомогательный метод для парсинга boolean
  static bool? _parseBool(String? value) {
    if (value == null) return null;
    final str = value.toLowerCase().trim();
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
