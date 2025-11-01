// lib/screens/employee_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // ← для kDebugMode
import '../providers/auth_provider.dart';
import '../models/user.dart';

class EmployeeOrdersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser as Employee;

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказы (${user.role})'),
        actions: [
          // 🔑 Кнопка "Сброс" только для Developer в режиме отладки
          if (kDebugMode && user.role.toLowerCase() == 'developer')
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.orange),
              onPressed: () {
                _showLogoutDialog(context, authProvider);
              },
              tooltip: 'Сбросить сессию (отладка)',
            ),
        ],
      ),
      body: Center(
        child: Text('Экран управления заказами'),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Сброс аутентификации'),
        content: Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              authProvider.logout();
            },
            child: Text('Выйти'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
