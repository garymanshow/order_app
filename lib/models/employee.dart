// lib/models/employee.dart
import 'user.dart';
import '../utils/parsing_utils.dart';

// Сотрудники
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
      twoFactorAuth: ParsingUtils.parseBool(map['2FA']?.toString()) ?? false,
      fcm: map['FCM']?.toString(),
    );
  }

  // 🔥 БЕЗОПАСНЫЙ fromJson для восстановления из кэша
  factory Employee.fromJson(Map<String, dynamic> json) {
    // Безопасное преобразование bool
    bool safeBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value == 1;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return false;
    }

    return Employee(
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString(),
      twoFactorAuth: safeBool(json['twoFactorAuth']),
      fcm: json['fcm']?.toString(),
    );
  }

  // 🔥 ИСПРАВЛЕНО: безопасный toJson для сохранения в кэш
  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
      'twoFactorAuth': twoFactorAuth,
      'fcm': fcm,
    };
  }
  // Здесь всё нормально, так как JSON допускает null значения
  // name, phone, role, fcm могут быть null - это допустимо

  // 🔥 ДОБАВЛЕН toMap для Google Таблиц
  Map<String, dynamic> toMap() {
    return {
      'Сотрудник': name ?? '',
      'Телефон': phone ?? '',
      'Роль': role ?? '',
      '2FA': twoFactorAuth.toString(),
      'FCM': fcm ?? '',
    };
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
