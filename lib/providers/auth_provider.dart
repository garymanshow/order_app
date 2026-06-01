// lib/providers/auth_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_category.dart';
import '../models/client.dart';
import '../models/client_data.dart';
import '../models/composition.dart';
import '../models/delivery_condition.dart';
import '../models/employee.dart';
import '../models/filling.dart';
import '../models/order_item.dart';
import '../models/price_category.dart';
import '../models/product.dart';
import '../models/nutrition_info.dart';
import '../models/user.dart';
import '../models/sheet_metadata.dart';
import '../models/storage_condition.dart';
import '../models/transport_condition.dart';
import '../screens/two_factor_screen.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/silent_sync_service.dart';
import '../services/sync_service.dart';
import '../services/web_push_service.dart';
import '../services/env_service.dart';
import '../utils/phone_validator.dart';
import 'cart_provider.dart';

class AuthProvider with ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey;

  User? _currentUser;
  ClientData? _clientData;
  Map<String, SheetMetadata>? _metadata;
  List<Employee>? _availableRoles;
  bool _isLoading = false;
  bool _isOffline = false;

  bool _clientSelected = false;

  // 👇 ДОБАВЛЯЕМ ФЛАГ БЛОКИРОВКИ
  bool _isPushDialogShowing = false;

  bool get clientSelected => _clientSelected;

  // 👇 ДЛЯ PUSH (только Web Push, без FCM)
  bool _pushSubscriptionAttempted = false;
  Timer? _pushReminderTimer;

  // 🔥 ТИХАЯ СИНХРОНИЗАЦИЯ: поля
  bool _hasPendingUpdates = false;
  List<String> _pendingSheets = [];
  SilentSyncService? _silentSync;

  // 🔥 Геттеры для UI
  bool get hasPendingUpdates => _hasPendingUpdates;
  List<String> get pendingSheets => _pendingSheets;

  // 👇 СЕРВИСЫ
  late final CacheService _cacheService;
  late final SyncService _syncService;
  final ApiService _apiService = ApiService();

  AuthProvider({required this.navigatorKey});

  // Геттеры
  User? get currentUser => _currentUser;
  ClientData? get clientData => _clientData;
  Map<String, SheetMetadata>? get metadata => _metadata;
  List<Employee>? get availableRoles => _availableRoles;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmployee => _currentUser is Employee;
  bool get isClient => _currentUser is Client;
  bool get hasMultipleRoles =>
      _availableRoles != null && _availableRoles!.length > 1;
  bool get isOffline => _isOffline;

  // ================== ИНИЦИАЛИЗАЦИЯ ==================
  Future<void> init() async {
    debugPrint('🟢 AuthProvider.init() START');
    _isLoading = true;
    notifyListeners();

    _cacheService = await CacheService.getInstance();
    _syncService = SyncService();

    final hasCachedData = await _loadCachedData();

    if (hasCachedData) {
      debugPrint('✅ Загружены кэшированные данные');

      // 🔥 ЗАЩИТА: Проверяем, не забыл ли менеджер отправить заказы перед закрытием вкладки
      await _restoreUnsentDrafts();

      _isLoading = false;
      notifyListeners();

      // Легкая проверка метаданных
      _checkMetadataOnStart();
    } else {
      _isLoading = false;
      notifyListeners();
    }

    debugPrint('🟢 AuthProvider.init() END');
  }

  // 🔥 Вспомогательный метод для легкой проверки при старте
  Future<void> _checkMetadataOnStart() async {
    try {
      final result = await _apiService.checkMetadataUpdates(
        phone: _currentUser?.phone,
        localMetadata: _cacheService.getMetadata(),
      );

      if (result != null && result['hasUpdates'] == true) {
        debugPrint(
            '🔄 Данные на сервере обновились, запускаем полную синхронизацию');
        await _syncService.sync();
      } else {
        debugPrint('💤 Данные актуальны, лишних запросов нет');
      }
    } catch (e) {
      debugPrint('⚠️ Легкая проверка метаданных не удалась: $e');
    }
  }

  // ================== ЗАГРУЗКА КЭШИРОВАННЫХ ДАННЫХ ==================
  Future<bool> _loadCachedData() async {
    try {
      // Загружаем пользователя из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('auth_user');

      if (userData != null) {
        final json = jsonDecode(userData);
        if (json['role'] == null) {
          _currentUser = Client.fromJson(json);
        } else {
          _currentUser = Employee.fromJson(json);
        }
      }

      // Загружаем данные из Hive
      final orders = _cacheService.getOrders();
      final products = _cacheService.getProducts();
      final fillings = _cacheService.getFillings();
      final compositions = _cacheService.getCompositions();
      final priceCategories = _cacheService.getPriceCategories();

      // === НОВОЕ: Загрузка новых моделей ===
      final storageConditions = _cacheService.getStorageConditions();
      final transportConditions = _cacheService.getTransportConditions();
      // ====================================

      if (orders.isNotEmpty || products.isNotEmpty) {
        // 🔥 ИСПРАВЛЕНО: создаём ClientData через сеттеры
        _clientData = ClientData()
          ..products = products
          ..orders = orders
          ..fillings = fillings
          ..compositions = compositions
          ..priceCategories = priceCategories
          // === НОВОЕ: Присваиваем загруженные данные ===
          ..storageConditions = storageConditions
          ..transportConditions = transportConditions;
        // =============================================

        _clientData?.buildIndexes();

        debugPrint('📦 Кэшированные данные загружены:');
        debugPrint('   - Заказов: ${orders.length}');
        debugPrint('   - Продуктов: ${products.length}');
        debugPrint('   - Начинок: ${fillings.length}');
        debugPrint('   - Составов: ${compositions.length}');
        debugPrint('   - Категорий: ${priceCategories.length}');
        // === НОВОЕ: Логи ===
        debugPrint('   - Усл. хранения: ${storageConditions.length}');
        debugPrint('   - Усл. транспортировки: ${transportConditions.length}');
        // ===================

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки кэша: $e');
      return false;
    }
  }

  // ================== АУТЕНТИФИКАЦИЯ ==================

  Future<void> login(String phone, {required BuildContext context}) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🟢 login() начат с телефоном: $phone');

      final normalizedPhone = PhoneValidator.normalizePhone(phone);
      if (normalizedPhone == null) {
        throw Exception('Неверный формат телефона');
      }
      debugPrint('🟢 Нормализованный телефон: $normalizedPhone');

      // Загружаем локальные метаданные для сравнения
      final localMetadata = _cacheService.getMetadata();

      // Пытаемся получить данные с сервера
      Map<String, dynamic>? authResponse;
      bool hasNetwork = await _checkNetwork();

      if (hasNetwork) {
        try {
          // ==========================================
          // 🔥 NОВОЕ: БЕСШУМНЫЙ СБОР ПУШ-ПОДПИСКИ
          // Работает за 1 миллисекунду, без запросов к серверу
          // ==========================================
          Map<String, dynamic>? currentPushData;
          if (kIsWeb) {
            try {
              final pushService = WebPushService();
              await pushService.initialize(EnvService.vapidPublicKey);

              // Если подписка есть в браузере — забираем её
              currentPushData = await pushService.getSubscriptionForAuth();

              if (currentPushData != null) {
                debugPrint(
                    '📬 Найдена активная подписка, прикрепляем к запросу');
              } else {
                debugPrint(
                    '📭 Подписка не найдена (пользователь отписан или новый)');
              }
            } catch (e) {
              debugPrint('⚠️ Ошибка проверки пуш-статуса: $e');
            }
          }

          // ==========================================
          // 📤 ОСНОВНОЙ ЗАПРОС АВТОРИЗАЦИИ
          // Если currentPushData не null, он полетит "в нагрузке"
          // ==========================================
          authResponse = await _apiService.authenticate(
            phone: normalizedPhone,
            localMetadata: localMetadata,
            pushData: currentPushData, // <--- ПРИКРЕПЛЯЕМ ПУШ
          );
        } catch (e) {
          debugPrint('⚠️ Ошибка сети: $e');
          authResponse = null;
        }
      }

      if (authResponse != null) {
        // Есть ответ от сервера — обновляем кэш
        try {
          await _handleServerResponse(authResponse, normalizedPhone, context);
          _isOffline = false;
        } catch (e) {
          debugPrint('❌ Ошибка обработки ответа сервера: $e');
          final hasCache = await _loadCachedData();
          if (hasCache && _currentUser != null) {
            _isOffline = true;
            _showOfflineModeDialog(context);
          } else {
            rethrow;
          }
        }
      } else {
        // Нет сети — пытаемся загрузить из кэша
        final hasCache = await _loadCachedData();
        if (hasCache && _currentUser != null) {
          _isOffline = true;
          _showOfflineModeDialog(context);
        } else {
          throw Exception('Нет интернета и нет кэшированных данных');
        }
      }

      // Убеждаемся, что isLoading false перед тем как идти дальше
      _isLoading = false;
      notifyListeners();

      // ==========================================
      // 🗑️ УДАЛЕНО: ВЕСЬ БЛОК ФОНОВОЙ ПОДПИСКИ (_handlePushSubscriptionSafe)
      // Сервер уже получил подписку (если она была) в запросе authenticate.
      // Отдельные запросы больше не нужны!
      // ==========================================
    } catch (e) {
      debugPrint('❌ Критическая ошибка входа: $e');
      _currentUser = null;
      _clientData = null;
      _metadata = null;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ================== ТИХАЯ СИНХРОНИЗАЦИЯ ==================

  /// 🔥 Установить сервис синхронизации (вызывается из main)
  void setSilentSync(SilentSyncService service) {
    _silentSync = service;
  }

  /// 🔥 Обновить статус ожидающих обновлений
  void setHasPendingUpdates(bool value, List<String> sheets) {
    _hasPendingUpdates = value;
    _pendingSheets = sheets;
    notifyListeners(); // 🔥 UI обновится автоматически
  }

  /// 🔥 Проверка обновлений (вызывается при старте / resume)
  Future<void> checkForUpdates() async {
    await _silentSync?.checkIfNeeded();
  }

  /// 🔥 Принудительная синхронизация (по тапу на иконку)
  Future<void> syncNow() async {
    await _silentSync?.syncNow();
  }

  // 🔥 БЕЗОПАСНАЯ ОБЕРТКА ДЛЯ PUSH
  Future<void> _handlePushSubscriptionSafe(String phone) async {
    try {
      await _handlePushSubscription(phone);
    } catch (e) {
      debugPrint('⚠️ PUSH ошибка (безопасный режим): $e');
      // Ошибка здесь никак не повлияет на состояние авторизации
    }
  }

  Future<void> _handleServerResponse(
    Map<String, dynamic> authResponse,
    String phone,
    BuildContext context,
  ) async {
    final userData = authResponse['user'];
    final data = authResponse['data'];
    final metadata = authResponse['metadata'];

    if (userData == null) {
      throw Exception('Сервер не вернул данные пользователя');
    }

    // 🔥 ЛОГ 1: Проверяем сырые данные от сервера
    debugPrint('📡 ШАГ 1: Проверка ответа сервера...');
    if (data != null && data is Map<String, dynamic>) {
      final rawCategories = data['priceCategories'];
      debugPrint(
          '📡 ШАГ 1: Ключ priceCategories найден? ${rawCategories != null}');

      if (rawCategories is List) {
        debugPrint(
            '📡 ШАГ 1: Количество категорий в JSON: ${rawCategories.length}');
        if (rawCategories.isNotEmpty) {
          // Выведем первую категорию целиком, чтобы увидеть ключи
          debugPrint('📡 ШАГ 1: Пример первой категории: ${rawCategories[0]}');
        }
      } else {
        debugPrint(
            '⚠️ ШАГ 1: priceCategories не является списком! Тип: ${rawCategories.runtimeType}');
      }
    } else {
      debugPrint('❌ ШАГ 1: Объект data пуст или отсутствует!');
    }

    // Десериализуем пользователя (ваш существующий код)
    if (userData is List) {
      _availableRoles = userData
          .map((item) => Employee.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      if (userData['Роль'] != null && userData['Роль'].toString().isNotEmpty) {
        debugPrint('🕵️‍♂️ Обнаружен сотрудник с ролью: ${userData['Роль']}');
        _currentUser = Employee.fromJson(userData);
      } else if (userData['role'] != null) {
        _currentUser = Employee.fromJson(userData);
      } else {
        _currentUser = Client.fromJson(userData);
      }
    }

    // 🔥 ПРОВЕРКА 2FA ДЛЯ ВСЕХ (С ИСКЛЮЧЕНИЕМ DEBUG)
    if (!kDebugMode) {
      String? missingEmailRole;

      if (_currentUser is Employee) {
        final employee = _currentUser as Employee;
        debugPrint('🔐 [2FA CHECK] Тип: СОТРУДНИК, Email: ${employee.email}');

        if (employee.twoFactorAuth &&
            (employee.email == null || employee.email!.isEmpty)) {
          missingEmailRole = 'сотрудника';
        } else if (employee.twoFactorAuth) {
          await _handleTwoFactorAuth(context,
              email: employee.email, name: employee.name, isEmployee: true);
        }
      } else if (_currentUser is Client) {
        final client = _currentUser as Client;
        debugPrint('🔐 [2FA CHECK] Тип: КЛИЕНТ, Email: ${client.email}');

        if (client.email == null || client.email!.isEmpty) {
          missingEmailRole = 'клиента';
        } else {
          await _handleTwoFactorAuth(context,
              email: client.email,
              name: client.name ?? client.firm,
              isEmployee: false);
        }
      }

      // 🔥 НОВОЕ: Если обнаружен пустой Email — показываем диалог-барьер
      if (missingEmailRole != null) {
        final adminPhone = _adminPhone ?? 'не указан';
        final adminText = adminPhone != 'не указан' ? adminPhone : '';

        await _showNoEmailDialog(context, missingEmailRole, adminText);

        // После закрытия диалога всё равно выбрасываем ошибку, чтобы не пускать внутрь
        throw Exception('Профиль $missingEmailRole не настроен для 2FA');
      }
    } else {
      debugPrint('🛑 [2FA CHECK] Режим DEBUG: Проверка 2FA ОТКЛЮЧЕНА!');
    }

    // Сохраняем данные в кэш
    if (data != null && metadata != null) {
      // 🔥 ЛОГ 2: Перед парсингом
      debugPrint('💾 ШАГ 2: Начинаем десериализацию ClientData...');

      _clientData = _deserializeClientData(data);
      _metadata = _deserializeMetadata(metadata);

      // 🔥 ЛОГ 3: После парсинга
      debugPrint(
          '💾 ШАГ 3: Результат парсинга. Категорий в объекте: ${_clientData?.priceCategories.length ?? 0}');
      if (_clientData?.priceCategories.isNotEmpty == true) {
        debugPrint(
            '💾 ШАГ 3: Первая категория после парсинга: "${_clientData!.priceCategories[0].name}" (ID: ${_clientData!.priceCategories[0].id})');
      } else {
        debugPrint('❌ ШАГ 3: Список категорий ПОСЛЕ парсинга ПУСТ!');
      }

      // Сохраняем в Hive
      await saveToCache();

      // вызов восстановления черновиков
      await _restoreUnsentDrafts();

      // Сохраняем в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'auth_user', jsonEncode(_currentUser?.toJson() ?? {}));
      await prefs.setString('auth_timestamp', DateTime.now().toIso8601String());
    }
  }

  Future<void> _handleTwoFactorAuth(
    BuildContext context, {
    required String? email,
    String? name,
    bool isEmployee = false,
  }) async {
    if (email == null || email.isEmpty) {
      throw Exception('Для прохождения 2FA не указан email');
    }

    final twoFactorResult = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        // 🔥 Теперь передаем чистые данные, экран сам разберется
        builder: (context) => TwoFactorScreen(
          userName: name ?? 'Пользователь',
          requiredEmail: email,
          isEmployee: isEmployee,
        ),
      ),
    );

    if (twoFactorResult != true) {
      throw Exception('2FA не пройдена');
    }
  }

  Future<void> saveToCache() async {
    if (_clientData == null) return;

    await _cacheService.saveOrders(_clientData!.orders);
    await _cacheService.saveProducts(_clientData!.products);
    await _cacheService.saveFillings(_clientData!.fillings);
    await _cacheService.saveCompositions(_clientData!.compositions);

    // === НОВОЕ: Сохранение условий с логами ===
    debugPrint(
        '🧊 ШАГ 3: Сохраняем условий хранения: ${_clientData!.storageConditions.length}');
    await _cacheService.saveStorageConditions(_clientData!.storageConditions);

    debugPrint(
        '🚚 ШАГ 3: Сохраняем условий транспортировки: ${_clientData!.transportConditions.length}');
    await _cacheService
        .saveTransportConditions(_clientData!.transportConditions);
    // ========================================

    debugPrint(
        '📦 ШАГ 3: Сохраняем в Hive категорий: ${_clientData!.priceCategories.length}');
    await _cacheService.savePriceCategories(_clientData!.priceCategories);

    final cachedCats = _cacheService.getPriceCategories();
    debugPrint('📦 ШАГ 4: Прочитали из Hive категорий: ${cachedCats.length}');

    if (_metadata != null) {
      await _cacheService.saveMetadata(_metadata!);
    }

    debugPrint('✅ Данные сохранены в Hive кэш');
  }

  // 🔥 МЕТОД ДЛЯ СИНХРОНИЗАЦИИ ОФЛАЙН-ЗАКАЗОВ С ИНТЕРФЕЙСОМ
  Future<void> refreshOrdersFromCache() async {
    try {
      final freshOrders = _cacheService.getOrders();
      if (_clientData != null) {
        _clientData!.orders = freshOrders;
        notifyListeners(); // Заставляет экраны пересобраться с новыми данными
        debugPrint(
            '🔄 Заказы в интерфейсе обновлены из кэша (после офлайн-отправки)');
      }
    } catch (e) {
      debugPrint('❌ Ошибка обновления заказов из кэша: $e');
    }
  }

  // 🔥 МЕТОД СИНХРОНИЗАЦИИ: Обновляет глобальный список заказов
  // чтобы экраны выбора клиентов и прайс-листа видели актуальные суммы
  void updateGlobalOrders(List<OrderItem> updatedOrders) {
    if (_clientData != null) {
      _clientData!.orders = updatedOrders;
      notifyListeners();
    }
  }

  // ==========================================
  // ЗАЩИТА ОТ ЗАБЫВЧИВОСТИ МЕНЕДЖЕРА
  // ==========================================

  /// Меняем статус локальных заказов на "Отправлено на сервер"
  void markOrdersAsSent(List<OrderItem> sentOrders) {
    if (_clientData == null) return;

    // Фильтруем только валидные заказы (у которых есть ID и Имя)
    final validSentOrders = sentOrders
        .where((o) => o.clientName.isNotEmpty && o.priceListId.isNotEmpty)
        .toList();

    if (validSentOrders.isEmpty) return;

    // 🔥 МАГИЯ: Мы НЕ УДАЛЯЕМ заказы. Мы просто меняем у них флаг!
    for (int i = 0; i < _clientData!.orders.length; i++) {
      final localOrder = _clientData!.orders[i];

      // Ищем этот заказ в списке успешно отправленных
      final wasSent = validSentOrders.any((sentOrder) =>
          localOrder.clientPhone == sentOrder.clientPhone &&
          localOrder.clientName == sentOrder.clientName &&
          localOrder.priceListId == sentOrder.priceListId);

      if (wasSent) {
        // Меняем флаг на false (больше не черновик)
        _clientData!.orders[i] = localOrder.copyWith(isLocalDraft: false);
      }
    }

    // Сохраняем обновленное состояние в кэш
    saveToCache();

    // Заставляем главный экран перерисоваться (появятся синие кнопки)
    notifyListeners();
  }

  /// Срабатывает при авторизации. Ищет в глубоком кэше (Prefs) незаконченные заказы
  /// и возвращает их в рабочую базу, чтобы менеджер не потерял накликанное.
  Future<void> _restoreUnsentDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJsonString = prefs.getString('all_orders');

      if (draftJsonString == null || draftJsonString.isEmpty) return;

      final List<dynamic> draftList = jsonDecode(draftJsonString);

      if (draftList.isEmpty) return;

      // Ищем только настоящие черновики (isLocalDraft == true)
      final unsentDrafts = draftList
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .where((order) => order.isLocalDraft && order.quantity > 0)
          .toList();

      if (unsentDrafts.isEmpty) return;

      debugPrint(
          '🛡️ НАЙДЕНЫ НЕОТПРАВЛЕННЫЕ ЧЕРНОВИКИ: ${unsentDrafts.length} шт. Восстанавливаем...');

      if (_clientData != null) {
        // 🔥 ФИЛЬТР: Восстанавливаем ТОЛЬКО то, чего НЕТ на сервере!
        final actualNewDrafts = unsentDrafts.where((draft) {
          // Ищем такой же заказ в данных, которые только что пришли от GAS
          final existsOnServer = _clientData!.orders.any((serverOrder) =>
              serverOrder.clientPhone == draft.clientPhone &&
              serverOrder.clientName == draft.clientName &&
              serverOrder.priceListId == draft.priceListId &&
              serverOrder.status == draft.status);

          // Если на сервере такого НЕТ — значит это реальный потерянный черновик, восстанавливаем
          // Если на сервере ЕСТЬ — игнорируем (мы его уже отправили, пусть живет как есть)
          return !existsOnServer;
        }).toList();

        if (actualNewDrafts.isEmpty) {
          print('🛡️ Потерянных черновиков нет (все уже на сервере)');
          await prefs.remove('all_orders'); // Чистим буфер на всякий случай
          return;
        }

        print(
            '🛡️ НАЙДЕНЫ ИСТИННО ПОТЕРЯННЫЕ ЧЕРНОВИКИ: ${actualNewDrafts.length} шт. Восстанавливаем...');

        // Убираем дубли
        _clientData!.orders.removeWhere((existingOrder) => actualNewDrafts.any(
            (draft) =>
                draft.clientPhone == existingOrder.clientPhone &&
                draft.clientName == existingOrder.clientName &&
                draft.priceListId == existingOrder.priceListId));

        // Восстанавливаем только истинно новые
        final restoredOrders = actualNewDrafts.map((draft) {
          return draft.copyWith(
            status: 'оформлен',
            isLocalDraft: true,
          );
        }).toList();

        _clientData!.orders.addAll(restoredOrders);
        await saveToCache();
        await prefs.remove('all_orders');
        notifyListeners();
        debugPrint('✅ ЧЕРНОВИКИ УСПЕШНО ВОССТАНОВЛЕНЫ В СПИСОК ЗАКАЗОВ');
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка восстановления черновиков: $e');
    }
  }

  Future<bool> _checkNetwork() async {
    try {
      final result = await _apiService.testConnection();
      return result;
    } catch (e) {
      return false;
    }
  }

  void _showOfflineModeDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📱 Офлайн-режим: данные загружены из кэша'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // 🔥 ДИАЛОГ: ОТСУТСТВИЕ EMAIL ДЛЯ 2FA
  Future<void> _showNoEmailDialog(
      BuildContext context, String role, String adminPhone) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // Нельзя закрыть кликом по фону
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.admin_panel_settings, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Профиль не настроен', style: TextStyle(fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ваш профиль не настроен для безопасного входа.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Обратитесь к администратору для корректировки ваших учетных данных.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              if (adminPhone.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 15, color: Colors.black87),
                            children: [
                              const TextSpan(text: 'Телефон администратора: '),
                              TextSpan(
                                text: adminPhone,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Спасибо за понимание, мы заботимся о безопасности ваших данных.',
                style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Понятно', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================== PUSH УВЕДОМЛЕНИЯ ==================

  Future<void> _handlePushSubscription(String phone) async {
    if (!kIsWeb) return;
    if (_pushSubscriptionAttempted) return;

    _pushSubscriptionAttempted = true;

    try {
      final pushService = WebPushService();
      await pushService.initialize(EnvService.vapidPublicKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('push_user_id', phone);

      if (_currentUser is Employee) {
        await _handleEmployeePushSubscription(pushService);
      } else {
        await _handleClientPushSubscription(pushService);
      }
    } catch (e) {
      debugPrint('❌ Ошибка в _handlePushSubscription: $e');
    }
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД ДЛЯ СОТРУДНИКОВ
  Future<void> _handleEmployeePushSubscription(
      WebPushService pushService) async {
    // Если диалог открыт, не проверяем подписку и не зовем оформить
    if (_isPushDialogShowing) return;

    bool subscribed = await pushService.subscribe();
    if (!subscribed) {
      _startPushReminders();
    }
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД ДЛЯ КЛИЕНТОВ
  Future<void> _handleClientPushSubscription(WebPushService pushService) async {
    // Если уже подписан или диалог открыт — выходим
    if (pushService.isSubscribed || _isPushDialogShowing) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('push_offer_declined') == true) return;

    // 👇 СТАВИМ БЛОКИРОВКУ ПЕРЕД SHOWDIALOG
    _isPushDialogShowing = true;

    final shouldSubscribe = await _showPushOfferDialog();

    // 👇 СНИМАЕМ БЛОКИРОВКУ ПОСЛЕ ЗАКРЫТИЯ
    _isPushDialogShowing = false;

    if (shouldSubscribe) {
      await pushService.subscribe();
    } else {
      await prefs.setBool('push_offer_declined', true);
    }
  }

  Future<bool> _showPushOfferDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('🔔 Быть в курсе заказа?')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Мы будем присылать уведомления, когда:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                _buildBenefitItem(
                    Icons.check_circle, '✅ Заказ принят в обработку'),
                _buildBenefitItem(
                    Icons.factory, '🏭 Заказ запущен в производство'),
                _buildBenefitItem(
                    Icons.check_circle, '🍰 Заказ готов к выдаче'),
                _buildBenefitItem(
                    Icons.local_shipping, '🚚 Статус доставки изменился'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Expanded(
                          child:
                              Text('Это бесплатно и займет всего 2 секунды!')),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    Text('Нет, спасибо', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('✅ Да, хочу быть в курсе!'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _startPushReminders() {
    if (_pushReminderTimer != null) return;

    Future.delayed(Duration(seconds: 5), () => _checkSubscriptionAndRemind());
    _pushReminderTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      _checkSubscriptionAndRemind();
    });
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД НАПОМИНАНИЯ
  Future<void> _checkSubscriptionAndRemind() async {
    if (!kIsWeb) return;

    // 👇 ГЛАВНАЯ ПРОВЕРКА: Если диалог уже открыт, просто выходим
    if (_isPushDialogShowing) return;

    final pushService = WebPushService();
    await pushService.initialize(EnvService.vapidPublicKey);

    if (pushService.isSubscribed) {
      _pushReminderTimer?.cancel();
      _pushReminderTimer = null;
      return;
    }

    _showPushReminder();
  }

  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД ПОКАЗА ДИАЛОГА-НАПОМИНАНИЯ
  void _showPushReminder() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // 👇 ДВОЙНАЯ ПРОВЕРКА ПЕРЕД ПОКАЗОМ
    if (_isPushDialogShowing) return;

    // Включаем блокировку
    _isPushDialogShowing = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🔔 Не забудьте включить уведомления'),
        content: Text(
            'Для быстрого реагирования на заказы необходимо разрешить уведомления.\n\n'
            'Нажмите "Разрешить" в следующем диалоге браузера.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Снимаем блокировку при закрытии
              _isPushDialogShowing = false;
            },
            child: Text('Напомнить позже'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final pushService = WebPushService();
              await pushService.initialize(EnvService.vapidPublicKey);
              final subscribed = await pushService.subscribe();
              if (subscribed) {
                _pushReminderTimer?.cancel();
                _pushReminderTimer = null;
              }
              // Снимаем блокировку после действия
              _isPushDialogShowing = false;
            },
            child: Text('Попробовать сейчас'),
          ),
        ],
      ),
    ).then((_) {
      // 👇 СТРАХОВКА: Снимаем блокировку, если диалог закрыли свайпом или кнопкой "назад"
      _isPushDialogShowing = false;
    });
  }

  // ================== ДЕСЕРИАЛИЗАЦИЯ ==================
  ClientData _deserializeClientData(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) {
      return ClientData();
    }

    final clientData = ClientData();
    final clientDataMap = data;

    // === 1. ПРОДУКТЫ ===
    final rawProducts =
        clientDataMap['products'] ?? clientDataMap['Прайс-лист'];
    if (rawProducts is List) {
      clientData.products = rawProducts
          .map((item) => Product.fromMap(item as Map<String, dynamic>))
          .toList();
      debugPrint('📦 Распарсено продуктов: ${clientData.products.length}');
    }

    // === 2. КАТЕГОРИИ ===
    final rawCategories =
        clientDataMap['priceCategories'] ?? clientDataMap['Категории прайса'];
    if (rawCategories is List) {
      clientData.priceCategories = rawCategories
          .map((item) => PriceCategory.fromJson(item as Map<String, dynamic>))
          .toList();
      debugPrint(
          '📂 Распарсено категорий: ${clientData.priceCategories.length}');
    }

    // === 3. ЗАКАЗЫ ===
    if (clientDataMap['orders'] is List) {
      final Map<String, String> productDisplayNames = {};
      for (var p in clientData.products) {
        productDisplayNames[p.id] = p.displayName;
      }
      clientData.orders = (clientDataMap['orders'] as List)
          .map((item) => OrderItem.fromMap(
                item as Map<String, dynamic>,
                productDisplayNames: productDisplayNames,
              ))
          .toList();
    }

    // === 4. СОСТАВ (Composition) ===
    // ИспользуемComposition.fromJson, так как модель универсальная
    final rawCompositions =
        clientDataMap['compositions'] ?? clientDataMap['Состав'];
    if (rawCompositions is List) {
      clientData.compositions = rawCompositions
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
      debugPrint(
          '📝 Распарсено Composition: ${clientData.compositions.length}');
    }

    // === 5. НАЧИНКИ (Filling / Composition) ===
    // Начинки парсим как Composition, чтобы они попали в общие списки
    final rawFillings = clientDataMap['fillings'] ?? clientDataMap['Начинки'];
    if (rawFillings is List) {
      final fillingsList = rawFillings
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
      clientData.compositions.addAll(fillingsList);
      debugPrint('🧩 Распарсено Начинок: ${fillingsList.length}');
    }

    // === 6. УСЛОВИЯ ХРАНЕНИЯ (StorageCondition) ===
    // ИСПРАВЛЕНО: Проверяем правильный ключ 'Условия хранения'
    final rawStorage =
        clientDataMap['storageConditions'] ?? clientDataMap['Условия хранения'];
    if (rawStorage is List) {
      clientData.storageConditions = rawStorage
          .map(
              (item) => StorageCondition.fromJson(item as Map<String, dynamic>))
          .toList();
      debugPrint(
          '🧊 Распарсено StorageCondition: ${clientData.storageConditions.length}');
      // Добавляем в общий список Composition для универсального доступа
      // clientData.compositions.addAll(clientData.storageConditions.map((s) => s.toComposition()));
    }

    // === 7. УСЛОВИЯ ТРАНСПОРТИРОВКИ (TransportCondition) ===
    // ИСПРАВЛЕНО: Ключ в JSON от GAS идет слитно: "условиятранспортировки"
    final rawTransport = clientDataMap['transportConditions'] ??
        clientDataMap['Условия транспортировки'] ??
        clientDataMap['условиятранспортировки']; // <-- ВОТ ОН!

    if (rawTransport is List) {
      clientData.transportConditions = rawTransport
          .map((item) =>
              TransportCondition.fromJson(item as Map<String, dynamic>))
          .toList();
      debugPrint(
          '🚚 Распарсено TransportCondition: ${clientData.transportConditions.length}');
    }

    // === 8. Остальное ===
    if (clientDataMap['nutritionInfos'] is List) {
      clientData.nutritionInfos = (clientDataMap['nutritionInfos'] as List)
          .map((item) => NutritionInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['deliveryConditions'] is List) {
      clientData.deliveryConditions =
          (clientDataMap['deliveryConditions'] as List)
              .map((item) =>
                  DeliveryCondition.fromJson(item as Map<String, dynamic>))
              .toList();
    }

    if (clientDataMap['clientCategories'] is List) {
      clientData.clientCategories = (clientDataMap['clientCategories'] as List)
          .map((item) => ClientCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['clients'] is List) {
      clientData.clients = (clientDataMap['clients'] as List)
          .map((item) => Client.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    clientData.buildIndexes();
    debugPrint('✅ Десериализация ClientData завершена');
    return clientData;
  }

  Map<String, SheetMetadata> _deserializeMetadata(dynamic metadata) {
    if (metadata == null || metadata is! Map<String, dynamic>) {
      return {};
    }

    final result = <String, SheetMetadata>{};

    for (final entry in metadata.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        try {
          result[entry.key] = SheetMetadata.fromJson(value);
        } catch (e) {
          debugPrint(
              '⚠️ Ошибка десериализации метаданных для ${entry.key}: $e');
        }
      } else if (value is SheetMetadata) {
        // Если уже SheetMetadata, просто добавляем
        result[entry.key] = value;
      }
    }
    return result;
  }

  // ================== УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЕМ ==================

  void selectRole(Employee selectedRole) {
    _currentUser = selectedRole;
    _availableRoles = null;
    notifyListeners();
  }

  void setClient(Client client) {
    _currentUser = client;
    _clientSelected = true;
    notifyListeners();
  }

  // 🔥 СБРОС ВЫБРАННОГО КЛИЕНТА (при возврате к списку)
  void resetClientSelection() {
    _clientSelected = false;
    notifyListeners();
  }

  // 🔥 ВЫБОР КЛИЕНТА (при входе в прайс-лист)
  void selectClient(Client client) {
    _currentUser = client;
    _clientSelected = true;
    notifyListeners();
  }

  Future<void> logout() async {
    _clientSelected = false;
    _pushSubscriptionAttempted = false;
    _pushReminderTimer?.cancel();
    _pushReminderTimer = null;

    _currentUser = null;
    _clientData = null;
    _metadata = null;
    _availableRoles = null;
    _isOffline = false;

    // 🔥 НОВОЕ: Очищаем корзину из памяти при выходе
    // Нам нужно получить контекст, чтобы найти CartProvider
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        // Вызываем жесткий сброс (обнуляем всё, включая _allOrders)
        cartProvider.hardReset();
      } catch (e) {
        debugPrint('⚠️ Не удалось сбросить корзину при выходе: $e');
      }
    }

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_user');
      await prefs.remove('auth_timestamp');
      await prefs.remove('local_metadata');
      await prefs.remove('client_data');
      await prefs.remove('selected_client_id');
      await prefs.remove('current_user_phone');
      await prefs.remove('push_offer_declined');

      // Очищаем Hive
      await _cacheService.clearAll();

      debugPrint('✅ Все данные очищены при выходе');
    } catch (e) {
      debugPrint('❌ Ошибка при выходе: $e');
    }
  }

  Future<void> clearAllCache() async {
    if (!kDebugMode) return;
    await _cacheService.clearAll();
    debugPrint('🧹 Весь кэш очищен');
  }

  // 🔥 ПОЛУЧЕНИЕ ТЕЛЕФОНА АДМИНА ИЗ ЗАГРУЖЕННЫХ ДАННЫХ
  String? get _adminPhone {
    try {
      // Ищем первого сотрудника с ролью "Администратор"
      final admin = _clientData?.clients.whereType<Employee>().firstWhere(
            (e) => e.role?.toLowerCase() == 'администратор',
            orElse: () => throw StateError('Not found'),
          );
      return admin?.phone;
    } catch (e) {
      // Если список пуст или админа нет
      return null;
    }
  }

  @override
  void dispose() {
    _pushReminderTimer?.cancel();
    super.dispose();
  }
}
