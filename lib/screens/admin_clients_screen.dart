// lib/screens/admin_clients_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/google_sheets_service.dart';
import '../models/client.dart';
import 'admin_client_form_screen.dart';

class AdminClientsScreen extends StatefulWidget {
  @override
  _AdminClientsScreenState createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends State<AdminClientsScreen> {
  List<Client> _clients = [];
  bool _isLoading = false;
  final GoogleSheetsService _service =
      GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _service.init();
      final data = await _service.read(sheetName: 'Клиенты');
      final clients = data.map((row) => Client.fromMap(row)).toList();
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки клиентов: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateClientInList(Client updatedClient) {
    setState(() {
      final index = _clients.indexWhere((client) =>
          client.phone == updatedClient.phone &&
          client.client == updatedClient.client);
      if (index != -1) {
        _clients[index] = updatedClient;
      }
    });
  }

  Future<void> _deleteClient(Client client) async {
    await _service.delete(
      sheetName: 'Клиенты',
      filters: [
        {'column': 'Телефон', 'value': client.phone ?? ''},
        {'column': 'Клиент', 'value': client.client ?? ''},
      ],
    );
    _loadClients();
  }

  void _showDeleteConfirmation(Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить клиента?'),
        content:
            Text('Вы уверены, что хотите удалить "${client.getDisplayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteClient(client);
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Клиенты'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminClientFormScreen()),
              );
              if (result == true || result is Client) {
                _loadClients();
              }
            },
            tooltip: 'Добавить клиента',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? Center(child: Text('Список клиентов пуст'))
              : ListView.builder(
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(client.client ?? ''),
                        subtitle: Text(client.firm ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminClientFormScreen(client: client),
                                  ),
                                );
                                if (result is Client) {
                                  _updateClientInList(result);
                                } else if (result == true) {
                                  _loadClients();
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmation(client),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
