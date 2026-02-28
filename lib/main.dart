// lib/main.dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io'
    show
        Directory,
        File; // ← Указываем явно, что это только для нативных платформ

// Screens
import 'screens/auth_or_home_router.dart';
import 'screens/price_list_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/client_orders_screen.dart';
import 'screens/client_selection_screen.dart';

// Services
import 'services/image_preloader.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';

// Widgets
import 'widgets/network_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация кэша предзагрузки
  final preloader = ImagePreloader();
  await preloader.initCache();

  // Предзагрузка фонов авторизации
  await preloader.preloadAuthBackgrounds();

  // Инициализация локализации дат для русского языка
  await initializeDateFormatting('ru_RU', null);
  print('✅ Локализация дат инициализирована');

  // 🔥 ИСПРАВЛЕНО: Полностью изолируем нативный код
  if (!kIsWeb) {
    // Этот код выполняется ТОЛЬКО на мобильных платформах и десктопе
    try {
      final envPath = Directory.current.path;
      final envFile = File('$envPath/.env');

      if (await envFile.exists()) {
        await dotenv.load(fileName: '$envPath/.env');
        print('✅ .env файл загружен');
      } else {
        print('⚠️ .env файл не найден. Используются значения по умолчанию.');
      }

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        // await Firebase.initializeApp();
      }
    } catch (e) {
      print('⚠️ Ошибка загрузки .env файла: $e');
    }
  } else {
    // Для веба используем значения по умолчанию
    print('🌐 Веб-платформа: пропускаем загрузку .env файла');

    // Здесь можно задать значения по умолчанию
    // dotenv.env['APP_SCRIPT_URL'] = 'https://script.google.com/...';
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
    // Явно обращаемся к провайдерам
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    print(
        '🟢 MyAppContent: authProvider.isLoading = ${authProvider.isLoading}');

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
