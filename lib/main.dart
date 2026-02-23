// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'dart:io';

// Screens
import 'screens/auth_or_home_router.dart';
import 'screens/price_list_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/client_orders_screen.dart';
import 'screens/client_selection_screen.dart'; // ← ДОБАВИТЬ ИМПОРТ

// Providers
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  // ... остальной код без изменений
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()..init()),
        ChangeNotifierProvider(
          create: (context) {
            final provider = AuthProvider();
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
            '/': (context) => AuthOrHomeRouter(),
            '/price': (context) => PriceListScreen(),
            '/cart': (context) => CartScreen(),
            '/orders': (context) => ClientOrdersScreen(),
            '/clientSelection': (context) {
              // Получаем данные из аргументов
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
