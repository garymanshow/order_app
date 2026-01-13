// lib/main.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Models
import 'models/user.dart';

// Screens
import 'screens/auth_or_home_router.dart';
import 'screens/price_list_screen.dart';
import 'screens/cart_screen.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/products_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  // 🔑 Обязательно: инициализация плагинов до runApp
  WidgetsFlutterBinding.ensureInitialized();
  // 🔥 Инициализируем Firebase ТОЛЬКО на поддерживаемых платформах
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    // await Firebase.initializeApp();
  }

  // 🔑 Правильная загрузка .env — с полным путём
  final envPath = Directory.current.path;
  final envFile = File('$envPath/.env');

  if (await envFile.exists()) {
    // Передаём путь явно
    await dotenv.load(fileName: '$envPath/.env');
  } else {
    // Опционально: используйте резервный ключ или завершите работу
    print('Внимание: файл .env не найден. Используются значения по умолчанию.');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (context) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (context) => ProductsProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
      ],
      child: MyAppContent(),
    );
  }
}

class MyAppContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Формирование заявок',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeProvider.themeMode,
          home: AuthOrHomeRouter(),
          debugShowCheckedModeBanner: false,
          routes: {
            // ✅ Маршрут для выбора адреса доставки → передаём Client в PriceListScreen
            '/price': (context) {
              final Client client =
                  ModalRoute.of(context)!.settings.arguments as Client;
              return PriceListScreen(client: client);
            },
            // ✅ Корзина — без аргументов (использует ProductsProvider и CartProvider)
            '/cart': (context) => CartScreen(),
          },
        );
      },
    );
  }
}
