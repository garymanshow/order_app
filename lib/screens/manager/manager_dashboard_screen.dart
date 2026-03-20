// lib/screens/manager/manager_dashboard_screen.dart (исправленный)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/employee.dart';
import '../../services/api_service.dart';
import '../../services/production_service.dart';
import '../../services/warehouse_service.dart';

// Импорты экранов менеджера
import 'manager_orders_screen.dart';
import 'manager_production_screen.dart';
import 'manager_fillings_screen.dart';
import 'manager_composition_screen.dart';
import 'manager_warehouse_screen.dart';
import 'manager_price_list_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  @override
  _ManagerDashboardScreenState createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  bool _isLoading = false;
  String? _error;
  bool _dataLoaded = false;

  // Данные для отображения
  int _readyOrdersCount = 0;
  List<String> _lowStockAlerts = [];
  Map<String, double> _fillingBalances = {};
  Map<String, double> _productBalances = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _dataLoaded = true;
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final productionService =
          Provider.of<ProductionService>(context, listen: false);
      final warehouseService =
          Provider.of<WarehouseService>(context, listen: false);

      await Future.wait([
        _loadOrdersStats(apiService),
        _loadProductionBalances(productionService),
        _loadWarehouseAlerts(warehouseService),
      ]);
    } catch (e) {
      setState(() => _error = 'Ошибка загрузки данных: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrdersStats(ApiService apiService) async {
    try {
      final orders = await apiService.fetchOrders();
      if (orders != null) {
        setState(() {
          _readyOrdersCount = orders
              .where((o) => o['status'] == 'готов' || o['Статус'] == 'готов')
              .length;
        });
      }
    } catch (e) {
      print('Ошибка загрузки статистики заказов: $e');
    }
  }

  Future<void> _loadProductionBalances(
      ProductionService productionService) async {
    try {
      final balances = await productionService.getProductionBalances();
      setState(() {
        _fillingBalances = balances['fillings'] ?? {};
        _productBalances = balances['products'] ?? {};
      });
    } catch (e) {
      print('Ошибка загрузки остатков производства: $e');
    }
  }

  Future<void> _loadWarehouseAlerts(WarehouseService warehouseService) async {
    try {
      final alerts = await warehouseService.getLowStockAlerts();
      setState(() {
        _lowStockAlerts = alerts;
      });
    } catch (e) {
      print('Ошибка загрузки уведомлений склада: $e');
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
                onPressed: _loadDashboardData,
                child: Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.name} (Менеджер)'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
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
            _buildStatsRow(),
            SizedBox(height: 24),
            _buildManagerButton(
              context,
              icon: Icons.shopping_cart_outlined,
              title: 'Заказы',
              description: 'Управление заказами',
              badge: _readyOrdersCount > 0 ? '$_readyOrdersCount готовы' : null,
              badgeColor: Colors.green,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManagerOrdersScreen()),
                );
              },
            ),
            SizedBox(height: 16),
            _buildManagerButton(
              context,
              icon: Icons.factory_outlined,
              title: 'Производство',
              description: 'Операции производства, остатки начинок',
              badge: _getProductionBadge(),
              badgeColor: Colors.blue,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManagerProductionScreen()),
                );
              },
            ),
            SizedBox(height: 16),
            _buildManagerButton(
              context,
              icon: Icons.category_outlined,
              title: 'Начинки',
              description: 'Управление начинками',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManagerFillingsScreen()),
                );
              },
            ),
            SizedBox(height: 16),
            _buildManagerButton(
              context,
              icon: Icons.menu_book_outlined,
              title: 'Состав',
              description: 'Редактирование состава',
              onPressed: () {
                _showCompositionTypeDialog(context);
              },
            ),
            SizedBox(height: 16),
            _buildManagerButton(
              context,
              icon: Icons.inventory_outlined,
              title: 'Склад',
              description: 'Остатки ингредиентов',
              badge: _lowStockAlerts.isNotEmpty
                  ? '${_lowStockAlerts.length} мало'
                  : null,
              badgeColor: Colors.orange,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManagerWarehouseScreen()),
                );
              },
            ),
            SizedBox(height: 16),
            _buildManagerButton(
              context,
              icon: Icons.attach_money,
              title: 'Прайс-лист',
              description: 'Управление прайс-листом',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManagerPriceListScreen()),
                );
              },
            ),
            SizedBox(height: 24),
            if (_lowStockAlerts.isNotEmpty) _buildAlertsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.production_quantity_limits,
              value: '${_fillingBalances.length}',
              label: 'Видов начинок',
              color: Colors.blue,
            ),
            _buildStatItem(
              icon: Icons.inventory,
              value: '${_productBalances.length}',
              label: 'Видов продукции',
              color: Colors.green,
            ),
            _buildStatItem(
              icon: Icons.warning,
              value: '${_lowStockAlerts.length}',
              label: 'Уведомлений',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildManagerButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? description,
    String? badge,
    Color? badgeColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, description != null ? 90 : 70),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 2,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.pressed)
              ? Colors.blue.withValues(alpha: 0.1)
              : null,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue[800], size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? Colors.blue)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: badgeColor ?? Colors.blue,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            color: badgeColor ?? Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (description != null) ...[
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue[400]),
        ],
      ),
    );
  }

  Widget _buildAlertsCard() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[800]),
                SizedBox(width: 8),
                Text(
                  'Требуют внимания',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._lowStockAlerts.take(3).map((alert) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.fiber_manual_record,
                          size: 8, color: Colors.orange[800]),
                      SizedBox(width: 8),
                      Expanded(child: Text(alert)),
                    ],
                  ),
                )),
            if (_lowStockAlerts.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '...и еще ${_lowStockAlerts.length - 3}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getProductionBadge() {
    if (_fillingBalances.isEmpty) return '';

    final lowFillings =
        _fillingBalances.entries.where((e) => e.value < 2).length;
    return lowFillings > 0 ? '$lowFillings мало' : '';
  }

  void _showCompositionTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Выберите тип состава'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.category, color: Colors.blue),
              title: Text('Состав начинок'),
              subtitle: Text('Ингредиенты для производства начинок'),
              onTap: () {
                Navigator.pop(context);
                _showFillingSelectionDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.restaurant_menu, color: Colors.green),
              title: Text('Состав продукции'),
              subtitle: Text('Ингредиенты и начинки для готовых блюд'),
              onTap: () {
                Navigator.pop(context);
                _showProductSelectionDialog(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _showFillingSelectionDialog(BuildContext context) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final fillings = await apiService.fetchFillings();

    if (fillings == null || fillings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Нет доступных начинок')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Выберите начинку'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: fillings.length,
            itemBuilder: (context, index) {
              final filling = fillings[index];
              return ListTile(
                title: Text(filling['name']?.toString() ??
                    filling['Наименование']?.toString() ??
                    ''),
                subtitle: Text('ID: ${filling['id'] ?? filling['ID'] ?? ''}'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManagerCompositionScreen(
                        sourceSheet: 'Начинки',
                        sourceId:
                            (filling['id'] ?? filling['ID'] ?? '').toString(),
                        sourceName: filling['name']?.toString() ??
                            filling['Наименование']?.toString() ??
                            '',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _showProductSelectionDialog(BuildContext context) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final products = await apiService.fetchProducts();

    if (products == null || products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Нет доступных продуктов')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Выберите продукт'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product['name']?.toString() ??
                    product['Название']?.toString() ??
                    ''),
                subtitle: Text('ID: ${product['id'] ?? product['ID'] ?? ''}'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManagerCompositionScreen(
                        sourceSheet: 'Прайс-лист',
                        sourceId:
                            (product['id'] ?? product['ID'] ?? '').toString(),
                        sourceName: product['name']?.toString() ??
                            product['Название']?.toString() ??
                            '',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
        ],
      ),
    );
  }
}
