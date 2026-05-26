// lib/services/image_preloader.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../generated/auth_assets.dart';

class ImagePreloader {
  static final ImagePreloader _instance = ImagePreloader._internal();
  factory ImagePreloader() => _instance;
  ImagePreloader._internal();

  final Set<String> _preloadedAssets = {};
  final Set<String> _preloadedNetwork = {};
  final Map<String, Completer<bool>> _pendingLoads = {};

  // 🔥 Кэш в SharedPreferences
  static const String _cacheKey = 'preloaded_images_cache';
  static const int _cacheExpiry =
      7 * 24 * 60 * 60 * 1000; // 7 дней в миллисекундах

  Map<String, int> _cacheTimestamps = {};

  // Инициализация кэша
  Future<void> initCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);

      if (cacheData != null) {
        _cacheTimestamps = Map<String, int>.from(jsonDecode(cacheData));

        // Очищаем устаревшие записи
        final now = DateTime.now().millisecondsSinceEpoch;
        _cacheTimestamps
            .removeWhere((key, timestamp) => now - timestamp > _cacheExpiry);

        // Восстанавливаем предзагруженные из кэша
        _preloadedAssets.addAll(_cacheTimestamps.keys);
      }

      debugPrint(
          '📦 Кэш предзагрузки инициализирован: ${_cacheTimestamps.length} записей');
    } catch (e) {
      debugPrint('❌ Ошибка инициализации кэша: $e');
    }
  }

  // Сохранение в кэш
  Future<void> _saveToCache(String key) async {
    try {
      _cacheTimestamps[key] = DateTime.now().millisecondsSinceEpoch;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_cacheTimestamps));
    } catch (e) {
      debugPrint('❌ Ошибка сохранения в кэш: $e');
    }
  }

  // Предзагрузка изображения из assets
  Future<bool> preloadAsset(String assetPath) async {
    if (_preloadedAssets.contains(assetPath)) return true;
    if (_pendingLoads.containsKey(assetPath)) {
      return _pendingLoads[assetPath]!.future;
    }

    final completer = Completer<bool>();
    _pendingLoads[assetPath] = completer;

    try {
      final config = ImageConfiguration();
      final assetImage = AssetImage(assetPath);
      final stream = assetImage.resolve(config);

      final completer = Completer<bool>();

      stream.addListener(
        ImageStreamListener(
          (ImageInfo image, bool synchronousCall) {
            _preloadedAssets.add(assetPath);
            _saveToCache(assetPath); // ← Сохраняем в кэш
            _pendingLoads.remove(assetPath);
            completer.complete(true);
          },
          onError: (dynamic exception, StackTrace? stackTrace) {
            debugPrint('❌ Ошибка предзагрузки asset $assetPath: $exception');
            _pendingLoads.remove(assetPath);
            completer.complete(false);
          },
        ),
      );

      return completer.future;
    } catch (e) {
      debugPrint('❌ Ошибка предзагрузки asset $assetPath: $e');
      _pendingLoads.remove(assetPath);
      completer.complete(false);
      return false;
    }
  }

  // Предзагрузка изображения из сети
  Future<bool> preloadNetwork(String url) async {
    if (_preloadedNetwork.contains(url)) return true;
    if (_pendingLoads.containsKey(url)) {
      return _pendingLoads[url]!.future;
    }

    final completer = Completer<bool>();
    _pendingLoads[url] = completer;

    try {
      final networkImage = NetworkImage(url);
      final stream = networkImage.resolve(ImageConfiguration.empty);

      stream.addListener(
        ImageStreamListener(
          (ImageInfo image, bool synchronousCall) {
            _preloadedNetwork.add(url);
            _saveToCache(url); // ← Сохраняем в кэш
            _pendingLoads.remove(url);
            completer.complete(true);
          },
          onError: (dynamic exception, StackTrace? stackTrace) {
            debugPrint('❌ Ошибка предзагрузки сети $url: $exception');
            _pendingLoads.remove(url);
            completer.complete(false);
          },
        ),
      );

      return completer.future;
    } catch (e) {
      debugPrint('❌ Ошибка предзагрузки сети $url: $e');
      _pendingLoads.remove(url);
      completer.complete(false);
      return false;
    }
  }

  // Предзагрузка изображения продукта
  Future<bool> preloadProductImage(Product product) async {
    // Сначала пробуем из assets
    final assetPath = 'assets/images/products/${product.id}.webp';
    final assetLoaded = await preloadAsset(assetPath);

    // Если в assets нет и есть networkUrl - грузим из сети
    if (!assetLoaded &&
        product.imageUrl != null &&
        product.imageUrl!.isNotEmpty) {
      return preloadNetwork(product.imageUrl!);
    }

    return assetLoaded;
  }

  // Пакетная предзагрузка товаров
  Future<void> preloadProducts(List<Product> products, {int limit = 10}) async {
    debugPrint('🖼️ Предзагрузка изображений товаров (первые $limit)...');

    final toLoad = products.take(limit).toList();
    final futures = toLoad.map((p) => preloadProductImage(p));

    await Future.wait(futures);
    debugPrint('✅ Предзагрузка товаров завершена');
  }

  // Предзагрузка фонов авторизации
  Future<void> preloadAuthBackgrounds() async {
    debugPrint('🖼️ Предзагрузка фонов авторизации...');

    final futures = AuthAssets.backgrounds.map((path) => preloadAsset(path));
    await Future.wait(futures);

    // Предзагружаем логотип
    await preloadAsset(AuthAssets.logo);

    debugPrint('✅ Предзагрузка фонов авторизации завершена');
  }

  // Очистка кэша
  Future<void> clearCache() async {
    _preloadedAssets.clear();
    _preloadedNetwork.clear();
    _pendingLoads.clear();
    _cacheTimestamps.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);

    debugPrint('🗑️ Кэш предзагрузки очищен');
  }

  // Проверка, загружено ли изображение
  bool isPreloaded(String key) {
    return _preloadedAssets.contains(key) || _preloadedNetwork.contains(key);
  }

  // Статистика
  void printStats() {
    debugPrint('📊 Статистика предзагрузки:');
    debugPrint('   Assets: ${_preloadedAssets.length}');
    debugPrint('   Network: ${_preloadedNetwork.length}');
    debugPrint('   В процессе: ${_pendingLoads.length}');
    debugPrint('   В кэше: ${_cacheTimestamps.length}');
  }
}
