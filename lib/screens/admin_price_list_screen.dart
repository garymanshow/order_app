// lib/screens/admin_price_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/google_sheets_service.dart';
import '../models/price_item.dart';
import 'admin_price_item_form_screen.dart';

class AdminPriceListScreen extends StatefulWidget {
  @override
  _AdminPriceListScreenState createState() => _AdminPriceListScreenState();
}

class _AdminPriceListScreenState extends State<AdminPriceListScreen> {
  List<PriceItem> _priceItems = [];
  bool _isLoading = false;
  final GoogleSheetsService _service =
      GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);

  @override
  void initState() {
    super.initState();
    _loadPriceList();
  }

  Future<void> _loadPriceList() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _service.init();
      final data = await _service.read(sheetName: 'Прайс-лист');
      final items = data.map((row) => PriceItem.fromMap(row)).toList();
      setState(() {
        _priceItems = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🔥 Обновление конкретной позиции в списке
  void _updateItemInList(PriceItem updatedItem) {
    setState(() {
      final index = _priceItems.indexWhere((item) => item.id == updatedItem.id);
      if (index != -1) {
        _priceItems[index] = updatedItem;
      }
    });
  }

  Future<void> _deleteItem(PriceItem item) async {
    await _service.delete(
      sheetName: 'Прайс-лист',
      filters: [
        {'column': 'ID', 'value': item.id}
      ],
    );
    _loadPriceList(); // Удаление требует перезагрузки
  }

  void _showDeleteConfirmation(PriceItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить позицию?'),
        content: Text('Вы уверены, что хотите удалить "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Прайс-лист'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminPriceItemFormScreen()),
              );
              if (result == true || result is PriceItem) {
                _loadPriceList(); // Новая позиция - перезагрузка
              }
            },
            tooltip: 'Добавить позицию',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _priceItems.isEmpty
              ? Center(child: Text('Прайс-лист пуст'))
              : ListView.builder(
                  itemCount: _priceItems.length,
                  itemBuilder: (context, index) {
                    final item = _priceItems[index];
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ListTile(
                        leading: item.photoUrl != null
                            ? Image.network(
                                item.photoUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.image, size: 32),
                              )
                            : Icon(Icons.cake, size: 32),
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.price.toStringAsFixed(2)} ₽ | Кратность: ${item.multiplicity}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminPriceItemFormScreen(item: item),
                                  ),
                                );

                                // 🔥 Частичное обновление
                                if (result is PriceItem) {
                                  _updateItemInList(result);
                                } else if (result == true) {
                                  _loadPriceList(); // На всякий случай
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmation(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
