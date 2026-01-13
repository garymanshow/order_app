import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/sheet_all_api_service.dart';
import 'client_selection_screen.dart';
import 'price_list_screen.dart';

class AuthPhoneScreen extends StatefulWidget {
  @override
  _AuthPhoneScreenState createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends State<AuthPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Авторизация')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Введите ваш номер телефона',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Телефон (+79023456789)',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите номер';
                  }
                  if (!value.startsWith('+7') || value.length != 12) {
                    return 'Формат: +79023456789';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: authProvider.isLoading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _login(_phoneController.text, context, authProvider);
                        }
                      },
                child: authProvider.isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : Text('Войти'),
              ),
              if (authProvider.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    authProvider.error!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login(
    String phone,
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    try {
      authProvider.setLoading(true);
      authProvider.clearError();

      // 🔑 Загружаем клиентов по телефону
      final clientsRaw = await SheetAllApiService().read(
        sheetName: 'Клиенты',
        filters: [
          {'column': 'Телефон', 'value': phone}
        ],
      );

      // 🔄 Преобразуем в List<Client>
      final List<Client> clients = clientsRaw
          .where((item) => item is Map<String, dynamic>)
          .map((item) => _parseClient(item as Map<String, dynamic>))
          .toList();

      if (clients.isEmpty) {
        authProvider.setError('Клиент не найден');
        return;
      }

      // 🚀 Сохраняем сессию
      await authProvider.setClientSession(clients.first);

      // ➡️ Навигация
      if (clients.length == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PriceListScreen(client: clients.first),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientSelectionScreen(
              phone: phone,
              clients: clients, // ✅ Теперь List<Client>
            ),
          ),
        );
      }
    } catch (e) {
      authProvider.setError('Ошибка авторизации: $e');
    } finally {
      authProvider.setLoading(false);
    }
  }

  // 🔧 Вспомогательный метод парсинга
  Client _parseClient(Map<String, dynamic> row) {
    return Client(
      phone: row['Телефон']?.toString() ?? '',
      name: row['Клиент']?.toString() ?? '',
      address: row['Адрес доставки']?.toString() ?? '',
      discount: _parseDiscount(row['Скидка']?.toString() ?? ''),
      minOrderAmount:
          double.tryParse(row['Сумма миним.заказа']?.toString() ?? '0') ?? 0.0,
      transportCost: null,
    );
  }

  int? _parseDiscount(String raw) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^\d,]'), '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.replaceAll(',', '.');
    try {
      return double.parse(normalized).toInt();
    } catch (e) {
      return null;
    }
  }
}
