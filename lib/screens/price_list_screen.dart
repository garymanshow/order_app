// lib/screens/price_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/price_list_mode.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';

class PriceListScreen extends StatefulWidget {
  final Client client;

  const PriceListScreen({Key? key, required this.client}) : super(key: key);

  @override
  _PriceListScreenState createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  late PriceListMode _currentMode;
  late String _modeLabel;

  @override
  void initState() {
    super.initState();
    _currentMode = _loadSavedMode(widget.client.phone);
    _modeLabel = _currentMode.label;
    // ❌ УДАЛЕНО: cartProvider.initialize(...) — это делает ClientSelectionScreen
  }

  PriceListMode _loadSavedMode(String phone) {
    return PriceListMode.full;
  }

  void _saveMode(String phone, PriceListMode mode) {}

  void _changeMode(PriceListMode newMode) {
    setState(() {
      _currentMode = newMode;
      _modeLabel = newMode.label;
    });
    _saveMode(widget.client.phone, newMode);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProductsProvider, CartProvider>(
      builder: (context, productsProvider, cartProvider, child) {
        final client = widget.client;

        // Показываем загрузку
        if (productsProvider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: Text('Загрузка прайса...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Показываем ошибку
        if (productsProvider.error != null) {
          return Scaffold(
            appBar: AppBar(title: Text('Ошибка')),
            body: Center(child: Text(productsProvider.error!)),
          );
        }

        // Если продуктов нет — показываем пустой список
        final products = productsProvider.products;
        if (products.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('Прайс-лист пуст')),
            body: const Center(child: Text('Нет товаров для отображения')),
          );
        }

        final discount = (client.discount ?? 0) / 100.0;
        final total = cartProvider.getTotal(products, discount);

        String title = 'Заказ для: ${client.name}';
        if (client.address.isNotEmpty) {
          title += ' — ${client.address}';
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
                TextButton(
                  onPressed: () => _showModeSelection(context),
                  child: Text(
                    'Режим: $_modeLabel',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.pushNamed(context, '/cart');
                },
              ),
            ],
          ),
          body: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final cartQty = cartProvider.getTemporaryQuantity(product.id);
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
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
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
                                products,
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
                              products,
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

  void _showModeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: PriceListMode.values.map((mode) {
            return ListTile(
              title: Text(mode.label),
              selected: mode == _currentMode,
              onTap: () {
                Navigator.pop(context);
                _changeMode(mode);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
