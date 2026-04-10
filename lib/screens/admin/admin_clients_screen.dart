// lib/screens/admin_clients_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/client.dart';
import 'admin_client_analytics_screen.dart';
import 'admin_clients_analytics_screen.dart';
import 'admin_client_form_screen.dart';
// import 'admin_client_analytics_screen.dart'; // Раскомментируйте когда создадим экран аналитики

class AdminClientsScreen extends StatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  State<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends State<AdminClientsScreen> {
  List<Client> _filteredClients = [];
  String _searchQuery = '';
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  void _loadClients() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clients = authProvider.clientData?.clients ?? [];

    setState(() {
      _filteredClients = clients;
    });
  }

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
    final clientOrders = authProvider.clientData?.orders
            .where((o) => o.clientPhone == client.phone)
            .toList() ??
        [];

    String warningText = 'Вы уверены, что хотите удалить "${client.name}"?';
    if (clientOrders.isNotEmpty) {
      warningText =
          'У клиента "${client.name}" есть ${clientOrders.length} заказов на сумму ${clientOrders.fold(0.0, (sum, o) => sum + o.totalPrice).toStringAsFixed(2)} ₽.\n\nПри удалении клиента все его заказы также будут удалены!';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(clientOrders.isNotEmpty ? '⚠️ Внимание!' : 'Удалить клиента?'),
        content: Text(warningText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      authProvider.clientData!.clients
          .removeWhere((c) => c.phone == client.phone);
      // Если есть заказы, удаляем и их локально
      if (clientOrders.isNotEmpty) {
        authProvider.clientData!.orders
            .removeWhere((o) => o.clientPhone == client.phone);
      }

      authProvider.clientData!.buildIndexes();
      await _saveToPrefs(authProvider);
      await _apiService.deleteClient(client.phone ?? '');

      if (!mounted) return;
      _loadClients();
      _showSnackBar('Клиент удален', Colors.green);
    } catch (e) {
      if (!mounted) return;
      print('❌ Ошибка удаления клиента: $e');
      _showSnackBar('Ошибка удаления: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final clients = authProvider.clientData?.clients ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Клиенты'),
        actions: [
          // Кнопка Аналитики
          IconButton(
            icon: const Icon(Icons.analytics, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminClientsAnalyticsScreen()),
              );
            },
            tooltip: 'Аналитика клиентов',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminClientFormScreen()),
              );
              if (result == true) _loadClients();
            },
            tooltip: 'Добавить клиента',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск по имени, фирме, телефону...',
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
      // УБРАН FloatingActionButton, так как кнопка есть в AppBar
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : clients.isEmpty
              ? _buildEmptyState()
              : _filteredClients.isEmpty
                  ? _buildNoResults()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = _filteredClients[index];
                        return _buildClientCard(client);
                      },
                    ),
    );
  }

  // ЛЕГКАЯ КАРТОЧКА КЛИЕНТА
  Widget _buildClientCard(Client client) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Основная информация
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                // ДОБАВЛЕН ОБРАБОТЧИК КЛИКА
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminClientAnalyticsScreen(client: client),
                    ),
                  );
                },
                title: Text(
                  client.name ?? 'Без имени',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (client.firm != null && client.firm!.isNotEmpty)
                      Text(
                        client.firm!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (client.phone != null)
                          Text(
                            client.phone!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        if (client.city != null && client.city!.isNotEmpty)
                          Text(
                            client.city!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Кнопки действий (Редактировать / Удалить)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              AdminClientFormScreen(client: client)),
                    );
                    if (result == true) _loadClients();
                  },
                  tooltip: 'Редактировать',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.red),
                  onPressed: () => _deleteClient(client),
                  tooltip: 'Удалить',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Нет клиентов',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Нажмите + чтобы добавить клиента',
              style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Ничего не найдено',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Попробуйте изменить поисковый запрос',
              style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
