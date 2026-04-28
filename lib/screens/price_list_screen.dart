// lib/screens/price_list_screen.dart
import 'dart:convert';
import 'dart:io' show File;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
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
      print('⚠️ Ошибка проверки статуса уведомлений: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CartProvider>(
      builder: (context, authProvider, cartProvider, child) {
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
        if (!cartProvider.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            cartProvider.setClient(
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

        final clientOrders = clientData.orders
            .where((o) =>
                o.clientPhone == currentClient.phone &&
                o.clientName == currentClient.name &&
                o.quantity > 0)
            .toList();

        double total = 0;
        for (var order in clientOrders) {
          total += order.totalPrice;
        }

        final titleText = total > 0
            ? 'Прайс-лист: выбрано на сумму ${total.toStringAsFixed(2)}'
            : 'Прайс-лист';

        return Scaffold(
          appBar: AppBar(
            title: Text(
              titleText,
              style: TextStyle(
                color: total > 0 ? Colors.green : null,
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

                // 🔥 СБРАСЫВАЕМ ВЫБОР КЛИЕНТА
                authProvider.resetClientSelection();

                // Используем pushReplacementNamed для возврата
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
                    tooltip: 'Уведомления о заказах',
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
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final quantity = cartProvider.getQuantity(product.id);

                    return GestureDetector(
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
                        quantity: quantity,
                        onQuantityChanged: (newQuantity) {
                          cartProvider.setQuantity(
                            product.id,
                            newQuantity,
                            product.multiplicity,
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
    // Убираем диалог загрузки. Показываем уведомление, что процесс пошел.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏳ Файл формируется и скоро будет сохранен...'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.blueGrey,
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final client = authProvider.currentUser;
      final clientData = authProvider.clientData;

      final nutritionByProduct = <String, NutritionInfo>{};
      final storageByProduct = <String, List<StorageCondition>>{};
      final compositionStringsByProduct = <String, String>{};

      if (clientData != null) {
        final categoriesMap = <String, PriceCategory>{};
        for (var cat in clientData.priceCategories) {
          categoriesMap[cat.id.toString()] = cat;
        }

        for (var product in products) {
          final String pId = product.id;
          final String cId = product.categoryId;

          if (includeNutrition) {
            try {
              final nut = clientData.nutritionInfos
                  .firstWhere((n) => n.priceListId == pId);
              nutritionByProduct[pId] = nut;
            } catch (_) {}
          }

          if (includeStorage) {
            final storages = clientData.storageConditions
                .where(
                    (s) => s.level == 'Категории прайса' && s.entityId == cId)
                .toList();
            if (storages.isNotEmpty) {
              storageByProduct[pId] = storages;
            }
          }

          if (includeComposition) {
            final compositionParts = <String>[];

            final fillings = clientData.compositions
                .where((c) =>
                    c.sheetName == 'Категории прайса' && c.entityId == cId)
                .toList();

            for (var filling in fillings) {
              final fillingIngredients = clientData.compositions
                  .where((c) =>
                      c.sheetName == 'Начинки' &&
                      c.entityId == filling.id.toString())
                  .map((i) => i.displayName.trim().toLowerCase())
                  .toList();

              if (fillingIngredients.isNotEmpty) {
                compositionParts.add(
                    '${_normalizeText(filling.displayName).replaceAll('.', '')}: ${fillingIngredients.join(', ')}');
              } else {
                compositionParts.add(
                    _normalizeText(filling.displayName).replaceAll('.', ''));
              }
            }

            final directIngredients = clientData.compositions
                .where((c) => c.sheetName == 'Прайс-лист' && c.entityId == pId)
                .map((i) => _normalizeText(i.displayName).replaceAll('.', ''))
                .toList();

            if (directIngredients.isNotEmpty) {
              compositionParts.addAll(directIngredients);
            }

            if (compositionParts.isNotEmpty) {
              String rawComp = compositionParts.join('. ');
              compositionStringsByProduct[pId] = _normalizeText(rawComp);
            } else if (product.composition.trim().isNotEmpty) {
              compositionStringsByProduct[pId] =
                  _normalizeText(product.composition);
            }
          }
        }
      }

      _exportService.format = format;
      _exportService.includeBasic = includeBasic;
      _exportService.includeComposition = includeComposition;
      _exportService.includeNutrition = includeNutrition;
      _exportService.includeStorage = includeStorage;
      _exportService.includePhotos = includePhotos;

      final result = await _exportService.generatePriceList(
        products: products,
        clientName: client?.name ?? 'Клиент',
        clientPhone: client?.phone ?? '',
        categories: clientData?.priceCategories ?? [],
        compositionsByProduct: compositionStringsByProduct,
        nutritionByProduct: nutritionByProduct,
        storageByProduct: storageByProduct,
      );

      if (result != null && mounted) {
        if (kIsWeb) {
          final bytes = result as Uint8List;
          final fileName =
              'price_list_${DateTime.now().millisecondsSinceEpoch}.$format';
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..style.display = 'none';
          html.document.body?.children.add(anchor);
          anchor.click();
          html.Url.revokeObjectUrl(url);
          anchor.remove();

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('✅ Файл скачан: $fileName'),
                backgroundColor: Colors.green[700]),
          );
        } else {
          final file = result as File;
          await SharePlus.instance
              .share(ShareParams(files: [XFile(file.path)]));

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Файл создан'), backgroundColor: Colors.green),
          );
        }
      } else if (mounted) {
        throw Exception('Ошибка генерации');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Ошибка: $e'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }
}
