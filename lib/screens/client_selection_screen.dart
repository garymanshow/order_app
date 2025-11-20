// lib/screens/client_selection_screen.dart
import 'package:flutter/material.dart';
import '../models/user.dart';

class ClientSelectionScreen extends StatelessWidget {
  final String phone;
  final List<Client> clients;

  const ClientSelectionScreen({
    Key? key,
    required this.phone,
    required this.clients,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Выберите клиента')),
      body: ListView.builder(
        itemCount: clients.length,
        itemBuilder: (context, index) {
          final client = clients[index];
          return ListTile(
            title: Text(client.name),
            subtitle: Text(client.address),
            onTap: () {
              // TODO: переход к PriceListScreen с выбранным client
            },
          );
        },
      ),
    );
  }
}
