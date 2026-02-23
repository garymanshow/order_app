// lib/main.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Screens
import 'screens/auth_or_home_router.dart';
import 'screens/price_list_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/client_orders_screen.dart';
import 'screens/client_selection_screen.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    // await Firebase.initializeApp();
  }

  final envPath = Directory.current.path;
  final envFile = File('$envPath/.env');

  if (await envFile.exists()) {
    await dotenv.load(fileName: '$envPath/.env');
  } else {
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
        ChangeNotifierProvider(
          create: (context) {
            print('🟢 Создание AuthProvider');
            final provider = AuthProvider();
            print('🟢 Вызов AuthProvider.init()');
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (context) => CartProvider()),
      ],
      child: MyAppContent(),
    );
  }
}

class MyAppContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Явно обращаемся к AuthProvider чтобы он инициализировался
    final authProvider = Provider.of<AuthProvider>(context);
    print(
        '🟢 MyAppContent: authProvider.isLoading = ${authProvider.isLoading}');

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
            '/price': (context) => PriceListScreen(),
            '/cart': (context) => CartScreen(),
            '/orders': (context) => ClientOrdersScreen(),
            '/clientSelection': (context) {
              final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
              return ClientSelectionScreen(
                phone: args['phone'],
                clients: args['clients'],
              );
            },
          },
        );
      },
    );
  }
}
