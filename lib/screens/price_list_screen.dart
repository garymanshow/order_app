// lib/screens/price_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/price_list_mode.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../services/sheet_all_api_service.dart';

class PriceListScreen extends StatefulWidget {
  final Client client;

  const PriceListScreen({Key? key, required this.client}) : super(key: key);

  @override
  _PriceListScreenState createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  late Future<List<Product>> _productsFuture;
  late PriceListMode _currentMode;
  late String _modeLabel;

  @override
  void initState() {
    super.initState();
    // 1. Загружаем сохранённый режим
    _currentMode = _loadSavedMode(widget.client.phone);
    _modeLabel = _currentMode.label;

    // 2. Загружаем товары
    _productsFuture = _loadProductsByMode(_currentMode);

    // 3. Загружаем заказы и инициализируем корзину
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrdersForClient(widget.client);
    });
  }

  // Сохраняет и загружает режим из кэша (в реальности — из SharedPreferences)
  PriceListMode _loadSavedMode(String phone) {
    // В реальном приложении: 
    // final prefs = await SharedPreferences.getInstance();
    // final modeStr = prefs.getString('price_mode_$phone') ?? 'full';
    // return PriceListModeExtension.fromString(modeStr);
    return PriceListMode.full; // временно
  }

  void _saveMode(String phone, PriceListMode mode) {
    // В реальном приложении:
    // final prefs = await SharedPreferences.getInstance();
    // prefs.setString('price_mode_$phone', mode.name);
  }

  Future<List<Product>> _loadProductsByMode(PriceListMode mode) async {
    final service = SheetAllApiService();
    List<dynamic> rawData = [];

    switch (mode) {
      case PriceListMode.full:
        rawData = await service.read(sheetName: 'Прайс-лист');
        break;
      case PriceListMode.byCategory:
        // Загружаем категории и фильтруем товары
        final categories = await service.read(sheetName: 'Категория прайса');
        // Пример: фильтрация по ID категорий (можно расширить)
        rawData = await service.read(
          sheetName: 'Прайс-лист',
          filters: {'Категория': '1'}, // пример фильтра
        );
        break;
      case PriceListMode.contractOnly:
        rawData = await service.read(
          sheetName: 'Прайс-лист',
          filters: {'Договорные': 'да'}, // условный столбец
        );
        break;
    }

    // Преобразуем rawData в List<Product>
    return rawData.map((item) {
      final row = item as Map<String, dynamic>;
      return Product(
        id: row['ID']?.toString() ?? '',
        name: row['Наименование']?.toString() ?? '',
        price: double.tryParse(row['Цена закупа']?.toString() ?? '0') ?? 0.0,
        // ... остальные поля
        categoryName: row['Категория']?.toString() ?? '',
      );
    }).toList();
  }

  Future<void> _loadOrdersForClient(Client client) async {
    final service = SheetAllApiService();
    final orders = await service.read(
      sheetName: 'Заказы',
      filters: {
        'Телефон': client.phone,
        'Статус': 'заказ',
      },
    );

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
    final products = productsProvider.products;

    cartProvider.clearAll();
    for (var order in orders) {
      final product = products.firstWhere(
        (p) => p.name == (order as Map)['Наименование'],
        orElse: () => null,
      );
      if (product != null) {
        cartProvider.setTemporaryQuantity(product.id, (order['Количество'] as int?) ?? 0);
      }
    }
  }

  void _changeMode(PriceListMode newMode) {
    setState(() {
      _currentMode = newMode;
      _modeLabel = newMode.label;
      _productsFuture = _loadProductsByMode(newMode);
    });
    _saveMode(widget.client.phone, newMode);
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Прайс-лист';
    if (widget.client.name.isNotEmpty) {
      title = 'Заказ для: ${widget.client.name}';
      if (widget.client.address.isNotEmpty) {
        title += ' — ${widget.client.address}';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16)),
            TextButton(
              onPressed: () => _showModeSelection(context),
              child: Text(
                'Режим: $_modeLabel',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final products = snapshot.data!;
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(products[index].name),
                subtitle: Text('${products[index].price} ₽'),
                trailing: Icon(Icons.add),
                onTap: () {
                  // Добавление в корзину
                },
              );
            },
          );
        },
      ),
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