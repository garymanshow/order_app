// lib/services/silent_sync_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'cache_service.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart'; // 🔥 Добавлен импорт
import '../models/order_item.dart'; // 🔥 Добавлен импорт
import '../models/sheet_metadata.dart'; // 🔥 Добавлен импорт

/// 🔥 Сервис тихой фоновой синхронизации метаданных
class SilentSyncService {
  final ApiService _api;
  final CacheService _cache;
  AuthProvider? _auth; // 🔥 Nullable

  // 🔥 Третий параметр — именованный и опциональный
  SilentSyncService(this._api, this._cache, {AuthProvider? auth}) {
    if (auth != null) _auth = auth;
  }

  // 🔥 Метод для поздней инъекции
  void setAuthProvider(AuthProvider auth) {
    _auth = auth;
  }

  /// 🔥 Проверить обновления
  Future<void> checkIfNeeded() async {
    // 🔥 Безопасная проверка: если auth ещё не установлен — выходим
    if (_auth == null) {
      print('⚠️ SilentSyncService: AuthProvider не установлен, пропускаем');
      return;
    }

    // 1. Проверяем тайминг (не чаще 24ч)
    if (!await _cache.shouldCheckMetadata()) return;

    // 2. Проверяем интернет
    // 🔥 FIX: Connectivity().checkConnectivity() возвращает List<ConnectivityResult>
    final connectivityList = await Connectivity().checkConnectivity();
    final connectivity = connectivityList.isNotEmpty
        ? connectivityList.first
        : ConnectivityResult.none;

    if (connectivity == ConnectivityResult.none) return;

    try {
      // 3. Лёгкий запрос метаданных
      final result = await _api.checkMetadataUpdates(
        phone:
            _auth!.currentUser?.phone, // 🔥 FIX: ! после проверки _auth != null
        localMetadata:
            _cache.getMetadata(), // 🔥 FIX: убрать await, метод не Future
      );

      if (result == null) return;

      final hasUpdates = result['hasUpdates'] as bool? ?? false;
      final changedSheets = List<String>.from(result['changedSheets'] ?? []);

      // 4. Сохраняем время проверки
      await _cache.markMetadataChecked();

      if (hasUpdates && changedSheets.isNotEmpty) {
        await _cache.setPendingUpdates(changedSheets);

        // 🔥 FIX: _auth! после проверки выше
        _auth!.setHasPendingUpdates(true, changedSheets);

        print('✅ Найдено обновлений: ${changedSheets.join(', ')}');

        // 5. Если WiFi → качаем полные данные сразу в фоне
        if (connectivity == ConnectivityResult.wifi) {
          await _syncFullDataInBackground();
        }
      }
    } catch (e) {
      print('⚠️ Ошибка тихой проверки: $e');
    }
  }

  /// 🔥 Фоновая полная синхронизация
  Future<void> _syncFullDataInBackground() async {
    try {
      // 🔥 FIX: _auth! после проверки
      final phone = _auth?.currentUser?.phone;
      if (phone == null) return;

      final result = await _api.authenticate(
        phone: phone,
        localMetadata: _cache.getMetadata(), // 🔥 FIX: убрать await
      );

      if (result != null && result['success'] == true) {
        // Сохраняем метаданные
        final metadata = _deserializeMetadata(result['metadata']);
        await _cache.saveMetadata(metadata);

        // Сохраняем данные
        if (result['data'] != null) {
          final data = result['data'] as Map<String, dynamic>;

          if (data['orders'] != null) {
            await _cache.saveOrders(_deserializeOrders(data['orders']));
          }
          if (data['products'] != null) {
            await _cache.saveProducts(_deserializeProducts(data['products']));
          }
          // При необходимости добавить другие поля: fillings, compositions, etc.
        }

        // Очищаем флаг ожидающих обновлений
        await _cache.clearPendingUpdates();
        _auth!.setHasPendingUpdates(false, []); // 🔥 FIX: _auth!

        print('✅ Фоновое обновление завершено');
      }
    } catch (e) {
      print('❌ Ошибка фонового обновления: $e');
    }
  }

  /// 🔥 Принудительная синхронизация
  Future<bool> syncNow() async {
    await _cache.markMetadataChecked();
    await _syncFullDataInBackground();
    return true;
  }

  // 🔥 ХЕЛПЕРЫ ДЛЯ ДЕСЕРИАЛИЗАЦИИ
  Map<String, SheetMetadata> _deserializeMetadata(dynamic raw) {
    if (raw is! Map<String, dynamic>) return {};
    final result = <String, SheetMetadata>{};
    for (final entry in raw.entries) {
      final value = entry.value as Map<String, dynamic>?;
      if (value != null) {
        result[entry.key] = SheetMetadata(
          lastUpdate: DateTime.parse(value['lastUpdate'] as String),
          editor: value['editor'] as String? ?? '',
        );
      }
    }
    return result;
  }

  List<OrderItem> _deserializeOrders(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  List<Product> _deserializeProducts(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((item) => Product.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}
