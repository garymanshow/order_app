// lib/utils/user_utils.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';

class UserUtils {
  // Получение пользователей по роли из ClientData
  static List<Employee> getUsersByRole(BuildContext context, String role) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.clientData == null) return [];

    // В clientData.clients хранятся все пользователи (клиенты и сотрудники)
    // Нам нужны только сотрудники с указанной ролью
    final allClients = authProvider.clientData!.clients;

    // Фильтруем сотрудников по роли
    final employees = allClients.whereType<Employee>().toList();

    return employees
        .where((e) => e.role == role && e.phone != null && e.phone!.isNotEmpty)
        .toList();
  }

  // Получение телефонов пользователей по роли
  static List<String> getUserPhonesByRole(BuildContext context, String role) {
    final users = getUsersByRole(context, role);
    return users.map((e) => e.phone!).toList();
  }

  // Проверка, есть ли пользователи с указанной ролью
  static bool hasUsersWithRole(BuildContext context, String role) {
    return getUsersByRole(context, role).isNotEmpty;
  }
}
