// lib/screens/auth_or_home_router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/client.dart';
import '../providers/auth_provider.dart';
import '../services/cache_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_warehouse_screen.dart';
import 'site/landing_screen.dart';
import 'auth_phone_screen.dart';
import 'client_selection_screen.dart';
import 'driver_screen.dart';
import 'manager/manager_dashboard_screen.dart';
import 'role_selection_screen.dart';
import 'price_list_screen.dart';

class AuthOrHomeRouter extends StatelessWidget {
  const AuthOrHomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final cacheService = Provider.of<CacheService>(context, listen: false);

    print('🔄 AuthOrHomeRouter build:');
    print('   - isLoading: ${authProvider.isLoading}');
    print('   - isAuthenticated: ${authProvider.isAuthenticated}');

    // 🔥 ЗАГРУЗКА
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔥 АВТОРИЗОВАН → сразу к прайсу/дашборду
    if (authProvider.isAuthenticated) {
      return _buildAuthenticatedRoute(authProvider);
    }

    // 🔥 НЕ АВТОРИЗОВАН → проверяем, новое ли устройство
    return _buildUnauthenticatedRoute(cacheService);
  }

  // 🔥 МАРШРУТ ДЛЯ АВТОРИЗОВАННОГО
  Widget _buildAuthenticatedRoute(AuthProvider authProvider) {
    if (authProvider.hasMultipleRoles) {
      return RoleSelectionScreen(roles: authProvider.availableRoles!);
    }

    if (authProvider.isEmployee) {
      final employee = authProvider.currentUser as Employee;
      switch (employee.role) {
        case 'Администратор':
          return AdminDashboardScreen();
        case 'Водитель':
          return DriverScreen();
        case 'Менеджер':
          return ManagerDashboardScreen();
        case 'Кладовщик':
          return AdminWarehouseScreen();
        default:
          return _GenericEmployeeScreen(employee: employee);
      }
    }

    return ClientRouterScreen();
  }

  // 🔥 МАРШРУТ ДЛЯ НЕАВТОРИЗОВАННОГО (НОВАЯ ЛОГИКА!)
  Widget _buildUnauthenticatedRoute(CacheService cacheService) {
    return FutureBuilder<bool>(
      future: cacheService.hasBeenUsed(),
      builder: (context, snapshot) {
        // Пока проверяем кэш — показываем загрузку
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 🔥 НОВОЕ УСТРОЙСТВО → показываем лендинг
        if (snapshot.data == false || snapshot.hasError) {
          print('🎯 Новое устройство → LandingScreen');
          return LandingScreen();
        }

        // 🔥 ВОЗВРАЩАЮЩИЙСЯ ПОЛЬЗОВАТЕЛЬ → сразу вход
        print('🎯 Возвращающийся пользователь → AuthPhoneScreen');
        return AuthPhoneScreen();
      },
    );
  }
}

class _GenericEmployeeScreen extends StatelessWidget {
  final Employee employee;

  const _GenericEmployeeScreen({super.key, required this.employee});

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
class ClientRouterScreen extends StatefulWidget {
  const ClientRouterScreen({super.key});

  @override
  _ClientRouterScreenState createState() => _ClientRouterScreenState();
}

class _ClientRouterScreenState extends State<ClientRouterScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndNavigate();
  }

  void _checkAndNavigate() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.currentUser == null || authProvider.isEmployee) {
      return;
    }

    final client = authProvider.currentUser as Client;
    final phone = client.phone;

    if (phone == null) return;

    final allClients = authProvider.clientData?.clients ?? [];
    final clientsWithPhone = allClients.where((c) => c.phone == phone).toList();

    // 🔥 ПРОВЕРЯЕМ, НУЖНО ЛИ ПЕРЕХОДИТЬ
    // Если клиент уже выбран, показываем прайс-лист
    if (authProvider.clientSelected && clientsWithPhone.isNotEmpty) {
      // Не делаем переход здесь, чтобы не было рекурсии
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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

    final allClients = authProvider.clientData?.clients ?? [];
    final clientsWithPhone = allClients.where((c) => c.phone == phone).toList();

    print('📞 Всего клиентов: ${allClients.length}');
    print('📞 Клиентов с телефоном $phone: ${clientsWithPhone.length}');

    // 🔥 ЕСЛИ КЛИЕНТ УЖЕ ВЫБРАН — ПОКАЗЫВАЕМ ПРАЙС-ЛИСТ
    if (authProvider.clientSelected && clientsWithPhone.isNotEmpty) {
      return PriceListScreen();
    }

    if (clientsWithPhone.isEmpty) {
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
                child: Text('Выйти'),
              ),
            ],
          ),
        ),
      );
    }

    // 🔥 ПОКАЗЫВАЕМ СПИСОК КЛИЕНТОВ
    return ClientSelectionScreen(
      phone: phone,
      clients: clientsWithPhone,
    );
  }
}
