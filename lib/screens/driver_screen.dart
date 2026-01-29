// lib/screens/driver_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';

class DriverScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // 🔥 Безопасная проверка на null
    if (authProvider.currentUser == null ||
        !(authProvider.currentUser is Employee)) {
      return Scaffold(
        body: Center(child: Text('Ошибка авторизации')),
      );
    }

    final user = authProvider.currentUser as Employee;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name ?? 'Водитель'), // 🔥 безопасная обработка null
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
            Icon(Icons.directions_car, size: 64, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'Экран водителя',
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
