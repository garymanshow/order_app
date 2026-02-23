// lib/screens/client_selection_screen.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Метод выхода с полной очисткой
  void _logoutAndReturnToAuth(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Выполняем выход и ждем завершения
    authProvider.logout().then((_) {
      if (context.mounted) {
        // Используем pushNamedAndRemoveUntil для полной очистки стека навигации
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/auth', (route) => false);
      }
    }).catchError((error) {
      print('❌ Ошибка при выходе: $error');
      if (context.mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/auth', (route) => false);
      }
    });
  }

  // Метод сброса настроек (отладка)
  Future<void> _resetAppSettings(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Сброс настроек'),
        content: Text('Вы уверены? Это удалит все локальные данные.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Сбросить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      // Очистка SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Очистка AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      // Перезапуск приложения
      if (context.mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/auth', (route) => false);
      }

      // Показать уведомление
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Настройки сброшены!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Проверяем, есть ли данные
        if (authProvider.clientData == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Загрузка данных...'),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

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
            actions: [
              // Кнопка "Сброс настроек" (только для отладки)
              if (kDebugMode)
                IconButton(
                  icon:
                      Icon(Icons.settings_backup_restore, color: Colors.orange),
                  onPressed: () => _resetAppSettings(context),
                  tooltip: 'Сбросить настройки (отладка)',
                ),

              // Кнопка "Выход"
              IconButton(
                icon: Icon(Icons.logout),
                onPressed: () => _logoutAndReturnToAuth(context),
                tooltip: 'Выйти',
              ),
            ],
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
                  Navigator.pushNamed(context, '/price');
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
