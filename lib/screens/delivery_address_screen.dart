// lib/screens/delivery_address_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/orders_service.dart';
import 'price_list_screen.dart';

class DeliveryAddressScreen extends StatefulWidget {
  final List<Client> clients;

  const DeliveryAddressScreen({Key? key, required this.clients})
      : super(key: key);

  @override
  _DeliveryAddressScreenState createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  Map<Client, double> _totalSums = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTotalSums();
  }

  Future<void> _loadTotalSums() async {
    final Map<Client, double> totals = {};
    for (var client in widget.clients) {
      final total = await OrdersService().getTotalForPhoneAndClient(
        client.phone,
        client
            .name, // или client.address — в зависимости от структуры "Заказов"
      );
      totals[client] = total;
    }
    setState(() {
      _totalSums = totals;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Выберите адрес доставки'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: widget.clients.length,
              itemBuilder: (context, index) {
                final client = widget.clients[index];
                final sum = _totalSums[client] ?? 0.0;

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    title: Text(
                      client.name,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (client.address.isNotEmpty)
                          Text('Адрес: ${client.address}'),
                        SizedBox(height: 6),
                        Text(
                          'Сумма заказа: ${sum.toStringAsFixed(2)} ₽',
                          style: TextStyle(color: Colors.green, fontSize: 14),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PriceListScreen(client: client),
                        ),
                      );
                    },
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                );
              },
            ),
    );
  }
}
