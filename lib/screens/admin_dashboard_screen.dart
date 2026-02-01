// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';
import 'admin_clients_screen.dart';
import 'admin_clients_with_orders_screen.dart';
import 'admin_price_list_screen.dart';
import 'admin_employees_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  String? _error;
  bool _dataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Загружаем данные только один раз при первом построении
    if (!_dataLoaded) {
      _dataLoaded = true;
      _loadRequiredData();
    }
  }

  Future<void> _loadRequiredData() async {
    setState(() => _isLoading = true);

    try {
      // Данные уже загружены при авторизации через "умную загрузку"
      // Здесь можно добавить дополнительную логику если нужно
      // Например, проверку актуальности данных

      // Пока просто ждем немного для UX
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      setState(() => _error = 'Ошибка загрузки данных: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser as Employee?;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Не авторизован')),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Загрузка данных...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Ошибка')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRequiredData,
                child: Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.name} (${user.role})'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRequiredData,
            tooltip: 'Обновить данные',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            _buildAdminButton(
              context,
              icon: Icons.shopping_cart_outlined,
              title: 'Заказы клиентов',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AdminClientsWithOrdersScreen()),
                );
              },
            ),
            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.currency_ruble,
              title: 'Прайс-лист',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminPriceListScreen()),
                );
              },
            ),
            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.people_outline,
              title: 'Клиенты',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminClientsScreen()),
                );
              },
            ),
            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.people,
              title: 'Сотрудники',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminEmployeesScreen()),
                );
              },
            ),
            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.food_bank_outlined,
              title: 'Поставщики',
              onPressed: () {
                // TODO: переход к редактору контрагентов
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Функция в разработке')),
                );
              },
            ),
            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.warehouse,
              title: 'Склад',
              onPressed: () {
                // TODO: переход к редактору склада
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Функция в разработке')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminButton(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(
        title,
        style: TextStyle(fontSize: 20),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 60),
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
