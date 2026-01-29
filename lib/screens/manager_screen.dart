// lib/screens/manager_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';

class ManagerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // 🔥 Безопасная проверка
    if (authProvider.currentUser == null ||
        !(authProvider.currentUser is Employee)) {
      return Scaffold(
        body: Center(child: Text('Ошибка авторизации')),
      );
    }

    final user = authProvider.currentUser as Employee;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name ?? 'Менеджер'), // 🔥 безопасная обработка null
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.green),
            SizedBox(height: 20),
            Text(
              'Экран менеджера',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
                'Роль: ${user.role ?? 'Не указана'}'), // 🔥 безопасная обработка null
          ],
        ),
      ),
    );
  }
}
