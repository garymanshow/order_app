// lib/screens/auth_or_home_router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/client.dart';
import '../providers/auth_provider.dart';
import 'auth_phone_screen.dart';
import 'admin_dashboard_screen.dart';
import 'driver_screen.dart';
import 'manager_screen.dart';
import 'warehouse_screen.dart';
import 'role_selection_screen.dart';

class AuthOrHomeRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isAuthenticated) {
      return AuthPhoneScreen();
    }

    // 🔥 НОВАЯ ЛОГИКА: ПРОВЕРКА МНОЖЕСТВЕННЫХ РОЛЕЙ
    if (authProvider.hasMultipleRoles) {
      return RoleSelectionScreen(roles: authProvider.availableRoles!);
    }

    // 🔥 СОХРАНЯЕМ ВСЮ ЛОГИКУ РОЛЕЙ ДЛЯ СОТРУДНИКОВ
    if (authProvider.isEmployee) {
      final employee = authProvider.currentUser as Employee;
      switch (employee.role) {
        case 'Администратор':
          return AdminDashboardScreen();
        case 'Водитель':
          return DriverScreen();
        case 'Менеджер':
          return ManagerScreen();
        case 'Кладовщик':
          return WarehouseScreen();
        default:
          return _GenericEmployeeScreen(employee: employee);
      }
    }

    // 🔥 ДЛЯ КЛИЕНТОВ — ИСПОЛЬЗУЕМ УЖЕ ЗАГРУЖЕННЫЕ ДАННЫЕ
    return ClientAddressOrPriceListScreen();
  }
}

class _GenericEmployeeScreen extends StatelessWidget {
  final Employee employee;

  const _GenericEmployeeScreen({Key? key, required this.employee})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(employee.name ?? 'Сотрудник'),
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
        child: Text('Роль "${employee.role}" пока не поддерживается'),
      ),
    );
  }
}

// Экран-посредник для клиентов
class ClientAddressOrPriceListScreen extends StatefulWidget {
  @override
  _ClientAddressOrPriceListScreenState createState() =>
      _ClientAddressOrPriceListScreenState();
}

class _ClientAddressOrPriceListScreenState
    extends State<ClientAddressOrPriceListScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Проверяем, что пользователь действительно клиент
    if (authProvider.currentUser == null || authProvider.isEmployee) {
      return Scaffold(body: Center(child: Text('Ошибка авторизации')));
    }

    final client = authProvider.currentUser as Client;
    final phone = client.phone;

    if (phone == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Номер телефона не указан'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                },
                child: Text('Вернуться к авторизации'),
              ),
            ],
          ),
        ),
      );
    }

    // 🔥 ПОЛУЧАЕМ КЛИЕНТОВ ИЗ УЖЕ ЗАГРУЖЕННЫХ ДАННЫХ
    final allClients = authProvider.clientData?.clients ?? [];

    print('📞 Всего клиентов в данных: ${allClients.length}');
    print('📞 Ищем клиентов с телефоном: $phone');

    // Фильтруем клиентов по телефону
    final clientsWithPhone = allClients.where((c) => c.phone == phone).toList();

    print('📞 Найдено клиентов с этим телефоном: ${clientsWithPhone.length}');

    if (clientsWithPhone.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Клиент не найден в загруженных данных'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                },
                child: Text('Вернуться к авторизации'),
              ),
            ],
          ),
        ),
      );
    }

    // 🔥 КЛЮЧЕВАЯ ЛОГИКА:
    // Если найден только один клиент → прямой переход
    // Если найдено несколько клиентов → показываем выбор
    if (clientsWithPhone.length == 1) {
      // Обновляем текущего клиента в AuthProvider
      authProvider.setClient(clientsWithPhone.first);

      // Используем WidgetsBinding для отложенного перехода
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/price');
      });

      // Возвращаем пустой контейнер, пока происходит переход
      return Container();
    } else {
      // Несколько клиентов с одним телефоном → выбор
      // Используем WidgetsBinding для отложенного перехода
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(
          context,
          '/clientSelection',
          arguments: {
            'phone': phone,
            'clients': clientsWithPhone,
          },
        );
      });

      // Возвращаем пустой контейнер, пока происходит переход
      return Container();
    }
  }
}
