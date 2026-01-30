// lib/screens/auth_or_home_router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart'; // ← добавлен импорт Employee
import '../models/client.dart'; // ← добавлен импорт Client
import '../providers/auth_provider.dart';
import '../services/clients_service.dart';
import 'price_list_screen.dart';
import 'client_selection_screen.dart';
import 'auth_phone_screen.dart';
import 'admin_dashboard_screen.dart';
import 'driver_screen.dart';
import 'manager_screen.dart';
import 'warehouse_screen.dart'; // ← добавлено для кладовщика

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
          return WarehouseScreen(); // ← новый экран
        default:
          return _GenericEmployeeScreen(employee: employee);
      }
    }

    // Для клиента — показываем экран-посредник
    return ClientAddressOrPriceListScreen();
  }
}

// Заглушка для других ролей
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
    return FutureBuilder<List<Client>>(
      future: ClientsService().fetchClientsByPhone(phone),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('❌ Ошибка загрузки данных'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      authProvider.logout();
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (route) => false);
                    },
                    child: Text('Попробовать снова'),
                  ),
                ],
              ),
            ),
          );
        }

        final clients = snapshot.data ?? [];

        if (clients.isEmpty) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Клиент не найден'),
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

        if (clients.length == 1) {
          return PriceListScreen(client: clients.first);
        } else {
          return ClientSelectionScreen(
            phone: phone,
            clients: clients,
          );
        }
      },
    );
  }
}
