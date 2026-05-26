// lib/screens/auth_or_home_router.dart
import 'package:flutter/foundation.dart';
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

// 🔥 ИЗМЕНЕНО НА StatefulWidget ДЛЯ ПОДДЕРЖКИ ФЛАГА
class AuthOrHomeRouter extends StatefulWidget {
  final bool forceLanding;

  const AuthOrHomeRouter({super.key, this.forceLanding = false});

  @override
  State<AuthOrHomeRouter> createState() => _AuthOrHomeRouterState();
}

class _AuthOrHomeRouterState extends State<AuthOrHomeRouter> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final cacheService = Provider.of<CacheService>(context, listen: false);

    debugPrint('🔄 AuthOrHomeRouter build:');
    debugPrint('   - isLoading: ${authProvider.isLoading}');
    debugPrint('   - isAuthenticated: ${authProvider.isAuthenticated}');
    debugPrint(
        '   - forceLanding: ${widget.forceLanding}'); // <--- Лог для отладки

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

    // 🔥 НЕ АВТОРИЗОВАН -> проверяем, новое ли устройство
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

    return const ClientRouterScreen();
  }

  // 🔥 МАРШРУТ ДЛЯ НЕАВТОРИЗОВАННОГО (С ПОДДЕРЖКОЙ ВОЗВРАТА НА ВИТРИНУ)
  Widget _buildUnauthenticatedRoute(CacheService cacheService) {
    // 🔥 НОВОЕ: Если нажали "Назад" из авторизации — принудительно витрина
    if (widget.forceLanding) {
      debugPrint('🎯 Принудительный возврат → LandingScreen');
      return const LandingScreen();
    }

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
          debugPrint('🎯 Новое устройство → LandingScreen');
          return const LandingScreen();
        }

        // 🔥 ВОЗВРАЩАЮЩИЙСЯ ПОЛЬЗОВАТЕЛЬ → сразу вход
        debugPrint('🎯 Возвращающийся пользователь → AuthPhoneScreen');
        return const AuthPhoneScreen();
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
            icon: const Icon(Icons.logout),
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
  bool _navigationHandled = false; // 🔥 ФЛАГ ЗАЩИТЫ ОТ ПОВТОРНОЙ ОТРИСОВКИ

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_navigationHandled) {
      _navigationHandled = true; // Сразу запоминаем, что мы здесь были
      // Если нужна была какая-то логика при первом входе — она тут
    }
  }

  @override
  Widget build(BuildContext context) {
    // Используем listen: false, чтобы этот экран НЕ перерисовывался,
    // когда AuthProvider дергает notifyListeners (например, от пуш-уведомлений)
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
              const Text('Номер телефона не указан'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                },
                child: const Text('Вернуться к авторизации'),
              ),
            ],
          ),
        ),
      );
    }

    final allClients = authProvider.clientData?.clients ?? [];
    final clientsWithPhone = allClients.where((c) => c.phone == phone).toList();

    // 🔥 ЕСЛИ КЛИЕНТ УЖЕ ВЫБРАН — ПОКАЗЫВАЕМ ПРАЙС-ЛИСТ
    if (authProvider.clientSelected && clientsWithPhone.isNotEmpty) {
      return const PriceListScreen();
    }

    if (clientsWithPhone.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Клиент не найден'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                },
                child: const Text('Выйти'),
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
