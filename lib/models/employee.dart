// lib/models/employee.dart
import 'user.dart';
import '../utils/parsing_utils.dart';

// Сотрудники
class Employee extends User {
  final String? role;
  final bool twoFactorAuth;
  final String? email; // 👈 ДОБАВЛЕНО поле для 2FA через Google
  String? fcm;

  Employee({
    super.name,
    super.phone,
    this.role,
    this.twoFactorAuth = false,
    this.email, // 👈 ДОБАВЛЕНО в конструктор
    this.fcm,
  });

  // 🔥 ИСПРАВЛЕННЫЙ fromMap для Google Таблиц
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      name: map['Сотрудник']?.toString(),
      phone: map['Телефон']?.toString(),
      role: map['Роль']?.toString(),
      twoFactorAuth: ParsingUtils.parseBool(map['2FA']?.toString()) ?? false,
      email: map['Email']?.toString(), // 👈 ДОБАВЛЕНО чтение email из таблицы
      fcm: map['FCM']?.toString(),
    );
  }

  // 🔥 ИСПРАВЛЕННЫЙ fromJson: читает и кэш, и формат сервера
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
      // Приоритет: 1. Обычный JSON (кэш), 2. Формат Google Таблиц (сервер)
      name: json['name']?.toString() ?? json['Сотрудник']?.toString(),
      phone: json['phone']?.toString() ?? json['Телефон']?.toString(),
      role: json['role']?.toString() ?? json['Роль']?.toString(),
      twoFactorAuth: safeBool(json['twoFactorAuth'] ?? json['2FA']),
      email: json['email']?.toString() ?? json['Email']?.toString(),
      fcm: json['fcm']?.toString() ??
          json['FCM']?.toString() ??
          json['fcmToken']?.toString(),
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
      'email': email, // 👈 ДОБАВЛЕНО сохранение в JSON
      'fcm': fcm,
    };
  }

  // 🔥 ДОБАВЛЕН toMap для Google Таблиц
  Map<String, dynamic> toMap() {
    return {
      'Сотрудник': name ?? '',
      'Телефон': phone ?? '',
      'Роль': role ?? '',
      '2FA': twoFactorAuth.toString(),
      'Email': email ?? '', // 👈 ДОБАВЛЕНО для обратной записи в таблицу
      'FCM': fcm ?? '',
    };
  }

  // Проверка, требуется ли 2FA
  bool get requiresTwoFactorAuth => twoFactorAuth;

  // Проверка наличия email для 2FA
  bool get canUseTwoFactor =>
      twoFactorAuth && email != null && email!.isNotEmpty;

  // Для отображения в списке
  String get getDisplayName {
    if (name != null && role != null) {
      return '$name ($role)';
    }
    return name ?? 'Без имени';
  }
}
