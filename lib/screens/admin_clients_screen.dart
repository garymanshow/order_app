// lib/screens/admin_clients_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/client.dart';
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

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  // 🔥 ЗАГРУЗКА КЛИЕНТОВ ИЗ ЛОКАЛЬНЫХ ДАННЫХ
  void _loadClients() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clients = authProvider.clientData?.clients ?? [];

    setState(() {
      _filteredClients = clients;
    });

    print('📊 Загружено клиентов: ${clients.length}');
  }

  // 🔥 ПОИСК КЛИЕНТОВ
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

  // 🔥 ОБНОВЛЕНИЕ КЛИЕНТА В ЛОКАЛЬНОМ СПИСКЕ
  void _updateClientInList(Client updatedClient) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Находим индекс по телефону (как уникальному идентификатору)
    final index = authProvider.clientData!.clients
        .indexWhere((c) => c.phone == updatedClient.phone);

    if (index != -1) {
      // Обновляем в списке
      authProvider.clientData!.clients[index] = updatedClient;
    } else {
      // Добавляем нового клиента
      authProvider.clientData!.clients.add(updatedClient);
    }

    // Перестраиваем индексы
    authProvider.clientData!.buildIndexes();

    // Обновляем отображение
    _applyFilter();

    // 🔥 ОТПРАВКА НА СЕРВЕР
    _syncClientWithServer(updatedClient);

    print('✅ Клиент обновлен локально: ${updatedClient.name}');
  }

  // 🔥 УДАЛЕНИЕ КЛИЕНТА
  Future<void> _deleteClient(Client client) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Удаляем из локального списка
      authProvider.clientData!.clients
          .removeWhere((c) => c.phone == client.phone);

      // Перестраиваем индексы
      authProvider.clientData!.buildIndexes();

      // Обновляем отображение
      _loadClients();

      // 🔥 ОТПРАВКА НА СЕРВЕР
      await _apiService.deleteClient(client.phone ?? '');

      _showSnackBar('Клиент удален', Colors.green);
    } catch (e) {
      print('❌ Ошибка удаления клиента: $e');
      _showSnackBar('Ошибка удаления: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 СИНХРОНИЗАЦИЯ С СЕРВЕРОМ
  Future<void> _syncClientWithServer(Client client) async {
    try {
      if (client.phone == null) return;

      // Проверяем, существует ли уже клиент
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final exists =
          authProvider.clientData!.clients.any((c) => c.phone == client.phone);

      if (exists) {
        await _apiService.updateClient(client);
        print('🔄 Клиент обновлен на сервере: ${client.name}');
      } else {
        await _apiService.createClient(client);
        print('🔄 Новый клиент создан на сервере: ${client.name}');
      }
    } catch (e) {
      print('⚠️ Ошибка синхронизации с сервером: $e');
    }
  }

  // 🔥 СОХРАНЕНИЕ В SHAREDPREFERENCES
  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }

  // 🔥 ДИАЛОГ ПОДТВЕРЖДЕНИЯ УДАЛЕНИЯ
  void _showDeleteConfirmation(Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: Text('Вы уверены, что хотите удалить "${client.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteClient(client);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 ПОКАЗ SNACKBAR
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
    // Получаем доступ к AuthProvider для отслеживания изменений
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
                        return _buildClientCard(client);
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

  // 🔥 КАРТОЧКА КЛИЕНТА
  Widget _buildClientCard(Client client) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Text(
            client.name?.substring(0, 1).toUpperCase() ?? '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          client.name ?? 'Без имени',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (client.firm != null && client.firm!.isNotEmpty)
              Text(
                client.firm!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            if (client.phone != null && client.phone!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    client.phone!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            if (client.city != null && client.city!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.location_city, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    client.city!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
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
              onPressed: () => _showDeleteConfirmation(client),
            ),
          ],
        ),
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
      ),
    );
  }

  // 🔥 ПУСТОЕ СОСТОЯНИЕ
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

  // 🔥 НИЧЕГО НЕ НАЙДЕНО
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
