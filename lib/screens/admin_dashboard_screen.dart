// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class AdminDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser as Employee;

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.name} (${user.role})'),
        actions: [
          // 🔑 Кнопка выхода
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAdminButton(
              context,
              icon: Icons.shopping_cart_outlined,
              title: 'Заказы',
              onPressed: () {
                // TODO: переход к экрану заказов
                // Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen()));
              },
            ),
            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.list_alt_outlined,
              title: 'Прайс-лист',
              onPressed: () {
                // TODO: переход к редактору прайс-листа
                // Navigator.push(context, MaterialPageRoute(builder: (_) => PriceListEditorScreen()));
              },
            ),
            SizedBox(height: 24),
            _buildAdminButton(
              context,
              icon: Icons.people_outline,
              title: 'Клиенты',
              onPressed: () {
                // TODO: переход к редактору клиентов
                // Navigator.push(context, MaterialPageRoute(builder: (_) => ClientsEditorScreen()));
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
