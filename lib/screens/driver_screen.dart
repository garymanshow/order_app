// lib/screens/driver_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';
import '../services/web_push_service.dart';
import '../services/env_service.dart';
import 'driver_route_screen.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final WebPushService _pushService = WebPushService();
  bool _hasNewRoute = false;
  int _readyOrdersCount = 0;
  int _clientsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPushService();
    _loadRouteInfo();
    _checkForNewRoute();
  }

  Future<void> _initPushService() async {
    try {
      await _pushService.initialize(EnvService.vapidPublicKey);

      // Подписываемся на уведомления
      if (!_pushService.isSubscribed) {
        await _pushService.subscribe();
      }

      print('✅ Push сервис инициализирован для водителя');
    } catch (e) {
      print('⚠️ Ошибка инициализации push: $e');
    }
  }

  void _loadRouteInfo() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];
    final allClients = authProvider.clientData?.clients ?? [];

    // Считаем заказы со статусом "готов"
    _readyOrdersCount = allOrders.where((o) => o.status == 'готов').length;

    // Считаем уникальных клиентов с готовыми заказами
    final clientsWithReadyOrders = <String>{};
    for (var order in allOrders) {
      if (order.status == 'готов' && order.clientName.isNotEmpty) {
        clientsWithReadyOrders.add(order.clientName);
      }
    }
    _clientsCount = clientsWithReadyOrders.length;

    _isLoading = false;
  }

  Future<void> _checkForNewRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRoute = prefs.getString('last_route_date');
      final today = DateTime.now().toIso8601String().split('T')[0];

      setState(() {
        _hasNewRoute = lastRoute != today && _readyOrdersCount > 0;
      });
    } catch (e) {
      print('⚠️ Ошибка проверки нового маршрута: $e');
    }
  }

  Future<void> _markRouteAsViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_route_date', today);
      setState(() {
        _hasNewRoute = false;
      });
    } catch (e) {
      print('⚠️ Ошибка сохранения статуса: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.currentUser == null ||
        authProvider.currentUser is! Employee) {
      return Scaffold(
        body: Center(child: Text('Ошибка авторизации')),
      );
    }

    final user = authProvider.currentUser as Employee;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name ?? 'Водитель'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _loadRouteInfo();
                await _checkForNewRoute();
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Приветствие
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Здравствуйте, ${user.name ?? 'водитель'}!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Роль: ${user.role ?? 'Водитель'}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Информация о маршруте
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.route, color: Colors.blue, size: 28),
                                SizedBox(width: 12),
                                Text(
                                  'Сегодняшний маршрут',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_hasNewRoute)
                                  Container(
                                    margin: EdgeInsets.only(left: 8),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.inventory,
                                    value: '$_readyOrdersCount',
                                    label: 'Заказов',
                                    color: Colors.orange,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.people,
                                    value: '$_clientsCount',
                                    label: 'Клиентов',
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _readyOrdersCount > 0
                                    ? () async {
                                        await _markRouteAsViewed();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DriverRouteScreen(),
                                          ),
                                        ).then((_) {
                                          _loadRouteInfo();
                                          _checkForNewRoute();
                                        });
                                      }
                                    : null,
                                icon: Icon(Icons.map),
                                label: Text(
                                  'ОТКРЫТЬ МАРШРУТНЫЙ ЛИСТ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _readyOrdersCount > 0
                                      ? Colors.blue
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                            if (_readyOrdersCount == 0)
                              Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  'Нет готовых заказов для доставки',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // История последних маршрутов (опционально)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Последние маршруты',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildLastRouteItem(
                              '20 марта 2026',
                              'доставлен',
                              Colors.green,
                            ),
                            _buildLastRouteItem(
                              '19 марта 2026',
                              'доставлен',
                              Colors.green,
                            ),
                            _buildLastRouteItem(
                              '18 марта 2026',
                              'корректировка',
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastRouteItem(String date, String status, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              date,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
