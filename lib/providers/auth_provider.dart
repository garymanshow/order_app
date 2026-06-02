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
// 🔥 2FA TOKEN: Удален импорт TwoFactorScreen, он больше не нужен
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
      bool hasNetwork = await _checkNetwork();

      if (hasNetwork) {
        try {
          // ==========================================
          // 🔥 NОВОЕ: БЕСШУМНЫЙ СБОР ПУШ-ПОДПИСКИ
          // ==========================================
          Map<String, dynamic>? currentPushData;
          if (kIsWeb) {
            try {
              final pushService = WebPushService();
              await pushService.initialize(EnvService.vapidPublicKey);
              currentPushData = await pushService.getSubscriptionForAuth();
              if (currentPushData != null) {
                debugPrint(
                    '📬 Найдена активная подписка, прикрепляем к запросу');
              } else {
                debugPrint('📭 Подписка не найдена');
              }
            } catch (e) {
              debugPrint('⚠️ Ошибка проверки пуш-статуса: $e');
            }
          }

          // ==========================================
          // 🔥 2FA TOKEN: Получаем токен устройства
          // ==========================================
          final prefs = await SharedPreferences.getInstance();
          final String? deviceToken =
              prefs.getString('device_token_$normalizedPhone');

          // 📤 ОСНОВНОЙ ЗАПРОС АВТОРИЗАЦИИ
          final authResponse = await _apiService.authenticate(
            phone: normalizedPhone,
            localMetadata: localMetadata,
            pushData: currentPushData,
            deviceToken: deviceToken, // <--- ПРИКРЕПЛЯЕМ ТОКЕН
          );

          // ==========================================
          // 🔥 2FA TOKEN: ОБРАБОТКА ОТВЕТОВ 2FA
          // ==========================================
          if (authResponse != null &&
              authResponse['status'] == '2fa_required') {
            debugPrint('🔐 2FA: Требуется код подтверждения');
            _isLoading = false;
            notifyListeners();

            final code = await _show2FACodeDialog(
                context, authResponse['email'] ?? 'вашу почту');

            if (code == null || code.isEmpty) {
              throw Exception('Вход отменен');
            }

            _isLoading = true;
            notifyListeners();

            // Повторяем запрос С КОДОМ
            final verifyResponse = await _apiService.authenticate(
              phone: normalizedPhone,
              localMetadata: localMetadata,
              pushData: currentPushData,
              code: code, // <--- ПРИКРЕПЛЯЕМ КОД
            );

            if (verifyResponse != null &&
                verifyResponse['status'] == '2fa_success') {
              // Сохраняем новый токен устройства
              await prefs.setString('device_token_$normalizedPhone',
                  verifyResponse['newDeviceToken']);
              debugPrint('✅ 2FA: Устройство доверено, токен сохранен');

              // Финальный запрос за данными (пройдет по сценарию БИНГО)
              final finalResponse = await _apiService.authenticate(
                phone: normalizedPhone,
                localMetadata: localMetadata,
                pushData: currentPushData,
                deviceToken: verifyResponse['newDeviceToken'],
              );

              if (finalResponse != null &&
                  finalResponse['status'] == 'success') {
                await _handleServerResponse(
                    finalResponse, normalizedPhone, context);
                _isOffline = false;
              } else {
                throw Exception('Ошибка финальной авторизации');
              }
            } else {
              throw Exception(
                  verifyResponse?['message'] ?? 'Ошибка проверки кода');
            }
          }
          // ==========================================
          // КОНЕЦ БЛОКА 2FA
          // ==========================================
          else if (authResponse != null) {
            // Если 2fa_required не пришло, значит это либо success, либо ошибка (обрабатывается в _handleServerResponse)
            await _handleServerResponse(authResponse, normalizedPhone, context);
            _isOffline = false;
          } else {
            throw Exception('Пустой ответ от сервера');
          }
        } catch (e) {
          debugPrint('⚠️ Ошибка сети или 2FA: $e');
          final hasCache = await _loadCachedData();
          if (hasCache && _currentUser != null) {
            _isOffline = true;
            if (context.mounted) _showOfflineModeDialog(context);
          } else {
            rethrow;
          }
        }
      } else {
        final hasCache = await _loadCachedData();
        if (hasCache && _currentUser != null) {
          _isOffline = true;
          if (context.mounted) _showOfflineModeDialog(context);
        } else {
          throw Exception('Нет интернета и нет кэшированных данных');
        }
      }

      _isLoading = false;
      notifyListeners();
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

  // 🔥 2FA TOKEN: ДИАЛОГ ВВОДА КОДА
  Future<String?> _show2FACodeDialog(BuildContext context, String email) async {
    final TextEditingController codeController = TextEditingController();
    String? errorMessage;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.blue, size: 28),
                  SizedBox(width: 10),
                  Text('Подтверждение входа', style: TextStyle(fontSize: 20)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Для безопасности введите 6-значный код, отправленный на:'),
                  const SizedBox(height: 8),
                  Text(email,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: codeController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 28, letterSpacing: 10),
                    autofocus: true,
                    decoration: InputDecoration(
                      counterText: "",
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                    ),
                    onChanged: (val) {
                      if (errorMessage != null) {
                        setDialogState(() => errorMessage = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (codeController.text.length == 6) {
                      Navigator.of(dialogContext).pop(codeController.text);
                    } else {
                      setDialogState(() => errorMessage = 'Введите 6 цифр');
                    }
                  },
                  child: const Text('Подтвердить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================== ТИХАЯ СИНХРОНИЗАЦИЯ ==================

  void setSilentSync(SilentSyncService service) {
    _silentSync = service;
  }

  void setHasPendingUpdates(bool value, List<String> sheets) {
    _hasPendingUpdates = value;
    _pendingSheets = sheets;
    notifyListeners();
  }

  Future<void> checkForUpdates() async {
    await _silentSync?.checkIfNeeded();
  }

  Future<void> syncNow() async {
    await _silentSync?.syncNow();
  }

  Future<void> _handlePushSubscriptionSafe(String phone) async {
    try {
      await _handlePushSubscription(phone);
    } catch (e) {
      debugPrint('⚠️ PUSH ошибка (безопасный режим): $e');
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
      // Если сервер вернул ошибку (например, пользователь не найден), выбрасываем её
      if (authResponse.containsKey('status') &&
          authResponse['status'] == 'error') {
        throw Exception(authResponse['message'] ?? 'Ошибка авторизации');
      }
      throw Exception('Сервер не вернул данные пользователя');
    }

    debugPrint('📡 ШАГ 1: Проверка ответа сервера...');
    if (data != null && data is Map<String, dynamic>) {
      final rawCategories = data['priceCategories'];
      if (rawCategories is List && rawCategories.isNotEmpty) {
        debugPrint('📡 ШАГ 1: Пример первой категории: ${rawCategories[0]}');
      }
    }

    // Десериализуем пользователя
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

    // Сохраняем данные в кэш
    if (data != null && metadata != null) {
      debugPrint('💾 ШАГ 2: Начинаем десериализацию ClientData...');

      _clientData = _deserializeClientData(data);
      _metadata = _deserializeMetadata(metadata);

      debugPrint(
          '💾 ШАГ 3: Результат парсинга. Категорий в объекте: ${_clientData?.priceCategories.length ?? 0}');

      await saveToCache();
      await _restoreUnsentDrafts();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'auth_user', jsonEncode(_currentUser?.toJson() ?? {}));
      await prefs.setString('auth_timestamp', DateTime.now().toIso8601String());
    }
  }

  Future<void> saveToCache() async {
    if (_clientData == null) return;

    await _cacheService.saveOrders(_clientData!.orders);
    await _cacheService.saveProducts(_clientData!.products);
    await _cacheService.saveFillings(_clientData!.fillings);
    await _cacheService.saveCompositions(_clientData!.compositions);

    debugPrint(
        '🧊 ШАГ 3: Сохраняем условий хранения: ${_clientData!.storageConditions.length}');
    await _cacheService.saveStorageConditions(_clientData!.storageConditions);

    debugPrint(
        '🚚 ШАГ 3: Сохраняем условий транспортировки: ${_clientData!.transportConditions.length}');
    await _cacheService
        .saveTransportConditions(_clientData!.transportConditions);

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

  Future<void> refreshOrdersFromCache() async {
    try {
      final freshOrders = _cacheService.getOrders();
      if (_clientData != null) {
        _clientData!.orders = freshOrders;
        notifyListeners();
        debugPrint('🔄 Заказы в интерфейсе обновлены из кэша');
      }
    } catch (e) {
      debugPrint('❌ Ошибка обновления заказов из кэша: $e');
    }
  }

  void updateGlobalOrders(List<OrderItem> updatedOrders) {
    if (_clientData != null) {
      _clientData!.orders = updatedOrders;
      notifyListeners();
    }
  }

  // ==========================================
  // ЗАЩИТА ОТ ЗАБЫВЧИВОСТИ МЕНЕДЖЕРА
  // ==========================================

  void markOrdersAsSent(List<OrderItem> sentOrders) {
    if (_clientData == null) return;

    final validSentOrders = sentOrders
        .where((o) => o.clientName.isNotEmpty && o.priceListId.isNotEmpty)
        .toList();

    if (validSentOrders.isEmpty) return;

    for (int i = 0; i < _clientData!.orders.length; i++) {
      final localOrder = _clientData!.orders[i];

      final wasSent = validSentOrders.any((sentOrder) =>
          localOrder.clientPhone == sentOrder.clientPhone &&
          localOrder.clientName == sentOrder.clientName &&
          localOrder.priceListId == sentOrder.priceListId);

      if (wasSent) {
        _clientData!.orders[i] = localOrder.copyWith(isLocalDraft: false);
      }
    }

    saveToCache();
    notifyListeners();
  }

  Future<void> _restoreUnsentDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJsonString = prefs.getString('all_orders');

      if (draftJsonString == null || draftJsonString.isEmpty) return;

      final List<dynamic> draftList = jsonDecode(draftJsonString);
      if (draftList.isEmpty) return;

      final unsentDrafts = draftList
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .where((order) => order.isLocalDraft && order.quantity > 0)
          .toList();

      if (unsentDrafts.isEmpty) return;

      debugPrint(
          '🛡️ НАЙДЕНЫ НЕОТПРАВЛЕННЫЕ ЧЕРНОВИКИ: ${unsentDrafts.length} шт.');

      if (_clientData != null) {
        final actualNewDrafts = unsentDrafts.where((draft) {
          final existsOnServer = _clientData!.orders.any((serverOrder) =>
              serverOrder.clientPhone == draft.clientPhone &&
              serverOrder.clientName == draft.clientName &&
              serverOrder.priceListId == draft.priceListId &&
              serverOrder.status == draft.status);
          return !existsOnServer;
        }).toList();

        if (actualNewDrafts.isEmpty) {
          await prefs.remove('all_orders');
          return;
        }

        _clientData!.orders.removeWhere((existingOrder) => actualNewDrafts.any(
            (draft) =>
                draft.clientPhone == existingOrder.clientPhone &&
                draft.clientName == existingOrder.clientName &&
                draft.priceListId == existingOrder.priceListId));

        final restoredOrders = actualNewDrafts.map((draft) {
          return draft.copyWith(status: 'оформлен', isLocalDraft: true);
        }).toList();

        _clientData!.orders.addAll(restoredOrders);
        await saveToCache();
        await prefs.remove('all_orders');
        notifyListeners();
        debugPrint('✅ ЧЕРНОВИКИ УСПЕШНО ВОССТАНОВЛЕНЫ');
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка восстановления черновиков: $e');
    }
  }

  Future<bool> _checkNetwork() async {
    try {
      return await _apiService.testConnection();
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

  // 🔥 ДИАЛОГ: ОТСУТСТВИЕ EMAIL ДЛЯ 2FA (Оставлен на случай, если понадобится для других проверок)
  Future<void> _showNoEmailDialog(
      BuildContext context, String role, String adminPhone) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Профиль не настроен', style: TextStyle(fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ваш профиль не настроен для безопасного входа.',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                  'Обратитесь к администратору для корректировки ваших учетных данных.',
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
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
                                      color: Colors.blue)),
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
                      color: Colors.grey)),
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
                        borderRadius: BorderRadius.circular(8))),
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

  Future<void> _handleEmployeePushSubscription(
      WebPushService pushService) async {
    if (_isPushDialogShowing) return;
    bool subscribed = await pushService.subscribe();
    if (!subscribed) {
      _startPushReminders();
    }
  }

  Future<void> _handleClientPushSubscription(WebPushService pushService) async {
    if (pushService.isSubscribed || _isPushDialogShowing) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('push_offer_declined') == true) return;

    _isPushDialogShowing = true;
    final shouldSubscribe = await _showPushOfferDialog();
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
            title: const Row(
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
                const Text('Мы будем присылать уведомления, когда:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildBenefitItem(
                    Icons.check_circle, '✅ Заказ принят в обработку'),
                _buildBenefitItem(
                    Icons.factory, '🏭 Заказ запущен в производство'),
                _buildBenefitItem(
                    Icons.check_circle, '🍰 Заказ готов к выдаче'),
                _buildBenefitItem(
                    Icons.local_shipping, '🚚 Статус доставки изменился'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
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
                  child: const Text('Нет, спасибо',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('✅ Да, хочу быть в курсе!')),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text))
        ],
      ),
    );
  }

  void _startPushReminders() {
    if (_pushReminderTimer != null) return;
    Future.delayed(
        const Duration(seconds: 5), () => _checkSubscriptionAndRemind());
    _pushReminderTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkSubscriptionAndRemind();
    });
  }

  Future<void> _checkSubscriptionAndRemind() async {
    if (!kIsWeb || _isPushDialogShowing) return;

    final pushService = WebPushService();
    await pushService.initialize(EnvService.vapidPublicKey);

    if (pushService.isSubscribed) {
      _pushReminderTimer?.cancel();
      _pushReminderTimer = null;
      return;
    }
    _showPushReminder();
  }

  void _showPushReminder() {
    final context = navigatorKey.currentContext;
    if (context == null || _isPushDialogShowing) return;

    _isPushDialogShowing = true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔔 Не забудьте включить уведомления'),
        content: const Text(
            'Для быстрого реагирования на заказы необходимо разрешить уведомления.\n\nНажмите "Разрешить" в следующем диалоге браузера.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isPushDialogShowing = false;
            },
            child: const Text('Напомнить позже'),
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
              _isPushDialogShowing = false;
            },
            child: const Text('Попробовать сейчас'),
          ),
        ],
      ),
    ).then((_) => _isPushDialogShowing = false);
  }

  // ================== ДЕСЕРИАЛИЗАЦИЯ ==================
  ClientData _deserializeClientData(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) return ClientData();

    final clientData = ClientData();
    final clientDataMap = data;

    final rawProducts =
        clientDataMap['products'] ?? clientDataMap['Прайс-лист'];
    if (rawProducts is List) {
      clientData.products = rawProducts
          .map((item) => Product.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    final rawCategories =
        clientDataMap['priceCategories'] ?? clientDataMap['Категории прайса'];
    if (rawCategories is List) {
      clientData.priceCategories = rawCategories
          .map((item) => PriceCategory.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (clientDataMap['orders'] is List) {
      final Map<String, String> productDisplayNames = {};
      for (var p in clientData.products) {
        productDisplayNames[p.id] = p.displayName;
      }
      clientData.orders = (clientDataMap['orders'] as List)
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>,
              productDisplayNames: productDisplayNames))
          .toList();
    }

    final rawCompositions =
        clientDataMap['compositions'] ?? clientDataMap['Состав'];
    if (rawCompositions is List) {
      clientData.compositions = rawCompositions
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final rawFillings = clientDataMap['fillings'] ?? clientDataMap['Начинки'];
    if (rawFillings is List) {
      final fillingsList = rawFillings
          .map((item) => Composition.fromJson(item as Map<String, dynamic>))
          .toList();
      clientData.compositions.addAll(fillingsList);
    }

    final rawStorage =
        clientDataMap['storageConditions'] ?? clientDataMap['Условия хранения'];
    if (rawStorage is List) {
      clientData.storageConditions = rawStorage
          .map(
              (item) => StorageCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final rawTransport = clientDataMap['transportConditions'] ??
        clientDataMap['Условия транспортировки'] ??
        clientDataMap['условиятранспортировки'];
    if (rawTransport is List) {
      clientData.transportConditions = rawTransport
          .map((item) =>
              TransportCondition.fromJson(item as Map<String, dynamic>))
          .toList();
    }

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
    return clientData;
  }

  Map<String, SheetMetadata> _deserializeMetadata(dynamic metadata) {
    if (metadata == null || metadata is! Map<String, dynamic>) return {};

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

  void resetClientSelection() {
    _clientSelected = false;
    notifyListeners();
  }

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

    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
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

  String? get _adminPhone {
    try {
      final admin = _clientData?.clients.whereType<Employee>().firstWhere(
            (e) => e.role?.toLowerCase() == 'администратор',
            orElse: () => throw StateError('Not found'),
          );
      return admin?.phone;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _pushReminderTimer?.cancel();
    super.dispose();
  }
}
