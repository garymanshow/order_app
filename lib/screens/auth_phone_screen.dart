// lib/screens/auth_phone_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sheet_all_api_service.dart';
import '../screens/price_list_screen.dart';
import '../screens/client_selection_screen.dart';
import '../models/user.dart';
import '../providers/theme_provider.dart';

class AuthPhoneScreen extends StatefulWidget {
  @override
  _AuthPhoneScreenState createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends State<AuthPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  late final List<String> _backgrounds = [
    'assets/images/bg1.webp',
    'assets/images/bg2.webp',
    'assets/images/bg3.webp',
  ];
  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _backgrounds.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextIndex = (_currentIndex + 1) % _backgrounds.length;

    return Scaffold(
      body: Stack(
        children: [
          // 🔁 Анимированный фон
          AnimatedCrossFade(
            duration: Duration(seconds: 1),
            firstChild: _buildBackground(_backgrounds[_currentIndex]),
            secondChild: _buildBackground(_backgrounds[nextIndex]),
            crossFadeState: CrossFadeState.showFirst,
          ),
          // Затемнение
          Container(color: Colors.black.withOpacity(0.4)),
          // Контент
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Введите ваш номер телефона',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Телефон (+79023456789)',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.phone, color: Colors.white),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
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
                    SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final phone = _phoneController.text;
                          await _authenticateAndNavigate(context, phone);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Войти'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Кнопка выбора темы
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'theme_toggle',
        onPressed: () {
          _showThemeDialog(context);
        },
        tooltip: 'Выбрать тему',
        child: Icon(Icons.brightness_6),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }

  Widget _buildBackground(String imagePath) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Выберите тему'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.light_mode),
              title: Text('Светлая'),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: Icon(Icons.dark_mode),
              title: Text('Тёмная'),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Как в системе'),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _authenticateAndNavigate(BuildContext context, String phone) async {
    final service = SheetAllApiService();
    try {
      final clients = await service.read(
        sheetName: 'Клиенты',
        filters: {'Телефон': phone},
      );

      if (clients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Клиент не найден')),
        );
        return;
      }

      if (clients.length == 1) {
        final clientData = clients[0] as Map<String, dynamic>;
        final client = Client(
          phone: phone,
          name: clientData['Клиент']?.toString() ?? 'Клиент',
          discount: int.tryParse(
                clientData['Скидка']?.toString().replaceAll(',', '.') ??
                    '0',
              ) ??
              null,
          minOrderAmount: double.tryParse(
                clientData['Сумма миним.заказа']
                        ?.toString()
                        .replaceAll(' ', '') ??
                    '0',
              ) ??
              0.0,
          address: clientData['Адрес доставки']?.toString() ?? '',
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PriceListScreen(
              client: client,
//              mode: PriceListMode.full,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientSelectionScreen(
              phone: phone,
              clients: clients,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка авторизации: $e')),
      );
    }
  }
}