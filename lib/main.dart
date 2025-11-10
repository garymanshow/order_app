// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth_phone_screen.dart';
import 'screens/auth_or_home_router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart'; // ← новый провайдер

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) {
          final provider = AuthProvider();
          provider.init();
          return provider;
        }),
      ],
      child: MyAppWithTheme(),
    );
  }
}

class MyAppWithTheme extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Загружаем сохранённую тему
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.init(); // инициализация из SharedPreferences

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Формирование заявок',
          theme: ThemeData.light(), // светлая тема
          darkTheme: ThemeData.dark(), // тёмная тема
          themeMode: themeProvider.themeMode, // текущий режим
          home: AuthOrHomeRouter(),
        );
      },
    );
  }
}
