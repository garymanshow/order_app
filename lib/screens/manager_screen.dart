// lib/screens/manager_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';
import '../models/order_item.dart';
import '../models/product_category.dart';
import '../models/warehouse_operation.dart'; // ← новый импорт
import '../services/api_service.dart';
import '../services/ingredients_service.dart'; // ← новый импорт

class ManagerScreen extends StatefulWidget {
  @override
  _ManagerScreenState createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  List<OrderItem> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employee = authProvider.currentUser as Employee?;

      if (employee != null) {
        final ordersData =
            await ApiService().fetchOrders(employeeId: employee.phone);
        if (ordersData != null) {
          final orders = (ordersData as List)
              .map((order) => OrderItem.fromMap(order as Map<String, dynamic>))
              .where((order) => order.status == 'оформлен')
              .toList();
          setState(() => _orders = orders);
        }
      }
    } catch (e) {
      print('❌ Ошибка загрузки заказов: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Метод списания ингредиентов
  Future<void> _deductIngredientsForOrder(OrderItem order) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final metadata = authProvider.metadata;
    final clientData = authProvider.clientData;

    if (metadata == null || clientData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить данные для списания')),
      );
      return;
    }

    final categories = metadata['productCategories'] as List<dynamic>;
    // Преобразуем в List<ProductCategory>
    final productCategories = categories
        .map((cat) => ProductCategory.fromMap(cat as Map<String, dynamic>))
        .toList();
    final compositions = clientData.compositions;

    final ingredientsService = IngredientsService();
    final apiService = ApiService();

    Future<void> saveOperations(List<WarehouseOperation> operations) async {
      for (var operation in operations) {
        await apiService.addWarehouseOperation(operation);
      }
    }

    try {
      await ingredientsService.deductIngredientsForProduction(
        order,
        productCategories,
        compositions,
        saveOperations,
      );
    } catch (e) {
      print('❌ Ошибка списания ингредиентов: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка списания ингредиентов')),
      );
    }
  }

  // Начало производства
  Future<void> _startProduction(OrderItem order) async {
    final updatedOrder = order.copyWith(status: 'в производстве');
    final success = await ApiService().updateOrders([updatedOrder]);

    if (success) {
      await _deductIngredientsForOrder(updatedOrder);
      await _loadOrders(); // Обновляем список
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Производство начато')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка начала производства')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.currentUser == null ||
        !(authProvider.currentUser is Employee)) {
      return Scaffold(
        body: Center(child: Text('Ошибка авторизации')),
      );
    }

    final user = authProvider.currentUser as Employee;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name ?? 'Менеджер'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(child: Text('Нет заказов для производства'))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return ListTile(
                      title:
                          Text('${order.productName} - ${order.quantity} шт'),
                      subtitle: Text('Клиент: ${order.clientName}'),
                      trailing: ElevatedButton(
                        onPressed: () => _startProduction(order),
                        child: Text('В производство'),
                      ),
                    );
                  },
                ),
    );
  }
}
