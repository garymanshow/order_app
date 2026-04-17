// lib/screens/price_list_screen.dart
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/product.dart';
import '../models/client.dart';
import '../models/client_data.dart';
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

  final Map<String, bool> _exportFields = {
    'basic': true,
    'composition': true,
    'nutrition': true,
    'storage': true,
    'photos': false,
  };

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
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                
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
    bool includeBasic = true;
    bool includeComposition = true;
    bool includeNutrition = true;
    bool includeStorage = true;
    bool includePhotos = false; // 🔥 Фото выключены по умолчанию

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
                            includeBasic,
                            (v) => includeBasic = v ?? true,
                          ),
                          _buildCheckbox(
                            setState,
                            'Состав',
                            includeComposition,
                            (v) => includeComposition = v ?? true,
                          ),
                          _buildCheckbox(
                            setState,
                            'КБЖУ',
                            includeNutrition,
                            (v) => includeNutrition = v ?? true,
                          ),
                          _buildCheckbox(
                            setState,
                            'Условия хранения',
                            includeStorage,
                            (v) => includeStorage = v ?? true,
                          ),
                          
                          // 🔥 ФОТОГРАФИИ С ПРЕДУПРЕЖДЕНИЕМ
                          Column(
                            children: [
                              _buildCheckbox(
                                setState,
                                '📷 Фотографии товаров',
                                includePhotos,
                                (v) {
                                  includePhotos = v ?? false;
                                  // 🔥 Показать предупреждение при включении
                                  if (includePhotos && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '⏱️ Фото увеличивают время генерации и размер файла',
                                        ),
                                        duration: Duration(seconds: 3),
                                        backgroundColor: Color(0xFF5D4037),
                                      ),
                                    );
                                  }
                                },
                              ),
                              if (includePhotos)
                                Padding(
                                  padding: const EdgeInsets.only(left: 48, bottom: 8),
                                  child: Text(
                                    '• Загрузка фото: +10-30 сек',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
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
                  // 🔥 Передаём настройки напрямую
                  _exportPriceList(
                    context,
                    products,
                    format: selectedFormat,
                    includeBasic: includeBasic,
                    includeComposition: includeComposition,
                    includeNutrition: includeNutrition,
                    includeStorage: includeStorage,
                    includePhotos: includePhotos,
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

  Future<void> _exportPriceList(
    BuildContext context,
    List<Product> products, {
    required String format,
    required bool includeBasic,
    required bool includeComposition,
    required bool includeNutrition,
    required bool includeStorage,
    required bool includePhotos,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final client = authProvider.currentUser as Client;
      final clientData = authProvider.clientData!;

      // 🔥 Подготавливаем дополнительные данные
      final compositionsByProduct = <String, List<Composition>>{};
      final nutritionByProduct = <String, NutritionInfo>{};
      final storageByProduct = <String, StorageCondition>{};

      for (var product in products) {
        compositionsByProduct[product.id] = clientData.compositions
            .where((c) => c.sheetName == 'Состав' && c.entityId == product.id)
            .toList();

        try {
          nutritionByProduct[product.id] = clientData.nutritionInfos
              .firstWhere((n) => n.priceListId == product.id);
        } catch (_) {}

        try {
          storageByProduct[product.id] = clientData.storageConditions
              .firstWhere((s) =>
                  s.level == 'Прайс-лист' && s.entityId == product.id);
        } catch (e) {}
      }

      // 🔥 Настраиваем сервис
      _exportService.format = format;
      _exportService.includeBasic = includeBasic;
      _exportService.includeComposition = includeComposition;
      _exportService.includeNutrition = includeNutrition;
      _exportService.includeStorage = includeStorage;
      _exportService.includePhotos = includePhotos;

      if (!context.mounted) return;

      // 🔥 Показываем прогресс с сообщением о фото
      final photoMessage = includePhotos ? '\n📷 Загрузка фото...' : '';
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF5D4037),
              ),
              const SizedBox(height: 16),
              const Text('Генерация файла...'),
              if (includePhotos) ...[
                const SizedBox(height: 8),
                Text(
                  'Это может занять до 1 минуты',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      // 🔥 Генерируем файл
      final result = await _exportService.generatePriceList(
        products: products,
        clientName: client.name ?? 'Клиент',
        clientPhone: client.phone ?? '',
        compositionsByProduct: compositionsByProduct,
        nutritionByProduct: nutritionByProduct,
        storageByProduct: storageByProduct,
      );

      if (context.mounted) {
        try {
          Navigator.of(context).pop(); // Закрываем лоадер
        } catch (_) {}
      }

      if (result != null && context.mounted) {
        if (kIsWeb) {
          // 🔥 WEB: скачивание
          final bytes = result as Uint8List;
          final fileName = 'price_list_${DateTime.now().millisecondsSinceEpoch}.${format == 'pdf' ? 'pdf' : 'csv'}';
          
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = fileName;
          
          html.document.body?.children.add(anchor);
          anchor.click();
          html.document.body?.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('✅ Файл скачан: $fileName'),
                ],
              ),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // 🔥 Mobile/Desktop: Share
          final file = result as File;
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Прайс-лист ${client.name}',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Файл создан: ${file.path.split('/').last}'),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('Не удалось создать файл');
      }
    } catch (e) {
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('❌ Ошибка экспорта: $e');
    }
  }
}
