// lib/screens/price_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/client_data.dart';
import '../models/price_list_mode.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart';
import '../services/api_service.dart';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  late final AuthProvider _authProvider;
  late final CartProvider _cartProvider;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _cartProvider = Provider.of<CartProvider>(context, listen: false);

    await _cartProvider.loadPriceListMode();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _cartProvider),
      ],
      child: Builder(
        builder: (context) {
          final user = Provider.of<AuthProvider>(context).currentUser;
          final clientData = Provider.of<AuthProvider>(context).clientData;
          final cartProvider = Provider.of<CartProvider>(context);

          final allProducts = clientData?.products ?? [];
          final clientName = user?.name ?? '';
          final currentMode = cartProvider.priceListMode;

          final filteredProducts = _filterProducts(
            allProducts: allProducts,
            mode: currentMode,
            clientName: clientName,
            clientData: clientData,
          );

          final clientDiscount = (user?.discount ?? 0.0) / 100;
          final total = cartProvider.getTotal(allProducts, clientDiscount);
          final meetsMinOrder = cartProvider.meetsMinimumOrderAmount(total);

          final titleText = total > 0
              ? 'Прайс-лист: выбрано на сумму ${total.toStringAsFixed(2)}'
              : 'Прайс-лист';

          final titleColor = total > 0
              ? (meetsMinOrder ? Colors.green : Colors.red)
              : Theme.of(context).appBarTheme.foregroundColor ?? Colors.black;

          return Scaffold(
            appBar: AppBar(
              title: Text(
                titleText,
                style: TextStyle(color: titleColor),
                maxLines: 2,
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              toolbarHeight: total > 0 ? 80.0 : kToolbarHeight,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              actions: [
                // 🔥 КНОПКА КАЛЕНДАРЯ
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () {
                    Navigator.pushNamed(context, '/orders');
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (String result) {
                    if (result == 'export') {
                      _showExportDialog(context);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'export',
                      child: Text('Сохранить прайс'),
                    ),
                  ],
                ),
                DropdownButton<PriceListMode>(
                  value: cartProvider.priceListMode,
                  onChanged: (newMode) async {
                    if (newMode != null) {
                      await cartProvider.setPriceListMode(newMode);
                    }
                  },
                  items: PriceListMode.values.map((PriceListMode mode) {
                    return DropdownMenuItem<PriceListMode>(
                      value: mode,
                      child: Text(mode.label),
                    );
                  }).toList(),
                  underline: Container(),
                ),
                // 🔥 КНОПКА КОРЗИНЫ
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    Navigator.pushNamed(context, '/cart');
                  },
                ),
                const SizedBox(width: 16),
              ],
            ),
            body: filteredProducts.isEmpty
                ? const Center(child: Text('Нет товаров для отображения'))
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final quantity = cartProvider.getQuantity(product.id);

                      return ProductCard(
                        product: product,
                        quantity: quantity,
                        onQuantityChanged: (newQuantity) {
                          cartProvider.setQuantity(
                            product.id,
                            newQuantity,
                            product.multiplicity,
                            allProducts,
                          );
                        },
                      );
                    },
                  ),
            bottomSheet: _buildBottomSheet(
                total, meetsMinOrder, clientDiscount, cartProvider),
          );
        },
      ),
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
        if (allowedCategories.isEmpty) {
          return allProducts;
        }
        return allProducts
            .where((product) => allowedCategories.contains(product.categoryId))
            .toList();
    }
  }

  Widget _buildBottomSheet(double total, bool meetsMinOrder,
      double clientDiscount, CartProvider cartProvider) {
    final formattedTotal = total.toStringAsFixed(2);

    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итого: $formattedTotal ₽',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (clientDiscount > 0)
                  Text(
                    'Скидка: ${(clientDiscount * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.green),
                  ),
                if (!meetsMinOrder)
                  Text(
                    'Минимальная сумма: ${cartProvider.deliveryCondition?.deliveryAmount.toStringAsFixed(0) ?? '0'} ₽',
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: meetsMinOrder ? () => _submitOrder() : null,
            child: const Text('Оформить заказ'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();
    final success = await _cartProvider.submitOrder(
      authProvider.clientData?.products ?? [],
      apiService,
    );

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ успешно отправлен!')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при отправке заказа')),
      );
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
