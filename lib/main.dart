// lib/main.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

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
import 'services/env_service.dart';
import 'services/cache_service.dart';
import 'services/sync_service.dart';
//import 'services/unit_service.dart';

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
//late UnitService unitService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;

  // 🔥 КРИТИЧНАЯ ИНИЦИАЛИЗАЦИЯ (до показа UI)
  await EnvService.init();
  print('✅ EnvService инициализирован');

  await Hive.initFlutter();
  print('✅ Hive инициализирован');

  cacheService = await CacheService.getInstance();
  print('✅ CacheService инициализирован');

  //unitService = UnitService(ApiService());
  //await unitService.loadUnits(); // 🔥 Это может быть медленно, но нужно для UI
  //print('✅ UnitService инициализирован');

  // 🔥 СРАЗУ ПОКАЗЫВАЕМ ПРИЛОЖЕНИЕ
  runApp(MyApp());

  // 🔥 НЕ КРИТИЧНОЕ — В ФОНЕ
  Future.microtask(() async {
    print('🔄 Фоновая инициализация...');

    try {
      // SyncService
      syncService = SyncService();
      await syncService.initialize();
      print('✅ SyncService инициализирован');

      // Предзагрузка изображений
      final preloader = ImagePreloader();
      await preloader.initCache();
      await preloader.preloadAuthBackgrounds();
      print('✅ Изображения предзагружены');

      // Локализация
      await initializeDateFormatting('ru_RU', null);
      print('✅ Локализация инициализирована');

      // Запуск синхронизации
      //syncService.startPeriodicSync();
      //print('✅ Синхронизация запущена');

      // Подписка на интернет
      Connectivity().onConnectivityChanged.listen((result) {
        if (result != ConnectivityResult.none) {
          syncService.sync();
        }
      });

      print('✅ Фоновая инициализация завершена!');
    } catch (e, stack) {
      print('❌ Ошибка фона: $e');
      print('Stack: $stack');
    }
  });
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
        //Provider<UnitService>.value(value: unitService),
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

        // 🔥 НАСТРОЙКА ТЕМ СО ШРИФТОМ ПО УМОЛЧАНИЮ
        theme: _buildThemeData(Brightness.light),
        darkTheme: _buildThemeData(Brightness.dark),
        themeMode: themeProvider.themeMode,

        home: const AuthOrHomeRouter(), // 🔥 const для оптимизации
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

  // 🔥 ВСПОМОГАТЕЛЬНЫЙ МЕТОД: сборка ThemeData с кастомным шрифтом
  ThemeData _buildThemeData(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Цвета для светлой/тёмной темы
    final scaffoldColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[900]!;
    final secondaryColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Акцентный цвет — шоколадный для кондитерской 🍫
    final seedColor = const Color(0xFF5D4037);

    return ThemeData(
      // 🔥 ШРИФТ ПО УМОЛЧАНИЮ — задаём прямо в конструкторе
      fontFamily: 'PlayfairDisplay',

      brightness: brightness,
      scaffoldBackgroundColor: scaffoldColor,
      cardColor: cardColor,

      // Цветовая схема
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),

      // Настройка типографики
      textTheme: _buildCustomTextTheme(brightness),

      // Компоненты
      useMaterial3: true,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Кнопки
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // Текстовые поля
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: TextStyle(color: secondaryColor),
      ),
    );
  }

  // 🔥 КАСТОМНАЯ ТИПОГРАФИКА для Playfair Display
  TextTheme _buildCustomTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.grey[900]!;
    final secondaryColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return TextTheme(
      // Заголовки экранов
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),

      // Подзаголовки
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),

      // Основной текст
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
        height: 1.4,
      ),

      // Второстепенный текст
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),

      // Кнопки
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }
}
