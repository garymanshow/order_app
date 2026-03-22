// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
import 'services/env_service.dart';
import 'services/cache_service.dart';
import 'services/sync_service.dart';
import 'services/unit_service.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';

// Widgets
import 'widgets/network_indicator.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Глобальные переменные для сервисов
late CacheService cacheService;
late SyncService syncService;
late UnitService unitService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 ОТКЛЮЧАЕМ ПРОВЕРКУ ТИПОВ ДЛЯ PROVIDER
  Provider.debugCheckInvalidValueType = null;

  // 🔥 ИНИЦИАЛИЗАЦИЯ EnvService
  await EnvService.init();

  // 🔥 ИНИЦИАЛИЗАЦИЯ HIVE
  await Hive.initFlutter();
  print('✅ Hive инициализирован');

  // 🔥 ИНИЦИАЛИЗАЦИЯ КЭША
  cacheService = await CacheService.getInstance();
  print('✅ CacheService инициализирован');

  // 🔥 ИНИЦИАЛИЗАЦИЯ СЕРВИСА ЕДИНИЦ ИЗМЕРЕНИЯ
  unitService = UnitService(ApiService());
  await unitService.loadUnits();
  print('✅ UnitService инициализирован');

  // 🔥 ИНИЦИАЛИЗАЦИЯ СЕРВИСА СИНХРОНИЗАЦИИ
  syncService = SyncService();
  await syncService.initialize();
  print('✅ SyncService инициализирован');

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

  // Запускаем автосинхронизацию
  syncService.startPeriodicSync();

  // Подписываемся на изменения подключения
  Connectivity().onConnectivityChanged.listen((result) {
    if (result != ConnectivityResult.none) {
      print('🌐 Интернет появился, запускаем синхронизацию');
      syncService.sync();
    }
  });

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
      print('   3. Интернет-соединение');
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
            final provider = AuthProvider(
              navigatorKey: navigatorKey,
            );
            print('🟢 Вызов AuthProvider.init()');
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (context) => CartProvider()),
        // 🔥 ИСПРАВЛЕНО: используем Provider без Listenable
        Provider<UnitService>.value(value: unitService),
        Provider<CacheService>.value(value: cacheService),
        Provider<SyncService>.value(value: syncService),
        StreamProvider<ConnectivityResult>(
          create: (_) => Connectivity().onConnectivityChanged.map(
                (List<ConnectivityResult> results) => results.isNotEmpty
                    ? results.first
                    : ConnectivityResult.none,
              ),
          initialData: ConnectivityResult.none,
        ),
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
    final connectivityResult = Provider.of<ConnectivityResult>(context);

    print(
        '🟢 MyAppContent: authProvider.isLoading = ${authProvider.isLoading}');
    print(
        '🟢 MyAppContent: authProvider.isAuthenticated = ${authProvider.isAuthenticated}');
    print('🟢 MyAppContent: connectivity = $connectivityResult');

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
