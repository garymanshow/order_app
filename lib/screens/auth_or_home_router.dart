// lib/screens/auth_or_home_router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/clients_service.dart';
import '../screens/price_list_screen.dart';
import '../screens/client_selection_screen.dart';
import 'auth_phone_screen.dart';
import 'admin_dashboard_screen.dart';
import 'driver_screen.dart'; // ← добавлено
import 'manager_screen.dart'; // ← добавлено

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
        case 'Admin':
          return AdminDashboardScreen();
        case 'Driver':
          return DriverScreen();
        case 'Manager':
          return ManagerScreen();
        default:
          // Для Developer и других ролей — можно показать заглушку
          return _GenericEmployeeScreen(employee: employee);
      }
    }
    // ✅ Для клиента — ВСЕГДА показываем экран-посредник
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
        title: Text(employee.name),
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

// Новый экран-посредник
class ClientAddressOrPriceListScreen extends StatefulWidget {
  @override
  _ClientAddressOrPriceListScreenState createState() =>
      _ClientAddressOrPriceListScreenState();
}

class _ClientAddressOrPriceListScreenState
    extends State<ClientAddressOrPriceListScreen> {
  late Future<List<Client>> _clientsFuture;

  @override
  void initState() {
    super.initState();
    final phone = (Provider.of<AuthProvider>(context, listen: false).currentUser
            as Client)
        .phone;
    _clientsFuture = ClientsService().fetchClientsByPhone(phone);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Client>>(
      future: _clientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final clients = snapshot.data ?? [];
        if (clients.length == 1) {
          // Один адрес — сразу в прайс-лист
          return PriceListScreen(client: clients.first);
        } else if (clients.length > 1) {
          // Несколько адресов — выбор
          return ClientSelectionScreen(
            phone: (Provider.of<AuthProvider>(context, listen: false)
                    .currentUser as Client)
                .phone,
            clients: clients,
          );
        } else {
          return Scaffold(body: Center(child: Text('Клиент не найден')));
        }
      },
    );
  }
}
