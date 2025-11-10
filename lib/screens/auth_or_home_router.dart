// lib/screens/auth_or_home_router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth_phone_screen.dart';
import '../screens/home_screen.dart';
import '../screens/employee_orders_screen.dart';

/// Виджет маршрутизации: определяет, какой экран показывать
/// в зависимости от статуса авторизации.
class AuthOrHomeRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Показываем индикатор загрузки, если проверка сессии ещё не завершена
    if (authProvider.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Проверка сессии...'),
            ],
          ),
        ),
      );
    }

    // Если пользователь не авторизован — экран входа
    if (!authProvider.isAuthenticated) {
      return AuthPhoneScreen();
    }

    // Если авторизован как сотрудник — экран заказов
    if (authProvider.isEmployee) {
      return EmployeeOrdersScreen();
    }

    // Иначе — экран клиента (прайс-лист)
    return HomeScreen();
  }
}
