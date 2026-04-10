import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AdminExcludePositionsScreen extends StatefulWidget {
  const AdminExcludePositionsScreen({super.key});

  @override
  State<AdminExcludePositionsScreen> createState() =>
      _AdminExcludePositionsScreenState();
}

class _AdminExcludePositionsScreenState
    extends State<AdminExcludePositionsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isDeleting = false;

  Map<String, Map<String, dynamic>> _positionsMap = {};
  // Линтер просит сделать final, так как мы заменяем элементы внутри Set, а не саму переменную
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  void _loadPositions() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];

    final Map<String, Map<String, dynamic>> tempMap = {};

    for (var order in allOrders) {
      if (order.status == 'оформлен') {
        if (!tempMap.containsKey(order.priceListId)) {
          tempMap[order.priceListId] = {
            'name': order.displayName,
            'count': 0,
          };
        }
        tempMap[order.priceListId]!['count'] =
            (tempMap[order.priceListId]!['count'] as int) + order.quantity;
      }
    }

    setState(() {
      _positionsMap = tempMap;
      _isLoading = false;
    });
  }

  Future<void> _deleteSelectedPositions() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Исключить позиции?'),
        content: Text(
            'Вы удаляте ${_selectedIds.length} позиций из ВСЕХ оформленных заказов. Это действие необратимо.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      // ВЫЗЫВАЕМ НОВЫЙ МЕТОД ИЗ API SERVICE (см. инструкцию ниже по добавлению метода)
      final success =
          await _apiService.deletePositionsFromOrders(_selectedIds.toList());

      if (!mounted) return; // Защита от использования context после async

      if (success) {
        // 1. Удаляем локально из кэша приложения
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.clientData!.orders.removeWhere((order) =>
            order.status == 'оформлен' &&
            _selectedIds.contains(order.priceListId));
        authProvider.clientData!.buildIndexes();

        // 2. Сохраняем обновленные данные локально (решение TODO)
        try {
          final prefs = await SharedPreferences.getInstance();
          final clientDataJson = authProvider.clientData!.toJson();
          await prefs.setString('client_data', jsonEncode(clientDataJson));
        } catch (e) {
          print('❌ Ошибка сохранения после исключения позиций: $e');
        }

        // 3. Отправляем пушы затронутым клиентам (если API вернуло их список)
        // _apiService.sendPushNotification(...);

        if (!mounted) return;
        _showSnackBar('Позиции успешно исключены из заказов', Colors.green);
        Navigator.pop(context, true);
      } else {
        throw Exception('Ошибка на сервере');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Ошибка: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Исключение позиций'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton.icon(
              onPressed: _isDeleting ? null : _deleteSelectedPositions,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.delete_forever, color: Colors.white),
              label: Text('Исключить (${_selectedIds.length})',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _positionsMap.isEmpty
              ? const Center(child: Text('Нет оформленных позиций'))
              : ListView.builder(
                  itemCount: _positionsMap.length,
                  itemBuilder: (context, index) {
                    final id = _positionsMap.keys.elementAt(index);
                    final data = _positionsMap[id]!;
                    final isSelected = _selectedIds.contains(id);

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: Colors.red,
                      title: Text(data['name'],
                          style: TextStyle(
                              decoration: isSelected
                                  ? TextDecoration.lineThrough
                                  : null)),
                      subtitle: Text(
                          'Заказано всего: ${data['count']} шт | ID: $id',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
    );
  }
}
