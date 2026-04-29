import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vending_machine.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';

class AdminVendingDashboardScreen extends StatefulWidget {
  const AdminVendingDashboardScreen({super.key});

  @override
  State<AdminVendingDashboardScreen> createState() =>
      _AdminVendingDashboardScreenState();
}

class _AdminVendingDashboardScreenState
    extends State<AdminVendingDashboardScreen> {
  // Рассчитываем остатки для конкретного автомата
  List<VendingStockItem> _calculateStock(String machineId) {
    final clientData =
        Provider.of<AuthProvider>(context, listen: false).clientData;
    if (clientData == null) return [];

    final loads =
        clientData.vendingLoads.where((l) => l.machineId == machineId).toList();
    final ops = clientData.vendingOperations
        .where((o) => o.machineId == machineId)
        .toList();

    final Map<String, VendingStockItem> stockMap = {};

    // Суммируем загрузки
    for (var load in loads) {
      final key =
          '${load.productId}_${load.productionDate.millisecondsSinceEpoch}';
      if (!stockMap.containsKey(key)) {
        // ИСПРАВЛЕНО: Безопасный поиск товара с дефолтным значением
        final product = clientData.productIndex[load.productId] ??
            Product(
                id: load.productId,
                name: 'Товар не найден',
                price: 0,
                multiplicity: 1,
                categoryId: '');

        // Ищем срок хранения из условий
        int shelfLife = 90;
        try {
          final storage = clientData.storageConditions.firstWhere((s) =>
              s.level == 'Категории прайса' &&
              s.entityId == product.categoryId);
          shelfLife = int.tryParse(storage.shelfLife) ?? 90;
        } catch (_) {}

        stockMap[key] = VendingStockItem(
          productId: load.productId,
          productName: product.displayName,
          currentQty: load.loadedQty,
          productionDate: load.productionDate,
          shelfLifeDays: shelfLife,
        );
      } else {
        // ИСПРАВЛЕНО: Пересоздаем объект для сохранения immutability (final полей)
        final existing = stockMap[key]!;
        stockMap[key] = VendingStockItem(
          productId: existing.productId,
          productName: existing.productName,
          currentQty: existing.currentQty + load.loadedQty,
          productionDate: existing.productionDate,
          shelfLifeDays: existing.shelfLifeDays,
        );
      }
    }

    // Вычитаем продажи/списания
    for (var op in ops) {
      // Упрощенная логика: списываем из самой старой партии (FIFO)
      final matchingStocks = stockMap.values
          .where((s) => s.productId == op.productId && s.currentQty > 0)
          .toList()
        ..sort((a, b) => a.productionDate.compareTo(b.productionDate));

      int qtyToDeduct = op.qty;

      // ИСПРАВЛЕНО: Списываем с пересозданием immutable объектов
      final keysToUpdate = <String, int>{}; // Ключ -> сколько осталось

      for (var stock in matchingStocks) {
        if (qtyToDeduct <= 0) break;
        final deduct =
            stock.currentQty < qtyToDeduct ? stock.currentQty : qtyToDeduct;
        final newQty = stock.currentQty - deduct;
        qtyToDeduct -= deduct;

        final key =
            '${stock.productId}_${stock.productionDate.millisecondsSinceEpoch}';
        keysToUpdate[key] = newQty;
      }

      // Применяем изменения в мапе
      keysToUpdate.forEach((key, newQty) {
        final existing = stockMap[key]!;
        stockMap[key] = VendingStockItem(
          productId: existing.productId,
          productName: existing.productName,
          currentQty: newQty,
          productionDate: existing.productionDate,
          shelfLifeDays: existing.shelfLifeDays,
        );
      });
    }

    return stockMap.values.where((s) => s.currentQty > 0).toList();
  }

  // ИСПРАВЛЕНО: Вспомогательный метод для получения цвета из строкового статуса
  Color _getStatusColor(String statusLevel) {
    switch (statusLevel) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientData = Provider.of<AuthProvider>(context).clientData;
    final machines = clientData?.vendingMachines ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏭 Диспетчер вендинга'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              // TODO: Переход на экран "Загрузка в автомат"
            },
            tooltip: 'Загрузить автомат',
          ),
        ],
      ),
      body: machines.isEmpty
          ? const Center(child: Text('Нет данных об автоматах'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: machines.length,
              itemBuilder: (context, index) {
                final machine = machines[index];
                final stock = _calculateStock(machine.id);

                final hasExpired = stock.any((s) => s.isExpired);
                final hasLowStock = stock.any((s) => s.currentQty <= 2);
                final isCritical = hasExpired || hasLowStock || stock.isEmpty;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isCritical
                          ? Colors.red
                          : (hasLowStock ? Colors.orange : Colors.green),
                      width: isCritical ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      // TODO: Переход на экран карточки автомата (остатки)
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping,
                                  color:
                                      isCritical ? Colors.red : Colors.green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  machine.name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isCritical)
                                const Icon(Icons.warning_amber,
                                    color: Colors.red),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(machine.address,
                              style: TextStyle(color: Colors.grey[600])),
                          const Divider(height: 24),
                          if (stock.isEmpty)
                            const Text('⚠️ Нет данных об остатках',
                                style: TextStyle(color: Colors.red))
                          else
                            ...stock.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            // ИСПРАВЛЕНО: Используем метод вместо геттера
                                            color: _getStatusColor(
                                                item.statusLevel),
                                            shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(item.productName)),
                                      Text('${item.currentQty} шт',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      if (item.isExpiringSoon)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: Text('Скоро срок!',
                                                style: TextStyle(
                                                    color: Colors.orange[700],
                                                    fontSize: 12))),
                                      if (item.isExpired)
                                        const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Text('ПРОСРОЧКА',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12))),
                                    ],
                                  ),
                                )),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
