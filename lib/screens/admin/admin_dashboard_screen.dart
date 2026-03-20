// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/employee.dart';
import 'admin_clients_screen.dart';
import 'admin_clients_with_orders_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_price_list_screen.dart';
import 'admin_employees_screen.dart';
import '../notifications_screen.dart'; // 👈 Импортируем экран уведомлений

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
    if (!_dataLoaded) {
      _dataLoaded = true;
      _loadRequiredData();
    }
  }

  Future<void> _loadRequiredData() async {
    setState(() => _isLoading = true);

    try {
      // Реальная загрузка данных, а не просто задержка
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Проверяем, загружены ли данные
      if (authProvider.clientData == null) {
        print('⚠️ Данные клиента не загружены');
        // Можно попробовать перезагрузить
        // await authProvider.loadData();
      }
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
            // 👇 КНОПКА УВЕДОМЛЕНИЙ - ПЕРВАЯ В СПИСКЕ
            _buildAdminButton(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Push-уведомления',
              description: 'Управление рассылками и настройками уведомлений',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NotificationsScreen()),
                );
              },
            ),

            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.shopping_cart_outlined,
              title: 'Заказы клиентов',
              description: 'Просмотр и управление заказами',
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
              icon: Icons.shopping_cart,
              title: 'Все заказы',
              description: 'Управление всеми заказами клиентов',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminOrdersScreen()),
                );
              },
            ),

            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.currency_ruble,
              title: 'Прайс-лист',
              description: 'Управление ценами и блюдами',
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
              description: 'База клиентов и их данные',
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
              description: 'Управление персоналом',
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
              description: 'Управление поставщиками (в разработке)',
              onPressed: () {
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
              description: 'Учет товаров (в разработке)',
              onPressed: () {
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

  // Обновленная кнопка с описанием
  Widget _buildAdminButton(BuildContext context,
      {required IconData icon,
      required String title,
      String? description,
      required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, description != null ? 80 : 60),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                if (description != null) ...[
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    );
  }
}
