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
import 'services/api_service.dart';
import 'services/env_service.dart';
import 'services/cache_service.dart';
import 'services/image_preloader.dart';
import 'services/sync_service.dart';
import 'services/silent_sync_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;

  // 🔥 КРИТИЧНАЯ ИНИЦИАЛИЗАЦИЯ (до показа UI)
  await EnvService.init();
  print('✅ EnvService инициализирован');

  await Hive.initFlutter();
  print('✅ Hive инициализирован');

  // 👇 ВРЕМЕННО ВКЛЮЧАЕМ ОЧИСТКУ ДЛЯ УСТРАНЕНИЯ ОШИБКИ "connection is closing"
  // Это удалит старую базу, которая могла повредиться.
  // После первого успешного запуска ЭТУ СТРОКУ НУЖНО СНОВА ЗАКОММЕНТИРОВАТЬ.
  //await Hive.deleteFromDisk();
  //print('🔥 Hive очищен (deleteFromDisk)');

  cacheService = await CacheService.getInstance();
  print('✅ CacheService инициализирован');

  final unitService = UnitService(ApiService());

  final silentSync = SilentSyncService(
    ApiService(),
    cacheService,
  );

  runApp(MyApp(silentSync: silentSync, unitService: unitService));

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

// 🔥 ОБНОВЛЁННЫЙ MyApp: принимает silentSync и unitService
class MyApp extends StatelessWidget {
  final SilentSyncService? silentSync;
  final UnitService? unitService;

  const MyApp({super.key, this.silentSync, this.unitService});

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

            if (silentSync != null) {
              silentSync!.setAuthProvider(provider);
              provider.setSilentSync(silentSync!);
            }

            print('🟢 Вызов AuthProvider.init()');
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (context) => CartProvider()),
        if (unitService != null)
          ChangeNotifierProvider<UnitService>.value(value: unitService!),
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
      child: MyAppContent(silentSync: silentSync),
    );
  }
}

class MyAppContent extends StatelessWidget {
  final SilentSyncService? silentSync;

  const MyAppContent({super.key, this.silentSync});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final connectivityResult = Provider.of<ConnectivityResult>(context);

    // 🔥 РЕГИСТРИРУЕМ НАБЛЮДАТЕЛЯ ЖИЗНЕННОГО ЦИКЛА
    WidgetsBinding.instance.addObserver(
      _AppLifecycleObserver(
        onResume: () async {
          await authProvider.checkForUpdates();
        },
      ),
    );

    print(
        '🟢 MyAppContent: authProvider.isLoading = ${authProvider.isLoading}');
    print(
        '🟢 MyAppContent: authProvider.isAuthenticated = ${authProvider.isAuthenticated}');
    print('🟢 MyAppContent: connectivity = $connectivityResult');

    return NetworkIndicator(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Вкусные Моменты',
        theme: _buildThemeData(Brightness.light),
        darkTheme: _buildThemeData(Brightness.dark),
        themeMode: themeProvider.themeMode,
        home: const AuthOrHomeRouter(),
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru', 'RU'),
        supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],
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

  // 🔥 ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ТЕМ
  ThemeData _buildThemeData(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[900]!;
    final secondaryColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final seedColor = const Color(0xFF5D4037);

    return ThemeData(
      fontFamily: 'PlayfairDisplay',
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldColor,
      cardColor: cardColor,
      colorScheme:
          ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness),
      textTheme: _buildCustomTextTheme(brightness),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(color: secondaryColor),
      ),
    );
  }

  TextTheme _buildCustomTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.grey[900]!;
    final secondaryColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return TextTheme(
      headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.2),
      headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.3),
      titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
      bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textColor,
          height: 1.5),
      bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondaryColor,
          height: 1.4),
      bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w400, color: secondaryColor),
      labelLarge: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
    );
  }
}

// 🔥 НОВЫЙ КЛАСС: Наблюдатель за жизненным циклом приложения
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final Future<void> Function()? onResume;

  _AppLifecycleObserver({this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume?.call();
    }
  }
}
