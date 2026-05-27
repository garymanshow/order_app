import 'user.dart';
import '../utils/parsing_utils.dart';

// Сотрудники
class Employee extends User {
  final String? role;
  final bool twoFactorAuth;
  final String? email;

  // 🔥 УДАЛЕНО: String? fcm;

  Employee({
    super.name,
    super.phone,
    this.role,
    this.twoFactorAuth = false,
    this.email,
    // 🔥 УДАЛЕНО: this.fcm,
  });

  // 🔥 fromMap для Google Таблиц
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      name: map['Сотрудник']?.toString(),
      phone: map['Телефон']?.toString(),
      role: map['Роль']?.toString(),
      twoFactorAuth: ParsingUtils.parseBool(map['2FA']?.toString()) ?? false,
      email: map['Email']?.toString(),
      // 🔥 УДАЛЕНО: fcm: map['FCM']?.toString(),
    );
  }

  // 🔥 fromJson: читает и кэш, и формат сервера
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      // Приоритет: 1. Обычный JSON (кэш), 2. Формат Google Таблиц (сервер)
      name: json['name']?.toString() ?? json['Сотрудник']?.toString(),
      phone: json['phone']?.toString() ?? json['Телефон']?.toString(),
      role: json['role']?.toString() ?? json['Роль']?.toString(),
      twoFactorAuth:
          ParsingUtils.parseBool(json['twoFactorAuth'] ?? json['2FA']) ?? false,
      email: json['email']?.toString() ?? json['Email']?.toString(),
      // 🔥 УДАЛЕНО: чтение fcm
    );
  }

  // toJson для сохранения в кэш
  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
      'twoFactorAuth': twoFactorAuth,
      'email': email,
      // 🔥 УДАЛЕНО: 'fcm': fcm,
    };
  }

  // toMap для обратной записи в Google Таблицы
  Map<String, dynamic> toMap() {
    return {
      'Сотрудник': name ?? '',
      'Телефон': phone ?? '',
      'Роль': role ?? '',
      '2FA': twoFactorAuth.toString(),
      'Email': email ?? '',
      // 🔥 УДАЛЕНО: 'FCM': fcm ?? '',
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
