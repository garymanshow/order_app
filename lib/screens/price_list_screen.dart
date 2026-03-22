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
  String selectedFormat = 'pdf';

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Экспорт прайс-листа'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PDF option
                InkWell(
                  onTap: () => setState(() => selectedFormat = 'pdf'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedFormat == 'pdf'
                            ? Colors.blue
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: selectedFormat == 'pdf'
                          ? Colors.blue.withValues(alpha: 0.1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Radio<String>(
                            value: 'pdf',
                            groupValue: selectedFormat,
                            onChanged: (value) =>
                                setState(() => selectedFormat = value!),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PDF — полная информация о продукции',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Для каталогов, презентаций, печати',
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
                ),
                const SizedBox(height: 8),
                // CSV option
                InkWell(
                  onTap: () => setState(() => selectedFormat = 'csv'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedFormat == 'csv'
                            ? Colors.blue
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: selectedFormat == 'csv'
                          ? Colors.blue.withValues(alpha: 0.1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Radio<String>(
                            value: 'csv',
                            groupValue: selectedFormat,
                            onChanged: (value) =>
                                setState(() => selectedFormat = value!),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CSV — для этикеток и систем учета',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Только структурированные данные',
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
                ),
                if (selectedFormat == 'pdf') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text('Что включить в PDF'),
                    initiallyExpanded: true,
                    children: [
                      CheckboxListTile(
                        title: const Text('Основные поля'),
                        value: _exportFields['basic'] ?? true,
                        onChanged: (value) {
                          setState(() {
                            _exportFields['basic'] = value ?? true;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Состав'),
                        value: _exportFields['composition'] ?? true,
                        onChanged: (value) {
                          setState(() {
                            _exportFields['composition'] = value ?? true;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('КБЖУ'),
                        value: _exportFields['nutrition'] ?? true,
                        onChanged: (value) {
                          setState(() {
                            _exportFields['nutrition'] = value ?? true;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Условия хранения'),
                        value: _exportFields['storage'] ?? true,
                        onChanged: (value) {
                          setState(() {
                            _exportFields['storage'] = value ?? true;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Фотографии'),
                        value: _exportFields['photos'] ?? false,
                        onChanged: (value) {
                          setState(() {
                            _exportFields['photos'] = value ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _exportPriceList(context, products, format: selectedFormat);
              },
              child: const Text('Экспортировать'),
            ),
          ],
        );
      },
    ),
  );
}

  Future<void> _exportPriceList(
    BuildContext context,
    List<Product> products, {
    required String format,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final client = authProvider.currentUser as Client;
      final clientData = authProvider.clientData!;

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
        } catch (e) {}

        try {
          storageByProduct[product.id] = clientData.storageConditions
              .firstWhere((s) =>
                  s.sheetName == 'Прайс-лист' && s.entityId == product.id);
        } catch (e) {}
      }

      _exportService.format = format;
      _exportService.includeBasic = _exportFields['basic'] ?? true;
      _exportService.includeComposition = _exportFields['composition'] ?? true;
      _exportService.includeNutrition = _exportFields['nutrition'] ?? true;
      _exportService.includeStorage = _exportFields['storage'] ?? true;
      _exportService.includePhotos = _exportFields['photos'] ?? false;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Генерация файла...'),
            ],
          ),
        ),
      );

      final result = await _exportService.generatePriceList(
        products: products,
        clientName: client.name ?? 'Клиент',
        clientPhone: client.phone ?? '',
        compositionsByProduct: compositionsByProduct,
        nutritionByProduct: nutritionByProduct,
        storageByProduct: storageByProduct,
      );

      if (mounted) Navigator.of(context).pop();

      if (result != null && mounted) {
        if (kIsWeb) {
          // 🔥 ДЛЯ WEB — скачиваем файл
          final bytes = result as Uint8List;
          final fileName = 'price_list_${DateTime.now().millisecondsSinceEpoch}.${format == 'pdf' ? 'pdf' : 'csv'}';
          
          // Создаём blob и ссылку для скачивания
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
            const SnackBar(
              content: Text('Файл успешно создан и скачан'),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // 🔥 ДЛЯ МОБИЛЬНЫХ/ДЕСКТОП — делимся файлом
          final file = result as File;
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Прайс-лист ${client.name}',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Файл успешно создан: ${file.path.split('/').last}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Не удалось создать файл');
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Ошибка экспорта: $e');
    }
  }
}
