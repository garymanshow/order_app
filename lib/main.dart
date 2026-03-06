// lib/main.dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Убираем импорт dart:io - он не нужен для веба

// Screens
import 'screens/auth_or_home_router.dart';
import 'screens/price_list_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/client_orders_screen.dart';
import 'screens/client_selection_screen.dart';

// Services
import 'services/image_preloader.dart';
import 'services/api_service.dart'; // 👈 ДОБАВЛЕНО для тестирования API

// Providers
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';

// Widgets
import 'widgets/network_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 ЗАГРУЗКА .env ДЛЯ ВСЕХ ПЛАТФОРМ
  await _loadEnvFile();

  // Проверяем соединение с API
  await _testApiConnection();

  // Инициализация кэша предзагрузки
  final preloader = ImagePreloader();
  await preloader.initCache();

  // Предзагрузка фонов авторизации
  await preloader.preloadAuthBackgrounds();

  // Инициализация локализации дат для русского языка
  await initializeDateFormatting('ru_RU', null);
  print('✅ Локализация дат инициализирована');

  // Firebase только для мобильных платформ (если нужно)
  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      // await Firebase.initializeApp();
    }
  }

  runApp(MyApp());
}

// 🔥 ЗАГРУЗКА .env ФАЙЛА ДЛЯ ВСЕХ ПЛАТФОРМ
Future<void> _loadEnvFile() async {
  print('\n📁 ===== ЗАГРУЗКА .env ФАЙЛА =====');

  try {
    // Загружаем .env для ВСЕХ платформ (включая веб)
    await dotenv.load(fileName: "assets/.env");
    print('✅ .env файл загружен из assets/.env');

    final scriptUrl = dotenv.env['APP_SCRIPT_URL'];
    final secret = dotenv.env['APP_SCRIPT_SECRET'];
    final vapidKey = dotenv.env['VAPID_PUBLIC_KEY'];

    print('📌 APP_SCRIPT_URL: ${scriptUrl ?? '❌ НЕ НАЙДЕН'}');
    print(
        '📌 APP_SCRIPT_SECRET: ${secret != null ? '✓ найден' : '❌ НЕ НАЙДЕН'}');
    print(
        '📌 VAPID_PUBLIC_KEY: ${vapidKey != null ? '✓ найден' : '❌ НЕ НАЙДЕН'}');

    if (scriptUrl == null || secret == null) {
      print('⚠️ ВНИМАНИЕ: Не все ключи найдены в .env файле!');
    }
  } catch (e) {
    print('❌ Ошибка загрузки .env файла: $e');
    print('⚠️ Приложение будет работать со значениями по умолчанию');
  }

  print('📁 ===== КОНЕЦ ЗАГРУЗКИ =====\n');
}

// 🔥 ТЕСТИРОВАНИЕ СОЕДИНЕНИЯ С API
Future<void> _testApiConnection() async {
  print('\n🔧 ===== ПРОВЕРКА СОЕДИНЕНИЯ С API =====');

  try {
    final apiService = ApiService();
    final isConnected = await apiService.testConnection();

    if (isConnected) {
      print('✅ API доступен и работает');
    } else {
      print('❌ API не отвечает. Проверьте:');
      print('   1. Правильность APP_SCRIPT_URL в .env');
      print('   2. Доступность скрипта (опубликован ли он)');
      print('   3. Правильность APP_SCRIPT_SECRET');
    }
  } catch (e) {
    print('❌ Ошибка при проверке API: $e');
  }

  print('🔧 ===== КОНЕЦ ПРОВЕРКИ =====\n');
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
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    print(
        '🟢 MyAppContent: authProvider.isLoading = ${authProvider.isLoading}');
    print(
        '🟢 MyAppContent: authProvider.isAuthenticated = ${authProvider.isAuthenticated}');

    return NetworkIndicator(
      child: MaterialApp(
        title: 'Формирование заявок',
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeProvider.themeMode,
        home: AuthOrHomeRouter(),
        debugShowCheckedModeBanner: false,

        // Локализация Material-компонентов
        locale: const Locale('ru', 'RU'),
        supportedLocales: const [
          Locale('ru', 'RU'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

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
      ),
    );
  }
}
