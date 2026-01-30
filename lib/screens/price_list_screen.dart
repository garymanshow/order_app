// lib/screens/price_list_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/price_list_mode.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../models/order_item.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart'; // ← ДОБАВЬТЕ ИМПОРТ

class PriceListScreen extends StatefulWidget {
  final Client client;

  const PriceListScreen({Key? key, required this.client}) : super(key: key);

  @override
  _PriceListScreenState createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen>
    with TickerProviderStateMixin {
  late PriceListMode _currentMode;
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentMode = _loadSavedMode(widget.client.phone ?? '');

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _loadProductsAndRestoreCart();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsAndRestoreCart() async {
    try {
      // 🔥 СНАЧАЛА ПРОБУЕМ ЗАГРУЗИТЬ ИЗ ProductsProvider
      final productsProvider =
          Provider.of<ProductsProvider>(context, listen: false);

      if (productsProvider.products.isNotEmpty) {
        // Используем данные из ProductsProvider
        _products = productsProvider.products;
      } else {
        // Если нет в ProductsProvider, пробуем кэш
        final prefs = await SharedPreferences.getInstance();
        final priceJson = prefs.getString('client_price_data');

        if (priceJson != null) {
          _products = _deserializeProducts(priceJson);
        } else {
          // 🔥 Если нигде нет данных - загружаем с сервера
          await productsProvider.loadProducts();
          _products = productsProvider.products;
        }
      }

      // Загружаем заказы
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString('client_orders_data');
      List<OrderItem> orders = [];
      if (ordersJson != null) {
        orders = _deserializeOrders(ordersJson);
      }

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.setClient(widget.client);
      await _restoreCartFromOrders(orders, _products);

      final hasDebt = _calculateDebt(orders) > 0;
      if (hasDebt) {
        _pulseController.repeat(reverse: true);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки данных: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreCartFromOrders(
      List<OrderItem> orders, List<Product> products) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.setClient(widget.client);

    final clientOrders = orders
        .where((order) =>
            order.clientPhone == widget.client.phone &&
            order.clientName == widget.client.name)
        .toList();

    print(
        '📱 Заказы для клиента в price_list_screen ${widget.client.name}: ${clientOrders.length}');
    for (var order in clientOrders) {
      print(
          '📋 Заказ: ${order.productName}, статус: ${order.status}, количество: ${order.quantity}');
    }

    cartProvider.restoreCartFromOrders(clientOrders, products);
    await Future.delayed(Duration(milliseconds: 100));
  }

  double _calculateDebt(List<OrderItem> orders) {
    double totalDebt = 0;
    for (var order in orders) {
      if (order.status == 'доставлен' &&
          order.paymentAmount < order.totalPrice) {
        totalDebt += order.totalPrice - order.paymentAmount;
      }
    }
    return totalDebt;
  }

  PriceListMode _loadSavedMode(String phone) {
    return PriceListMode.full;
  }

  void _saveMode(String phone, PriceListMode mode) {}

  void _changeMode(PriceListMode newMode) {
    setState(() {
      _currentMode = newMode;
    });
    _saveMode(widget.client.phone ?? '', newMode);
  }

  List<Product> _deserializeProducts(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<OrderItem> _deserializeOrders(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  List<Product> _filterProductsByMode(List<Product> products) {
    switch (_currentMode) {
      case PriceListMode.full:
        return products;
      case PriceListMode.byCategory:
        return products;
      case PriceListMode.contractOnly:
        return products;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (_isLoading) {
          return Scaffold(
            appBar: AppBar(title: Text('Загрузка прайса...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (_error != null) {
          return Scaffold(
            appBar: AppBar(title: Text('Ошибка')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProductsAndRestoreCart,
                    child: Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final orders = _getCurrentOrders();
        final debt = _calculateDebt(orders);
        final hasDebt = debt > 0;

        final filteredProducts = _filterProductsByMode(_products);
        if (filteredProducts.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('Прайс-лист пуст')),
            body: const Center(child: Text('Нет товаров для отображения')),
          );
        }

        final discount = (widget.client.discount ?? 0) / 100.0;
        final total = cartProvider.getTotal(_products, discount);

        String title = 'Заказ для: ${widget.client.name ?? 'Клиент'}';
        if ((widget.client.deliveryAddress ?? '').isNotEmpty) {
          title += ' — ${widget.client.deliveryAddress}';
        }
        title += '  Итого: ${total.toStringAsFixed(2)} ₽';

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 80,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: IconButton(
                      icon: Icon(
                        Icons.history,
                        color: hasDebt ? Colors.red : Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/orders',
                            arguments: widget.client);
                      },
                      tooltip:
                          hasDebt ? 'Есть задолженность!' : 'История заказов',
                    ),
                  );
                },
              ),
              PopupMenuButton<PriceListMode>(
                icon: Icon(Icons.view_list, color: Colors.white),
                tooltip: 'Режим отображения',
                onSelected: (PriceListMode mode) {
                  _changeMode(mode);
                },
                itemBuilder: (BuildContext context) =>
                    PriceListMode.values.map((PriceListMode mode) {
                  return PopupMenuItem<PriceListMode>(
                    value: mode,
                    child: Row(
                      children: [
                        if (mode == _currentMode)
                          Icon(Icons.check, size: 16, color: Colors.green),
                        SizedBox(width: mode == _currentMode ? 8 : 0),
                        Text(mode.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () {
                  Navigator.pushNamed(context, '/cart', arguments: {
                    'client': widget.client,
                    'products': _products,
                  });
                },
              ),
            ],
          ),
          body: ListView.builder(
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              final cartQty = cartProvider.getQuantity(product.id);
              final totalForItem = product.price * cartQty;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (product.hasImageUrl)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cake, color: Colors.grey),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Цена: ${product.price.toStringAsFixed(2)} ₽ '
                            '× $cartQty шт = '
                            'Сумма: ${totalForItem.toStringAsFixed(2)} ₽',
                            style: TextStyle(
                                color: totalForItem != 0
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                                fontWeight: totalForItem == 0
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Кратность: ${product.multiplicity} шт',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (cartQty > 0)
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.red),
                            onPressed: () {
                              cartProvider.setQuantity(
                                product.id,
                                cartQty - product.multiplicity,
                                product.multiplicity,
                                _products,
                              );
                            },
                          ),
                        Text('$cartQty',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () {
                            cartProvider.setQuantity(
                              product.id,
                              cartQty + product.multiplicity,
                              product.multiplicity,
                              _products,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<OrderItem> _getCurrentOrders() {
    return [];
  }
}
