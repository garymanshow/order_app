// lib/screens/shared/production_planning_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/production_planning_service.dart';
import '../../services/warehouse_service.dart';
import '../../services/production_service.dart';
import '../../models/production_plan.dart';
import '../../providers/auth_provider.dart';

class ProductionPlanningScreen extends StatefulWidget {
  final String title;

  const ProductionPlanningScreen({
    super.key,
    this.title = 'Аналитика производства',
  });

  @override
  _ProductionPlanningScreenState createState() =>
      _ProductionPlanningScreenState();
}

class _ProductionPlanningScreenState extends State<ProductionPlanningScreen> {
  ProductionPlan? _productionPlan;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProductionPlan();
  }

  Future<void> _loadProductionPlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final clientData = authProvider.clientData;

      if (clientData == null) {
        setState(() {
          _error = 'Нет данных для анализа';
          _isLoading = false;
        });
        return;
      }

      // Получаем текущие остатки ингредиентов
      final warehouseService =
          Provider.of<WarehouseService>(context, listen: false);
      final stockBalances = await warehouseService.getAllBalances();

      // Формируем карту остатков
      final currentStock = <String, double>{};
      for (var entry in stockBalances.entries) {
        final parts = entry.key.split('_');
        final name = parts.isNotEmpty ? parts[0] : entry.key;
        currentStock[name] = entry.value;
      }

      // Добавляем остатки начинок
      final productionService =
          Provider.of<ProductionService>(context, listen: false);
      final balances = await productionService.getProductionBalances();
      final fillingsBalances = balances['fillings'];
      if (fillingsBalances != null) {
        for (var entry in fillingsBalances.entries) {
          currentStock['🥣 ${entry.key}'] = entry.value;
        }
      }

      final planningService = ProductionPlanningService(
        orders: clientData.orders,
        products: clientData.products,
        compositions: clientData.compositions,
        fillings: clientData.fillings,
        categories: clientData.priceCategories,
        currentStock: currentStock,
      );

      _productionPlan = planningService.calculatePlan();
    } catch (e) {
      setState(() {
        _error = 'Ошибка расчёта плана: $e';
      });
      print('Ошибка расчёта плана: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProductionPlan,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProductionPlan,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_productionPlan == null) {
      return const Center(
        child: Text('Нет данных для анализа'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📋 АНАЛИТИКА ПРОИЗВОДСТВА',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Заказов в работе: ${_productionPlan!.totalProducts} шт',
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                ),
                Text(
                  'Дата расчёта: ${_formatDate(_productionPlan!.date)}',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Продукты
          _buildSection(
            title: 'ПРОДУКТЫ (итого по всем клиентам)',
            icon: Icons.inventory,
            color: Colors.blue,
            child: _buildProductsList(),
          ),

          const SizedBox(height: 24),

          // Начинки
          _buildSection(
            title: 'НУЖНО НАЧИНОК',
            icon: Icons.category,
            color: Colors.green,
            child: _buildFillingsList(),
          ),

          const SizedBox(height: 24),

          // Ингредиенты
          _buildSection(
            title: 'НУЖНО ИНГРЕДИЕНТОВ',
            icon: Icons.food_bank,
            color: Colors.orange,
            child: _buildIngredientsList(),
          ),

          const SizedBox(height: 24),

          // Предупреждения о недостатке
          if (_productionPlan!.hasShortage) ...[
            _buildSection(
              title: '⚠️ ВНИМАНИЕ! НУЖНО ЗАКУПИТЬ',
              icon: Icons.warning,
              color: Colors.red,
              child: _buildShortageList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    if (_productionPlan!.productsNeeded.isEmpty) {
      return const Center(child: Text('Нет заказов в работе'));
    }

    return Column(
      children: _productionPlan!.productsNeeded.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(entry.key)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entry.value} шт',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFillingsList() {
    if (_productionPlan!.fillingsNeeded.isEmpty) {
      return const Center(child: Text('Нет начинок для производства'));
    }

    return Column(
      children: _productionPlan!.fillingsNeeded.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(entry.key)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entry.value.toStringAsFixed(2)} кг',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIngredientsList() {
    if (_productionPlan!.ingredientsNeeded.isEmpty) {
      return const Center(child: Text('Нет ингредиентов'));
    }

    return Column(
      children: _productionPlan!.ingredientsNeeded.entries.map((entry) {
        final needed = entry.value;
        final available = _productionPlan!.currentStock[entry.key] ?? 0;
        final isShortage = needed > available;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(entry.key)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'нужно: ${needed.toStringAsFixed(2)} кг',
                    style: TextStyle(
                      color: isShortage ? Colors.red : Colors.green.shade800,
                    ),
                  ),
                  Text(
                    'есть: ${available.toStringAsFixed(2)} кг',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShortageList() {
    return Column(
      children: _productionPlan!.shortage.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${entry.key}: осталось ${(_productionPlan!.currentStock[entry.key] ?? 0).toStringAsFixed(2)} кг, '
                  'нужно закупить ${entry.value.toStringAsFixed(2)} кг',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
