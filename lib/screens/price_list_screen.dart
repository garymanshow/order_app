// lib/screens/price_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/client.dart';
import '../models/client_data.dart';
import '../models/price_list_mode.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart';
import '../services/image_preloader.dart';
import 'product_detail_screen.dart';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  bool _isInitialized = false;
  bool _preloaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeCartProvider();
      });
    }
  }

  void _initializeCartProvider() {
    if (_isInitialized) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (authProvider.clientData != null && authProvider.currentUser is Client) {
      _isInitialized = true;

      cartProvider.setClient(
        authProvider.currentUser as Client,
        authProvider.clientData!.orders,
        authProvider.clientData!.products,
      );

      cartProvider.loadPriceListMode();

      // 🔥 Предзагрузка изображений товаров (первые 10)
      if (!_preloaded) {
        _preloaded = true;
        ImagePreloader().preloadProducts(
          authProvider.clientData!.products,
          limit: 10,
        );
      }

      print('✅ CartProvider инициализирован');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CartProvider>(
      builder: (context, authProvider, cartProvider, child) {
        // Проверка состояния авторизации
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
                      await authProvider.login(currentClient.phone!);
                    },
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            ),
          );
        }

        final allProducts = clientData.products;
        final clientName = currentClient.name ?? '';
        final currentMode = cartProvider.priceListMode;

        // Фильтруем продукты по режиму
        final filteredProducts = _filterProducts(
          allProducts: allProducts,
          mode: currentMode,
          clientName: clientName,
          clientData: clientData,
        );

        // Считаем общую сумму из заказов клиента
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
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => Navigator.pushNamed(context, '/orders'),
              ),
              PopupMenuButton<String>(
                onSelected: (String result) {
                  if (result == 'export') {
                    _showExportDialog(context);
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

  void _showExportDialog(BuildContext context) {
    String selectedFormat = 'pdf';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Экспорт прайс-листа'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('PDF — полная информация о продукции'),
                  subtitle: const Text('Для каталогов, презентаций, печати'),
                  value: 'pdf',
                  groupValue: selectedFormat,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedFormat = value;
                      });
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('CSV — для этикеток и систем учета'),
                  subtitle: const Text('Только структурированные данные'),
                  value: 'csv',
                  groupValue: selectedFormat,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedFormat = value;
                      });
                    }
                  },
                ),
                if (selectedFormat == 'pdf')
                  ExpansionTile(
                    title: const Text('Что включить в PDF'),
                    initiallyExpanded: true,
                    children: [
                      _buildFieldToggle('Основные поля', true),
                      _buildFieldToggle('Состав', true),
                      _buildFieldToggle('КБЖУ', true),
                      _buildFieldToggle('Условия хранения', true),
                      _buildFieldToggle('Фотографии', false),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  _exportPriceList(context, format: selectedFormat);
                  Navigator.of(context).pop();
                },
                child: const Text('Экспортировать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFieldToggle(String label, bool defaultValue) {
    return CheckboxListTile(
      title: Text(label),
      value: defaultValue,
      onChanged: (bool? value) {
        // TODO: сохранять выбор в состояние
      },
    );
  }

  Future<void> _exportPriceList(BuildContext context,
      {required String format}) async {
    // TODO: Реализовать экспорт в PDF/CSV
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Функция экспорта будет доступна в ближайшем обновлении!')),
    );
  }
}
