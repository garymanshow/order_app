// lib/screens/client_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/auth_provider.dart';

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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Рассчитываем суммы для каждого клиента
        final clientsWithTotals = clients.map((client) {
          final total = client.getActiveOrdersTotal(authProvider.clientData);
          return _ClientWithTotal(client: client, total: total);
        }).toList();

        // Рассчитываем общую сумму
        double totalAllClients = 0;
        for (var clientWithTotal in clientsWithTotals) {
          totalAllClients += clientWithTotal.total;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              totalAllClients > 0
                  ? 'Выберите клиента\n(всего на ${totalAllClients.toStringAsFixed(2)} ₽)'
                  : 'Выберите клиента',
              maxLines: 2,
              softWrap: true,
            ),
            toolbarHeight: totalAllClients > 0 ? 80.0 : kToolbarHeight,
          ),
          body: ListView.builder(
            itemCount: clientsWithTotals.length,
            itemBuilder: (context, index) {
              final clientWithTotal = clientsWithTotals[index];
              final hasActiveOrders = clientWithTotal.total > 0;

              return ListTile(
                title: Text(clientWithTotal.client.name ?? ''),
                subtitle: hasActiveOrders
                    ? Text('${clientWithTotal.total.toStringAsFixed(2)} ₽')
                    : null,
                textColor: hasActiveOrders ? Colors.green : null,
                iconColor: hasActiveOrders ? Colors.green : null,
                onTap: () {
                  authProvider.setClient(clientWithTotal.client);
                  Navigator.pushReplacementNamed(context, '/price');
                },
              );
            },
          ),
        );
      },
    );
  }
}

// Вспомогательный класс для хранения клиента и его суммы
class _ClientWithTotal {
  final Client client;
  final double total;

  _ClientWithTotal({required this.client, required this.total});
}
