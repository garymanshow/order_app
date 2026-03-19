// lib/screens/admin_clients_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/client.dart';
import 'admin_client_form_screen.dart';

class AdminClientsScreen extends StatefulWidget {
  @override
  _AdminClientsScreenState createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends State<AdminClientsScreen> {
  List<Client> _filteredClients = [];
  String _searchQuery = '';
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  // Статистика по клиентам
  Map<String, Map<String, dynamic>> _clientStats = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  // ЗАГРУЗКА КЛИЕНТОВ И СТАТИСТИКИ
  void _loadClients() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clients = authProvider.clientData?.clients ?? [];

    _calculateClientStats(authProvider);

    setState(() {
      _filteredClients = clients;
    });

    print('📊 Загружено клиентов: ${clients.length}');
  }

  // РАСЧЕТ СТАТИСТИКИ ПО КЛИЕНТАМ
  void _calculateClientStats(AuthProvider authProvider) {
    _clientStats.clear();
    final orders = authProvider.clientData?.orders ?? [];

    for (var order in orders) {
      if (order.clientPhone.isEmpty) continue;

      if (!_clientStats.containsKey(order.clientPhone)) {
        _clientStats[order.clientPhone] = {
          'totalOrders': 0,
          'totalItems': 0,
          'totalSpent': 0.0,
          'totalPaid': 0.0,
          'totalDebt': 0.0,
          'lastOrderDate': '',
        };
      }

      _clientStats[order.clientPhone]!['totalOrders'] += 1;
      _clientStats[order.clientPhone]!['totalItems'] += order.quantity;
      _clientStats[order.clientPhone]!['totalSpent'] += order.totalPrice;
      _clientStats[order.clientPhone]!['totalPaid'] += order.paymentAmount;

      final spent = _clientStats[order.clientPhone]!['totalSpent'] as double;
      final paid = _clientStats[order.clientPhone]!['totalPaid'] as double;
      _clientStats[order.clientPhone]!['totalDebt'] = spent - paid;

      if (order.date
              .compareTo(_clientStats[order.clientPhone]!['lastOrderDate']) >
          0) {
        _clientStats[order.clientPhone]!['lastOrderDate'] = order.date;
      }
    }
  }

  // ПОИСК КЛИЕНТОВ
  void _filterClients(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyFilter();
    });
  }

  void _applyFilter() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allClients = authProvider.clientData?.clients ?? [];

    if (_searchQuery.isEmpty) {
      _filteredClients = allClients;
    } else {
      _filteredClients = allClients.where((client) {
        return client.name?.toLowerCase().contains(_searchQuery) == true ||
            client.firm?.toLowerCase().contains(_searchQuery) == true ||
            client.phone?.toLowerCase().contains(_searchQuery) == true ||
            client.city?.toLowerCase().contains(_searchQuery) == true;
      }).toList();
    }
  }

  // 🔥 УДАЛЕНИЕ КЛИЕНТА
  Future<void> _deleteClient(Client client) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Проверяем, есть ли заказы у клиента
    final clientOrders = authProvider.clientData?.orders
            .where((o) => o.clientPhone == client.phone)
            .toList() ??
        [];

    if (clientOrders.isNotEmpty) {
      // Показываем предупреждение
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Внимание!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('У клиента "${client.name}" есть заказы:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                        'Всего заказов:', '${clientOrders.length} шт'),
                    _buildStatRow('На сумму:',
                        '${clientOrders.fold(0.0, (sum, o) => sum + o.totalPrice).toStringAsFixed(2)} ₽'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'При удалении клиента все его заказы также будут удалены!',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Удалить всё'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);

      try {
        // Удаляем заказы клиента (массовое обновление статуса)
        // Вместо удаления, можно помечать заказы как удаленные
        // или использовать другой подход

        // Удаляем клиента
        authProvider.clientData!.clients
            .removeWhere((c) => c.phone == client.phone);

        authProvider.clientData!.buildIndexes();
        await _saveToPrefs(authProvider);
        await _apiService.deleteClient(client.phone ?? '');

        _loadClients();
        _showSnackBar('Клиент и его заказы удалены', Colors.green);
      } catch (e) {
        print('❌ Ошибка удаления клиента: $e');
        _showSnackBar('Ошибка удаления: $e', Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      // Если заказов нет, просто подтверждение удаления
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить клиента?'),
          content: Text('Вы уверены, что хотите удалить "${client.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);

      try {
        authProvider.clientData!.clients
            .removeWhere((c) => c.phone == client.phone);

        authProvider.clientData!.buildIndexes();
        await _saveToPrefs(authProvider);
        await _apiService.deleteClient(client.phone ?? '');

        _loadClients();
        _showSnackBar('Клиент удален', Colors.green);
      } catch (e) {
        print('❌ Ошибка удаления клиента: $e');
        _showSnackBar('Ошибка удаления: $e', Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // СОХРАНЕНИЕ В SHAREDPREFERENCES
  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final clients = authProvider.clientData?.clients ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Клиенты'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClients,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminClientFormScreen()),
              );
              if (result == true) {
                _loadClients();
              }
            },
            tooltip: 'Добавить клиента',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск клиентов...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterClients,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : clients.isEmpty
              ? _buildEmptyState()
              : _filteredClients.isEmpty
                  ? _buildNoResults()
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = _filteredClients[index];
                        final stats = _clientStats[client.phone] ??
                            {
                              'totalOrders': 0,
                              'totalItems': 0,
                              'totalSpent': 0.0,
                              'totalPaid': 0.0,
                              'totalDebt': 0.0,
                            };
                        return _buildClientCard(client, stats);
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminClientFormScreen()),
          );
          if (result == true) {
            _loadClients();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // КАРТОЧКА КЛИЕНТА СО СТАТИСТИКОЙ
  Widget _buildClientCard(Client client, Map<String, dynamic> stats) {
    final debt = stats['totalDebt'] as double;
    final totalSpent = stats['totalSpent'] as double;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminClientFormScreen(client: client),
            ),
          );
          if (result == true) {
            _loadClients();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Аватар
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    debt > 0 ? Colors.red.shade100 : Colors.green.shade100,
                child: Text(
                  client.name?.substring(0, 1).toUpperCase() ?? '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: debt > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Информация о клиенте
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name ?? 'Без имени',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (client.firm != null && client.firm!.isNotEmpty)
                      Text(
                        client.firm!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),

                    // Контактная информация
                    Wrap(
                      spacing: 8,
                      children: [
                        if (client.phone != null)
                          Text(
                            '📞 ${client.phone}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        if (client.city != null)
                          Text(
                            '🏙️ ${client.city}',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Статистика заказов
                    Wrap(
                      spacing: 12,
                      children: [
                        // Количество заказов
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '📦 ${stats['totalOrders']} заказов',
                            style: TextStyle(
                                fontSize: 10, color: Colors.blue.shade700),
                          ),
                        ),

                        // Сумма покупок (зеленым)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '💰 ${totalSpent.toStringAsFixed(0)} ₽',
                            style: TextStyle(
                                fontSize: 10, color: Colors.green.shade700),
                          ),
                        ),

                        // Долг (красным, если > 0)
                        if (debt > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '💸 ${debt.toStringAsFixed(0)} ₽',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.red.shade700),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '✅ Нет долга',
                              style:
                                  TextStyle(fontSize: 10, color: Colors.green),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Кнопки действий
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminClientFormScreen(client: client),
                        ),
                      );
                      if (result == true) {
                        _loadClients();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteClient(client),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ПУСТОЕ СОСТОЯНИЕ
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет клиентов',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите + чтобы добавить клиента',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // НИЧЕГО НЕ НАЙДЕНО
  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Ничего не найдено',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте изменить поисковый запрос',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
