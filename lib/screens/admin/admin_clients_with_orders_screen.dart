// lib/screens/admin/admin_clients_with_orders_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb; // Для проверки платформы
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:charset_converter/charset_converter.dart'; // Для мобильных
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/order_item.dart';
import '../../models/status_update.dart';
import 'admin_order_analytics_screen.dart';
import 'admin_client_orders_screen.dart';
import 'admin_exclude_positions_screen.dart';
import 'admin_orders_calendar_screen.dart';

class AdminClientsWithOrdersScreen extends StatefulWidget {
  const AdminClientsWithOrdersScreen({super.key});

  @override
  State<AdminClientsWithOrdersScreen> createState() =>
      _AdminClientsWithOrdersScreenState();
}

class _AdminClientsWithOrdersScreenState
    extends State<AdminClientsWithOrdersScreen> {
  final ApiService _apiService = ApiService();

  String _selectedStatus = 'all';
  List<OrderItem> _filteredOrders = [];
  Map<String, List<OrderItem>> _groupedOrders = {};
  double _totalAmount = 0.0;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFilter();
  }

  Future<void> _loadSavedFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFilter = prefs.getString('admin_orders_filter') ?? 'all';
    setState(() {
      _selectedStatus = savedFilter;
    });
    _loadOrders();
  }

  Future<void> _saveFilter(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_orders_filter', filter);
  }

  bool get _canExport {
    return _selectedStatus == 'доставлен';
  }

  List<OrderItem> _getExportableOrders() {
    return _filteredOrders
        .where((order) =>
            order.status == 'доставлен' && order.paymentDocument.isEmpty)
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOrders();
  }

  void _loadOrders() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allOrders = authProvider.clientData?.orders ?? [];

    if (_selectedStatus == 'all') {
      _filteredOrders = List.from(allOrders);
    } else {
      _filteredOrders =
          allOrders.where((order) => order.status == _selectedStatus).toList();
    }

    _groupedOrders = {};
    for (var order in _filteredOrders) {
      final key = '${order.clientPhone}-${order.clientName}';
      if (!_groupedOrders.containsKey(key)) {
        _groupedOrders[key] = [];
      }
      _groupedOrders[key]!.add(order);
    }

    _totalAmount =
        _filteredOrders.fold(0.0, (sum, order) => sum + order.totalPrice);

    setState(() {});
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'оформлен':
        return Colors.blue;
      case 'производство':
        return Colors.orange;
      case 'готов':
        return Colors.purple;
      case 'доставлен':
        return Colors.green;
      case 'оплачен':
        return Colors.yellow[700]!;
      case 'запас':
        return Colors.brown;
      case 'в работе':
        return Colors.teal;
      case 'изготовление':
        return Colors.indigo;
      case 'отменен':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'all':
        return 'Все';
      case 'оформлен':
        return 'Оформлен';
      case 'производство':
        return 'Производство';
      case 'готов':
        return 'Готов';
      case 'доставлен':
        return 'Доставлен';
      case 'оплачен':
        return 'Оплачен';
      case 'запас':
        return 'Запас';
      case 'в работе':
        return 'В работе';
      case 'изготовление':
        return 'Изготовление';
      case 'отменен':
        return 'Отменен';
      default:
        return status;
    }
  }

  // ==========================================
  // НОВЫЕ МЕТОДЫ ОБНОВЛЕНИЯ СТАТУСОВ
  // ==========================================

  // 1. МАССОВОЕ ОБНОВЛЕНИЕ (Глобальная смена по текущему фильтру)
  Future<void> _updateAllFilteredStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      // Используем существующий метод API, передавая старый статус как orderId
      final success = await _apiService.updateOrderStatus(
        orderId: _selectedStatus,
        newStatus: newStatus,
      );

      if (success) {
        await _applyStatusChangesLocally(
          oldStatus: _selectedStatus,
          newStatus: newStatus,
          targetPhone: null,
        );
        _showSnackBar('Все заказы переведены в "${_getStatusText(newStatus)}"',
            Colors.green);
      } else {
        throw Exception('Ошибка на сервере');
      }
    } catch (e) {
      print('❌ Ошибка массового обновления: $e');
      _showSnackBar('Ошибка обновления: $e', Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // 2. ОБНОВЛЕНИЕ СТАТУСА КОНКРЕТНОГО КЛИЕНТА
  Future<void> _updateClientStatus(String clientKey, String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final parts = clientKey.split('-');
      if (parts.length < 2) return;

      final phone = parts[0];
      final name =
          parts.sublist(1).join('-'); // На случай, если в имени есть дефисы

      final updatePayload = StatusUpdate(
        client: name,
        phone: phone,
        oldStatus: _selectedStatus,
        newStatus: newStatus,
      );

      final success = await _apiService.updateOrderStatuses([updatePayload]);

      if (success) {
        await _applyStatusChangesLocally(
          oldStatus: _selectedStatus,
          newStatus: newStatus,
          targetPhone: phone,
        );
        _showSnackBar(
            'Статус изменен на "${_getStatusText(newStatus)}"', Colors.green);
      } else {
        throw Exception('Не удалось обновить статусы на сервере');
      }
    } catch (e) {
      print('❌ Ошибка обновления статусов клиента: $e');
      _showSnackBar('Ошибка обновления статусов: $e', Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // 3. ЛОКАЛЬНОЕ ОБНОВЛЕНИЕ БЕЗ ПОВТОРНОЙ ЗАГРУЗКИ ВСЕХ ДАННЫХ
  Future<void> _applyStatusChangesLocally({
    required String oldStatus,
    required String newStatus,
    String? targetPhone,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    for (int i = 0; i < authProvider.clientData!.orders.length; i++) {
      final order = authProvider.clientData!.orders[i];

      if (order.status == oldStatus) {
        if (targetPhone == null || order.clientPhone == targetPhone) {
          authProvider.clientData!.orders[i] =
              order.copyWith(status: newStatus);
        }
      }
    }

    authProvider.clientData!.buildIndexes();
    await _saveToPrefs(authProvider);

    setState(() {
      _selectedStatus = newStatus;
    });
    _saveFilter(newStatus);
    _loadOrders();
  }

  // ==========================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ==========================================

  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ДИАЛОГ ПОДТВЕРЖДЕНИЯ ОТМЕНЫ
  Future<void> _showCancelConfirmation(String clientKey) async {
    final parts = clientKey.split('-');
    final clientName =
        parts.length >= 2 ? parts.sublist(1).join('-') : 'клиента';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Отменить заказы?'),
          content: Text(
              'Вы уверены, что хотите отменить все текущие заказы для $clientName?\n\nЭто действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет, оставить'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Да, отменить'),
            ),
          ],
        );
      },
    );

    // Если пользователь подтвердил
    if (confirm == true) {
      _updateClientStatus(clientKey, 'отменен');
    }
  }

  Future<void> _exportOrdersToCsv() async {
    final orders = _getExportableOrders();

    if (orders.isEmpty) {
      _showSnackBar('Нет неоплаченных заказов для экспорта', Colors.orange);
      return;
    }

    try {
      // Запрашиваем разрешение только на Android
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showSnackBar('Нужно разрешение на запись файлов', Colors.orange);
          return;
        }
      }

      final csvContent = _generateCsvContent(orders);

      if (kIsWeb) {
        // ИСПРАВЛЕНО: На Web используем встроенный Blob с указанием кодировки
        final bytes = utf8.encode(csvContent);
        final blob = html.Blob([bytes], 'text/csv;charset=windows-1251');
        final url = html.Url.createObjectUrlFromBlob(blob);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'unpaid_orders_$timestamp.csv';

        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();

        Future.delayed(const Duration(seconds: 2), () {
          html.Url.revokeObjectUrl(url);
          anchor.remove();
        });

        _showSnackBar('Файл $fileName готов к скачиванию', Colors.green);
      } else {
        // Мобильные устройства: используем нативный конвертер
        final cp1251Bytes = await CharsetConverter.encode('cp1251', csvContent);

        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/unpaid_orders_$timestamp.csv';

        final file = File(filePath);
        await file.writeAsBytes(cp1251Bytes);

        _showSnackBar('Экспорт сохранен: $filePath', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Ошибка экспорта: $e', Colors.red);
    }
  }

  String _generateCsvContent(List<OrderItem> orders) {
    final headers = [
      'Статус',
      'Название',
      'Количество',
      'Итоговая цена',
      'Дата',
      'Телефон',
      'Клиент'
    ];

    final csvLines = <String>[];
    csvLines.add(headers.join(';'));

    for (var order in orders) {
      final row = [
        _escapeCsvField(_getStatusText(order.status)),
        _escapeCsvField(order.productName),
        order.quantity.toString(),
        order.totalPrice.toStringAsFixed(2),
        _escapeCsvField(order.date),
        _escapeCsvField(order.clientPhone),
        _escapeCsvField(order.clientName),
      ];
      csvLines.add(row.join(';'));
    }

    return csvLines.join('\r\n');
  }

  String _escapeCsvField(String field) {
    if (field.contains(';') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  void _navigateToClientOrders(String clientKey) {
    final parts = clientKey.split('-');
    if (parts.length >= 2) {
      final phone = parts[0];
      final name = parts.sublist(1).join('-');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminClientOrdersScreen(
            phone: phone,
            clientName: name,
          ),
        ),
      );
    }
  }

  // Динамическое построение меню массового обновления на основе модели OrderItem
  List<PopupMenuEntry<String>> _buildStatusChangeMenuItems() {
    final OrderItem? firstOrder =
        _filteredOrders.isNotEmpty ? _filteredOrders.first : null;
    final availableStatuses =
        firstOrder?.getAvailableStatuses(userRole: 'owner') ?? <String>[];

    if (availableStatuses.isEmpty) {
      return [
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('Нет доступных переходов',
              style: TextStyle(color: Colors.grey)),
        )
      ];
    }

    return availableStatuses.map((status) {
      return PopupMenuItem<String>(
        value: status,
        child: Row(
          children: [
            Icon(Icons.circle, color: _getStatusColor(status), size: 12),
            const SizedBox(width: 8),
            Text(
              _getStatusText(status),
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказы: Итого ${_totalAmount.toStringAsFixed(2)}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canExport)
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _isUpdating ? null : _exportOrdersToCsv,
              tooltip: 'Экспорт в CSV',
            ),
        ],
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ПАНЕЛЬ УПРАВЛЕНИЯ (ФИЛЬТРЫ И КНОПКИ)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      // 1. ВЫПАДАЮЩИЙ СПИСОК ФИЛЬТРОВ
                      PopupMenuButton<String>(
                        icon: Icon(Icons.filter_alt,
                            color: Colors.grey[700], size: 20),
                        tooltip: 'Фильтр по статусу',
                        onSelected: (value) {
                          setState(() => _selectedStatus = value);
                          _saveFilter(value);
                          _loadOrders();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuDivider(),
                          const CheckedPopupMenuItem(
                              value: 'all',
                              checked: false,
                              child: Text('👁️ Все заказы')),
                          const PopupMenuDivider(),
                          const CheckedPopupMenuItem(
                              value: 'оформлен',
                              checked: false,
                              child: Text('🟦 Оформлен')),
                          const CheckedPopupMenuItem(
                              value: 'производство',
                              checked: false,
                              child: Text('🟧 Производство')),
                          const CheckedPopupMenuItem(
                              value: 'готов',
                              checked: false,
                              child: Text('🟪 Готов')),
                          const CheckedPopupMenuItem(
                              value: 'доставлен',
                              checked: false,
                              child: Text('🟩 Доставлен')),
                          const CheckedPopupMenuItem(
                              value: 'оплачен',
                              checked: false,
                              child: Text('🟨 Оплачен')),
                          const PopupMenuDivider(),
                          const CheckedPopupMenuItem(
                              value: 'запас',
                              checked: false,
                              child: Text('📦 Запас')),
                          const CheckedPopupMenuItem(
                              value: 'в работе',
                              checked: false,
                              child: Text('⚙️ В работе')),
                          const CheckedPopupMenuItem(
                              value: 'изготовление',
                              checked: false,
                              child: Text('🛠️ Изготовление')),
                          const PopupMenuDivider(),
                          const CheckedPopupMenuItem(
                              value: 'отменен',
                              checked: false,
                              child: Text('❌ Отменен')),
                        ],
                      ),

                      // Текущий фильтр текстом
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          _getStatusText(_selectedStatus),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // 2. КНОПКА МАССОВОГО ИЗМЕНЕНИЯ СТАТУСА
                      if (_filteredOrders.isNotEmpty)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.sync_alt,
                              color: Colors.grey[700], size: 20),
                          tooltip: 'Изменить статус всех',
                          onSelected: (value) =>
                              _updateAllFilteredStatus(value),
                          itemBuilder: (context) =>
                              _buildStatusChangeMenuItems(),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.sync_alt,
                              color: Colors.grey[300], size: 20),
                          onPressed: null,
                          tooltip: 'Нет заказов',
                        ),

                      // КНОПКА ИСКЛЮЧЕНИЯ ПОЗИЦИЙ (Только для фильтра "Оформлен")
                      if (_selectedStatus == 'оформлен' &&
                          _filteredOrders.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: Colors.red[700], size: 20),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminExcludePositionsScreen()),
                            );
                            // Если экран вернул true (позиции удалены), обновляем список на текущем экране
                            if (result == true) {
                              _loadOrders();
                            }
                          },
                          tooltip: 'Исключить позиции из всех заказов',
                        ),

                      // 3. КНОПКА АНАЛИТИКИ
                      IconButton(
                        icon: Icon(Icons.analytics,
                            color: Colors.grey[700], size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminAnalyticsScreen()),
                          );
                        },
                        tooltip: 'Аналитика',
                      ),

                      // 4. КНОПКА КАЛЕНДАРЯ
                      IconButton(
                        icon: Icon(Icons.calendar_today,
                            color: Colors.grey[700], size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AdminOrdersCalendarScreen()),
                          );
                        },
                        tooltip: 'Календарь заказов',
                      ),
                    ],
                  ),
                ),

                // СПИСОК КЛИЕНТОВ
                Expanded(
                  child: _groupedOrders.isEmpty
                      ? const Center(child: Text('Нет заказов'))
                      : ListView.builder(
                          itemCount: _groupedOrders.keys.length,
                          itemBuilder: (context, index) {
                            final clientKey =
                                _groupedOrders.keys.elementAt(index);
                            final orders = _groupedOrders[clientKey]!;

                            double clientTotal = 0;
                            for (var order in orders) {
                              clientTotal += order.totalPrice;
                            }

                            // Связь с моделью: какие кнопки показывать для этого клиента
                            final availableCardStatuses = orders.first
                                .getAvailableStatuses(userRole: 'owner');

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      // Одиночный клик для перехода
                                      onTap: () =>
                                          _navigateToClientOrders(clientKey),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              orders.first.clientName ?? '',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${clientTotal.toStringAsFixed(2)} ₽',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              '${orders.length} позиций',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Блок кнопок действий с клиентом
                                  if (availableCardStatuses.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                              color: Colors.grey[300]!),
                                        ),
                                      ),
                                      // Используем Column, чтобы разместить кнопки друг под другом
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Кнопка движения ВПЕРЕД
                                          TextButton(
                                            onPressed: () =>
                                                _updateClientStatus(
                                                    clientKey,
                                                    availableCardStatuses
                                                        .first),
                                            child: Text(
                                              'в ${_getStatusText(availableCardStatuses.first)}',
                                              style: TextStyle(
                                                color: _getStatusColor(
                                                    availableCardStatuses
                                                        .first),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),

                                          // Кнопка ОТМЕНЫ (если она доступна в списке)
                                          if (availableCardStatuses
                                              .contains('отменен'))
                                            TextButton(
                                              onPressed: () =>
                                                  _showCancelConfirmation(
                                                      clientKey),
                                              child: const Text(
                                                'Отменить',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
