// lib/main.dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Screens
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth_or_home_router.dart';
import 'screens/price_list_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/client_orders_screen.dart';
import 'screens/client_selection_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/driver_screen.dart';
import 'screens/manager/manager_dashboard_screen.dart';
import 'screens/admin/admin_warehouse_screen.dart';

// Services
import 'services/image_preloader.dart';
import 'services/api_service.dart';
import 'services/env_service.dart'; // 👈 ЕДИНСТВЕННЫЙ СЕРВИС ДЛЯ ENV

// Providers
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';

// Widgets
import 'widgets/network_indicator.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 ИНИЦИАЛИЗАЦИЯ EnvService (вся логика загрузки внутри)
  await EnvService.init();

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

// 🔥 Тестирование соединения с API
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
            final provider = AuthProvider(navigatorKey: navigatorKey);
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
        navigatorKey: navigatorKey,
        title: 'Вкусные моменты',
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
          '/price': (context) => const PriceListScreen(),
          '/cart': (context) => const CartScreen(),
          '/orders': (context) => const ClientOrdersScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/admin': (context) => AdminDashboardScreen(),
          '/driver': (context) => DriverScreen(),
          '/manager': (context) => ManagerDashboardScreen(),
          '/warehouse': (context) => AdminWarehouseScreen(),
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
