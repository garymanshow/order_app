// lib/screens/price_list_screen.dart
import 'dart:convert';
import 'dart:io' show File;
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../models/product.dart';
import '../models/client.dart';
import '../models/client_data.dart';
import '../models/price_category.dart';
import '../models/price_list_mode.dart';
import '../models/composition.dart';
import '../models/nutrition_info.dart';
import '../models/storage_condition.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart';
import '../services/image_preloader.dart';
import '../services/export_service.dart';
import '../services/web_push_service.dart';
import '../services/env_service.dart';
import 'product_detail_screen.dart';
import 'notifications_screen.dart';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  bool _showNotificationDot = false;
  final ExportService _exportService = ExportService();

  // Текущие настройки экспорта по умолчанию
  bool _expBasic = true;
  bool _expComposition = true;
  bool _expNutrition = true;
  bool _expStorage = true;
  bool _expPhotos = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    if (!kIsWeb) return;

    try {
      final pushService = WebPushService();
      await pushService.initialize(EnvService.vapidPublicKey);

      if (mounted) {
        setState(() {
          _showNotificationDot = !pushService.isSubscribed;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка проверки статуса уведомлений: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 СЛУШАЕМ ТОЛЬКО AuthProvider. Он отвечает за список товаров и общую сумму.
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated || authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentClient = authProvider.currentUser as Client?;
        if (currentClient == null) {
          return const Scaffold(
            body: Center(child: Text('Ошибка: клиент не выбран')),
          );
        }

        final clientData = authProvider.clientData;
        if (clientData == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Ошибка загрузки данных'),
                  ElevatedButton(
                    onPressed: () async {
                      await authProvider.login(
                        currentClient.phone!,
                        context: context,
                      );
                    },
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            ),
          );
        }

        // Инициализация CartProvider если нужно
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        if (!cartProvider.isInitialized) {
          // 🔥 СНАЧАЛА УСТАНАВЛИВАЕМ СВЯЗЬ!
          cartProvider.setAuthProvider(authProvider);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            cartProvider.loadCartForClient(
              currentClient,
              clientData.orders,
              clientData.products,
            );
            cartProvider.loadPriceListMode();

            ImagePreloader().preloadProducts(
              clientData.products,
              limit: 10,
            );
          });
        }

        final allProducts = clientData.products;
        final clientName = currentClient.name ?? '';
        final currentMode = cartProvider.priceListMode;

        final filteredProducts = _filterProducts(
          allProducts: allProducts,
          mode: currentMode,
          clientName: clientName,
          clientData: clientData,
        );

        // 🔥 Читаем сумму напрямую из массива (без лишних переменных)
        double total = clientData.orders
            .where((o) =>
                o.clientPhone == currentClient.phone &&
                o.clientName == currentClient.name &&
                o.quantity > 0)
            .fold(0.0, (sum, o) => sum + o.totalPrice);

        // 🔥 Проверяем, есть ли у текущего клиента неотправленные черновики
        final hasUnsent = clientData.orders.any((o) =>
            o.clientPhone == currentClient.phone &&
            o.clientName == currentClient.name &&
            o.isLocalDraft == true &&
            o.quantity > 0);

        final titleText = total > 0
            ? 'Прайс-лист: ${hasUnsent ? '⚠️ ' : ''}выбрано на сумму ${total.toStringAsFixed(2)}'
            : 'Прайс-лист';

        return Scaffold(
          appBar: AppBar(
            title: Text(
              titleText,
              style: TextStyle(
                // 🔥 Если есть несохраненное — делаем текст оранжевым (или любым ярким)
                color: hasUnsent
                    ? Colors.orange
                    : (total > 0 ? Colors.green : null),
                fontWeight: hasUnsent ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
            toolbarHeight: total > 0 ? 80.0 : kToolbarHeight,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                authProvider.resetClientSelection();
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                      _checkNotificationStatus();
                    },
                    tooltip: 'Уведомления о заказов',
                  ),
                  if (_showNotificationDot)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => Navigator.pushNamed(context, '/orders'),
              ),
              PopupMenuButton<String>(
                onSelected: (String result) {
                  if (result == 'export') {
                    _showExportDialog(context, allProducts);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'export',
                    child: Text('Сохранить прайс'),
                  ),
                ],
              ),
              DropdownButton<PriceListMode>(
                value: currentMode,
                onChanged: (newMode) async {
                  if (newMode != null) {
                    await cartProvider.setPriceListMode(newMode);
                  }
                },
                items: PriceListMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode.label),
                  );
                }).toList(),
                underline: Container(),
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => Navigator.pushNamed(context, '/cart'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: filteredProducts.isEmpty
              ? const Center(child: Text('Нет товаров для отображения'))
              : ListView.builder(
                  // УБРАЛИ ValueKey СЮДА, ОН БОЛЬШЕ НЕ НУЖЕН
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];

                    final cartProvider =
                        Provider.of<CartProvider>(context, listen: false);

                    return GestureDetector(
                      key: ValueKey(product.id), // Ключ только по ID товара
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(
                              initialProductId: product.id,
                              allProducts: allProducts,
                            ),
                          ),
                        );
                      },
                      child: ProductCard(
                        product: product,
                        quantity: cartProvider
                            .getQuantity(product.id), // Читаем напрямую
                        onQuantityChanged: (newQuantity) {
                          cartProvider.setQuantity(
                            // Вызываем БЕЗ await
                            product.id,
                            newQuantity,
                            product.multiplicity,
                            Navigator.of(context).context,
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  List<Product> _filterProducts({
    required List<Product> allProducts,
    required PriceListMode mode,
    required String clientName,
    required ClientData? clientData,
  }) {
    switch (mode) {
      case PriceListMode.full:
        return allProducts;
      case PriceListMode.byCategory:
      case PriceListMode.contractOnly:
        final allowedCategories =
            clientData?.clientCategoryIndex[clientName] ?? [];
        if (allowedCategories.isEmpty) return allProducts;
        return allProducts
            .where((product) => allowedCategories.contains(product.categoryId))
            .toList();
    }
  }

  void _showExportDialog(BuildContext context, List<Product> products) {
    // 🔥 ЛОКАЛЬНЫЕ ПЕРЕМЕННЫЕ ДЛЯ ДИАЛОГА
    String selectedFormat = 'pdf';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('📄 Экспорт прайс-листа'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 ВЫБОР ФОРМАТА
                    _buildFormatOption(
                      setState,
                      selectedFormat,
                      'pdf',
                      'PDF — полная информация о продукции',
                      'Для каталогов, презентаций, печати',
                    ),
                    const SizedBox(height: 8),
                    _buildFormatOption(
                      setState,
                      selectedFormat,
                      'csv',
                      'CSV — для этикеток и систем учёта',
                      'Только структурированные данные',
                    ),

                    // 🔥 НАСТРОЙКИ ДЛЯ PDF
                    if (selectedFormat == 'pdf') ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: const Text('Что включить в PDF'),
                        initiallyExpanded: true,
                        children: [
                          _buildCheckbox(
                            setState,
                            'Основные поля',
                            _expBasic, // <---
                            (v) => _expBasic = v ?? true, // <---
                          ),
                          _buildCheckbox(
                            setState,
                            'Состав',
                            _expComposition, // <---
                            (v) => _expComposition = v ?? true, // <---
                          ),
                          _buildCheckbox(
                            setState,
                            'КБЖУ',
                            _expNutrition, // <---
                            (v) => _expNutrition = v ?? true, // <---
                          ),
                          _buildCheckbox(
                            setState,
                            'Условия хранения',
                            _expStorage, // <---
                            (v) => _expStorage = v ?? true, // <---
                          ),

                          // Блок с фотографиями
                          Column(
                            children: [
                              _buildCheckbox(
                                setState,
                                '📷 Фотографии товаров',
                                _expPhotos, // <---
                                (v) {
                                  _expPhotos = v ?? false; // <---
                                  if (_expPhotos && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '⏱️ Фото увеличат время генерации'),
                                        duration: Duration(seconds: 3),
                                        backgroundColor: Color(0xFF5D4037),
                                      ),
                                    );
                                  }
                                },
                              ),
                              if (_expPhotos) // <---
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 48, bottom: 8),
                                  child: Text(
                                    '• Загрузка фото: +10-30 сек',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _exportPriceList(
                    context,
                    products,
                    format: selectedFormat,
                    includeBasic: _expBasic, // <---
                    includeComposition: _expComposition, // <---
                    includeNutrition: _expNutrition, // <---
                    includeStorage: _expStorage, // <---
                    includePhotos: _expPhotos, // <---
                  );
                },
                icon: const Icon(Icons.file_download),
                label: const Text('Экспортировать'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔥 ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ: опция формата
  Widget _buildFormatOption(
    StateSetter setState,
    String selectedFormat,
    String value,
    String title,
    String subtitle,
  ) {
    return InkWell(
      onTap: () => setState(() => selectedFormat = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedFormat == value
                ? const Color(0xFF5D4037)
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selectedFormat == value
              ? const Color(0xFF5D4037).withValues(alpha: 0.1)
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Radio<String>(
                value: value,
                groupValue: selectedFormat,
                onChanged: (v) => setState(() => selectedFormat = v!),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: const Color(0xFF5D4037),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ: чекбокс
  Widget _buildCheckbox(
    StateSetter setState,
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF5D4037),
      contentPadding: EdgeInsets.zero,
    );
  }

  // Функция для приведения текста в порядок (1-я буква большая, 1 точка в конце)
  String _normalizeText(String input) {
    if (input.trim().isEmpty) return '';
    String text = input.trim();
    text = text[0].toUpperCase() + text.substring(1);
    while (text.endsWith('.')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return '$text.';
  }

  Future<void> _exportPriceList(
    BuildContext context,
    List<Product> products, {
    required String format,
    bool includeBasic = true,
    bool includeComposition = true,
    bool includeNutrition = true,
    bool includeStorage = true,
    bool includePhotos = false,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('⏳ Файл формируется и скоро будет сохранен...'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.blueGrey),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final client = authProvider.currentUser;
      final clientData = authProvider.clientData;

      if (clientData == null) throw Exception('Данные не загружены');

      final categoriesMap = <String, PriceCategory>{
        for (var c in clientData.priceCategories) c.id.toString(): c
      };

      final List<ExportProductData> exportProducts = [];

      for (var prod in products) {
        final cat = categoriesMap[prod.categoryId];
        if (cat == null) continue;

        // ==========================================
        // 1. ОПИСАНИЕ
        // ==========================================
        final categoryDescription = cat.description ?? '';
        final productDescription = prod.composition ?? '';

        // ==========================================
        // 2. КБЖУ (Строго по ID прайс-листа)
        // ==========================================
        NutritionInfo? nutrition;
        try {
          nutrition = clientData.nutritionInfos.firstWhere((n) =>
              n.priceListId != null &&
              double.tryParse(n.priceListId ?? '') == double.tryParse(prod.id));
        } catch (_) {}

        // ==========================================
        // 3. УСЛОВИЯ ХРАНЕНИЯ (Слияние без дублей)
        // ==========================================
        final List<StorageCondition> mergedStorages = [];
        final existingKeys = <String>{};

        // Берем из Категории
        if (includeStorage) {
          final catStorages = clientData.storageConditions
              .where((s) =>
                  s.level == 'Категории прайса' &&
                  s.entityId == prod.categoryId)
              .toList();

          for (var s in catStorages) {
            String key = '${s.storageLocation}_${s.temperature}_${s.shelfLife}';
            if (!existingKeys.contains(key)) {
              mergedStorages.add(s);
              existingKeys.add(key);
            }
          }

          // Дополняем из Прайс-листа (если есть)
          final prodStorages = clientData.storageConditions
              .where((s) => s.level == 'Прайс-лист' && s.entityId == prod.id)
              .toList();

          for (var s in prodStorages) {
            String key = '${s.storageLocation}_${s.temperature}_${s.shelfLife}';
            if (!existingKeys.contains(key)) {
              mergedStorages.add(s);
              existingKeys.add(key);
            }
          }
        }

        // ==========================================
        // 4. СОСТАВ (Матрешка)
        // ==========================================
        final compLines = <String>[];

        if (includeComposition) {
          // Шаг А: Начинки уровня Категории
          final catFillings = clientData.compositions
              .where((c) =>
                  c.sheetName == 'Начинки' && c.entityId == prod.categoryId)
              .toList();

          for (var filling in catFillings) {
            final ings = clientData.compositions
                .where((c) =>
                    c.sheetName == 'Начинки' &&
                    c.entityId == filling.id.toString())
                .map((i) => i.ingredientName.trim().toLowerCase())
                .where((s) => s.isNotEmpty)
                .toList();

            if (ings.isNotEmpty) {
              compLines.add(
                  '${_normalizeText(filling.displayName).replaceAll('.', '')}: ${ings.join(', ')}.');
            }
          }

          // Шаг Б: Начинки уровня Прайс-листа
          final prodFillings = clientData.compositions
              .where((c) => c.sheetName == 'Начинки' && c.entityId == prod.id)
              .toList();

          for (var filling in prodFillings) {
            final ings = clientData.compositions
                .where((c) =>
                    c.sheetName == 'Начинки' &&
                    c.entityId == filling.id.toString())
                .map((i) => i.ingredientName.trim().toLowerCase())
                .where((s) => s.isNotEmpty)
                .toList();

            if (ings.isNotEmpty) {
              compLines.add(
                  '${_normalizeText(filling.displayName).replaceAll('.', '')}: ${ings.join(', ')}.');
            }
          }

          // Шаг В: Прямые ингредиенты из листа Состав (Лист == 'Прайс-лист')
          final directIngs = clientData.compositions
              .where((c) => c.sheetName == 'Состав' && c.entityId == prod.id)
              .map((i) => i.ingredientName.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toList();

          if (directIngs.isNotEmpty) {
            compLines.add('${directIngs.join(', ')}.');
          }
        }

        exportProducts.add(ExportProductData(
          product: prod,
          categoryDescription: categoryDescription,
          productDescription: productDescription,
          nutrition: nutrition,
          compositionText: compLines.join(' '),
          mergedStorages: mergedStorages,
        ));
      }

      _exportService.format = format;
      _exportService.includeBasic = includeBasic;
      _exportService.includeComposition = includeComposition;
      _exportService.includeNutrition = includeNutrition;
      _exportService.includeStorage = includeStorage;
      _exportService.includePhotos = includePhotos;
      _exportService.markupPercent = 0;
      _exportService.discountPercent = 0;
      _exportService.roundToNearest = 0;

      final result = await _exportService.generateStructuredPriceList(
        productsData: exportProducts,
        clientName: client?.name ?? 'Клиент',
        clientPhone: client?.phone ?? '',
        categories: clientData.priceCategories,
      );

      // ==========================================
      // ЛОГИКА СОХРАНЕНИЯ (ВАША ОРИГИНАЛЬНАЯ)
      // ==========================================
      if (result != null && mounted) {
        if (kIsWeb) {
          final fileName =
              'price_list_${DateTime.now().millisecondsSinceEpoch}.$format';
          html.Blob blob;

          if (result is html.Blob) {
            blob = result as html.Blob;
          } else if (result is Uint8List) {
            blob = html.Blob([result]);
          } else {
            try {
              blob = html.Blob([Uint8List.fromList(result as List<int>)]);
            } catch (e) {
              blob = html.Blob([result.toString()]);
            }
          }

          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..style.display = 'none';
          html.document.body?.children.add(anchor);
          anchor.click();

          Future.delayed(const Duration(seconds: 2), () {
            html.Url.revokeObjectUrl(url);
            anchor.remove();
          });

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Файл готов: $fileName'),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                  label: 'Скачать вручную',
                  textColor: Colors.white,
                  onPressed: () => html.window.open(url, '_blank')),
            ),
          );
        } else {
          final file = result as File;
          await SharePlus.instance
              .share(ShareParams(files: [XFile(file.path)]));
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Файл создан'), backgroundColor: Colors.green));
        }
      } else if (mounted) {
        throw Exception('Ошибка генерации');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Ошибка: $e'), backgroundColor: Colors.red[700]));
      }
    }
  }
}
