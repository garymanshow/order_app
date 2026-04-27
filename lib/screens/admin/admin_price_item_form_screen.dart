// lib/screens/admin/admin_price_item_form_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/auth_provider.dart';
import '../../models/product.dart';
import '../../models/price_item.dart';
import '../../models/price_category.dart';
import '../../models/composition.dart';
import '../../models/storage_condition.dart';
import '../../models/transport_condition.dart';
import '../../services/api_service.dart';
import '../../services/unit_service.dart';
import '../../widgets/unit_selector.dart';

class _ListButtonConfig {
  final String title;
  final IconData icon;
  final String sheetName;
  final String levelCategory;
  final String levelProduct;
  final bool showQuantity;
  final bool showUnit;
  final bool isStorage;
  final bool isTransport;

  const _ListButtonConfig({
    required this.title,
    required this.icon,
    required this.sheetName,
    required this.levelCategory,
    required this.levelProduct,
    this.showQuantity = false,
    this.showUnit = false,
    this.isStorage = false,
    this.isTransport = false,
  });
}

class ProductFormData {
  final String productId;
  String name;
  double price;
  int multiplicity;
  String photoUrl;
  Uint8List? imageBytes;
  String description;
  String categoryId;
  String categoryName;
  String unit;
  String weight;
  String packagingName;
  int wastePercentage;

  Map<String, List<Composition>> ownData = {};
  List<Composition> baseFillings = [];
  List<Composition> baseCompositions = [];

  Map<String, List<Composition>> baseFillingCompositionsMap = {};
  Map<String, List<Composition>> ownFillingCompositionsMap = {};

  List<StorageCondition> baseStorage = [];
  List<StorageCondition> ownStorage = [];
  List<TransportCondition> baseTransport = [];
  List<TransportCondition> ownTransport = [];

  ProductFormData({
    required this.productId,
    this.name = '',
    this.price = 0.0,
    this.multiplicity = 1,
    this.photoUrl = '',
    this.imageBytes,
    this.description = '',
    this.categoryId = '',
    this.categoryName = '',
    this.unit = 'г',
    this.weight = '0',
    this.packagingName = 'Транспортный контейнер',
    this.wastePercentage = 10,
  });
}

class PendingChange {
  final String sheetName;
  final String entityId;
  final String level;
  final List<Map<String, dynamic>> items;

  PendingChange({
    required this.sheetName,
    required this.entityId,
    required this.level,
    required this.items,
  });
}

class AdminPriceItemFormScreen extends StatefulWidget {
  final PriceItem? item;
  final String? initialCategoryId;
  final String? initialCategoryName;

  const AdminPriceItemFormScreen({
    super.key,
    this.item,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  @override
  AdminPriceItemFormScreenState createState() =>
      AdminPriceItemFormScreenState();
}

class AdminPriceItemFormScreenState extends State<AdminPriceItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  static const _kTransportConfig = _ListButtonConfig(
    title: 'Условия транспортировки',
    icon: Icons.local_shipping,
    sheetName: 'Условия транспортировки',
    levelCategory: 'Категории прайса',
    levelProduct: 'Прайс-лист',
    isTransport: true,
  );
  static const _kStorageConfig = _ListButtonConfig(
    title: 'Условия хранения',
    icon: Icons.inventory_2,
    sheetName: 'Условия хранения',
    levelCategory: 'Категории прайса',
    levelProduct: 'Прайс-лист',
    isStorage: true,
  );
  static const _kFillingConfig = _ListButtonConfig(
    title: 'Начинки',
    icon: Icons.cake,
    sheetName: 'Начинки',
    levelCategory: 'Категории прайса',
    levelProduct: 'Прайс-лист',
    showQuantity: true,
    showUnit: true,
  );
  static const _kCompositionConfig = _ListButtonConfig(
    title: 'Состав',
    icon: Icons.restaurant_menu,
    sheetName: 'Состав',
    levelCategory: 'Категории прайса',
    levelProduct: 'Прайс-лист',
    showQuantity: true,
    showUnit: true,
  );

  List<PriceCategory> _categories = [];
  List<Product> _allProducts = [];
  late PageController _pageController;
  int _currentIndex = 0;

  final Map<String, ProductFormData> _formDataMap = {};
  bool _isSaving = false;
  bool _hasLocalChanges = false;
  final List<PendingChange> _pendingChanges = [];

  int _ownCompositionsCount = 0;
  int _baseCompositionsCount = 0;
  int _ownFillingsCount = 0;
  int _baseFillingsCount = 0;
  int _ownStorageCount = 0;
  int _baseStorageCount = 0;
  int _ownTransportCount = 0;
  int _baseTransportCount = 0;

  ProductFormData get _currentData {
    if (_currentIndex < 0 || _currentIndex >= _allProducts.length)
      return ProductFormData(productId: '');
    final id = _allProducts[_currentIndex].id;
    return _formDataMap.putIfAbsent(id, () => ProductFormData(productId: id));
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadInitialData().then((_) => _initPageIndex());
  }

  void _initPageIndex() {
    if (_allProducts.isEmpty) return;
    final idToFind = widget.item?.id;
    if (idToFind != null && idToFind.isNotEmpty) {
      final index = _allProducts.indexWhere((p) => p.id == idToFind);
      if (index != -1) _currentIndex = index;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients &&
          _pageController.initialPage != _currentIndex) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
    _loadDataForIndex(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData;
    if (clientData == null) return;
    setState(() {
      _categories = clientData.priceCategories;
      _allProducts = clientData.products;
    });
  }

  void _loadDataForIndex(int index) {
    if (index < 0 || index >= _allProducts.length) return;
    final product = _allProducts[index];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData;

    if (!_formDataMap.containsKey(product.id)) {
      PriceCategory? productCategory;
      if (product.categoryId.isNotEmpty) {
        try {
          productCategory = _categories
              .firstWhere((c) => c.id.toString() == product.categoryId);
        } catch (_) {}
      }

      final data = ProductFormData(
        productId: product.id,
        name: product.name,
        price: product.price,
        multiplicity:
            productCategory?.packagingQuantity ?? product.multiplicity,
        photoUrl: product.imageUrl ?? '',
        description: product.composition ?? '',
        categoryId: productCategory?.id.toString() ?? product.categoryId,
        categoryName: productCategory?.name ?? product.categoryName,
        unit: productCategory?.unit ?? 'г',
        weight: productCategory?.weight.toString() ?? product.weight,
        wastePercentage:
            productCategory?.wastePercentage ?? product.wastePercentage,
      );

      final String productIdStr = product.id.toString();
      final String catIdStr = productCategory?.id.toString() ?? '';

      if (clientData != null) {
        // 1. НАЧИНКИ КАТЕГОРИИ
        data.baseFillings = catIdStr.isNotEmpty
            ? clientData.compositions
                .where((c) =>
                    c.sheetName == 'Категории прайса' &&
                    c.entityId.toString() == catIdStr)
                .toList()
            : [];

        // 1.5 ВЛОЖЕННЫЙ СОСТАВ ДЛЯ КАЖДОЙ НАЧИНКИ КАТЕГОРИИ
        // Проходимся по найденным начинкам и для каждой вытаскиваем её состав
        for (var filling in data.baseFillings) {
          String fillingIdStr = filling.id.toString();
          data.baseFillingCompositionsMap[fillingIdStr] = clientData
              .compositions
              .where((c) =>
                  c.sheetName == 'Начинки' &&
                  c.entityId.toString() == fillingIdStr)
              .toList();
        }

        // 2. Начинки для конкретного товара
        data.ownData[_kFillingConfig.sheetName] = clientData.compositions
            .where((c) =>
                c.sheetName == 'Прайс-лист' &&
                c.entityId.toString() == productIdStr)
            .toList();

        // 2.5 ВЛОЖЕННЫЙ СОСТАВ ДЛЯ СОБСТВЕННЫХ НАЧИНОК ТОВАРА
        for (var filling in data.ownData[_kFillingConfig.sheetName] ?? []) {
          String fillingIdStr = filling.id.toString();
          data.ownFillingCompositionsMap[fillingIdStr] = clientData.compositions
              .where((c) =>
                  c.sheetName == 'Начинки' &&
                  c.entityId.toString() == fillingIdStr)
              .toList();
        }

        // 3. СОСТАВ ТОВАРА (Прямой состав, привязанный к товару)
        data.ownData[_kCompositionConfig.sheetName] = clientData.compositions
            .where((c) =>
                c.sheetName == 'Прайс-лист' &&
                c.entityId.toString() == productIdStr)
            .toList();

        // 4. Хранение и Транспорт
        data.ownStorage = clientData.storageConditions
            .where((c) =>
                c.entityId.toString() == productIdStr &&
                c.level == _kStorageConfig.levelProduct)
            .toList();
        data.baseStorage = catIdStr.isNotEmpty
            ? clientData.storageConditions
                .where((c) =>
                    c.entityId.toString() == catIdStr &&
                    c.level == _kStorageConfig.levelCategory)
                .toList()
            : [];
        data.ownTransport = clientData.transportConditions
            .where((c) =>
                c.entityId.toString() == productIdStr &&
                c.level == _kTransportConfig.levelProduct)
            .toList();
        data.baseTransport = catIdStr.isNotEmpty
            ? clientData.transportConditions
                .where((c) =>
                    c.entityId.toString() == catIdStr &&
                    c.level == _kTransportConfig.levelCategory)
                .toList()
            : [];
      }
      _formDataMap[product.id] = data;
    }
    _refreshTails();
    setState(() => _hasLocalChanges = false);
  }

  void _refreshTails() {
    final data = _currentData;
    _ownCompositionsCount =
        (data.ownData[_kCompositionConfig.sheetName] ?? []).length;
    _baseCompositionsCount = data.baseCompositions.length;
    _ownFillingsCount = (data.ownData[_kFillingConfig.sheetName] ?? []).length;
    _baseFillingsCount = data.baseFillings.length;
    _ownStorageCount = data.ownStorage.length;
    _baseStorageCount = data.baseStorage.length;
    _ownTransportCount = data.ownTransport.length;
    _baseTransportCount = data.baseTransport.length;
  }

  void _saveItemLocally() {
    if (!_formKey.currentState!.validate()) return;
    final data = _currentData;
    final product = _allProducts[_currentIndex];

    final updatedProduct = Product(
      id: data.productId,
      name: data.name,
      price: data.price,
      multiplicity: data.multiplicity,
      categoryId: data.categoryId.isNotEmpty ? data.categoryId : 'default',
      imageUrl: data.photoUrl,
      composition: data.description,
      weight: data.weight,
      nutrition: '',
      storage: '',
      packaging: '',
      categoryName: data.categoryName,
      wastePercentage: data.wastePercentage,
      displayName: data.name,
    );
    final pIndex = _allProducts.indexWhere((p) => p.id == product.id);
    if (pIndex != -1) _allProducts[pIndex] = updatedProduct;

    for (var config in [_kCompositionConfig, _kFillingConfig]) {
      _pendingChanges.add(PendingChange(
          sheetName: config.sheetName,
          entityId: product.id,
          level: config.levelProduct,
          items: (data.ownData[config.sheetName] ?? [])
              .map((c) => c.toJson())
              .toList()));
      if (data.categoryId.isNotEmpty) {
        _pendingChanges.add(PendingChange(
            sheetName: config.sheetName,
            entityId: data.categoryId,
            level: config.levelCategory,
            items: (config.sheetName == _kFillingConfig
                    ? data.baseFillings
                    : data.baseCompositions)
                .map((c) => c.toJson())
                .toList()));
      }
    }

    // ДОБАВЛЯЕМ ВЛОЖЕННЫЕ СОСТАВЫ НАЧИНОК В ОЧЕРЕДЬ НА СОХРАНЕНИЕ
    final allFillingComps = {
      ...data.baseFillingCompositionsMap,
      ...data.ownFillingCompositionsMap
    };
    for (var entry in allFillingComps.entries) {
      _pendingChanges.add(PendingChange(
          sheetName: 'Состав',
          entityId: entry.key,
          level: 'Начинки',
          items: entry.value.map((c) => c.toJson()).toList()));
    }

    _pendingChanges.add(PendingChange(
        sheetName: _kStorageConfig.sheetName,
        entityId: product.id,
        level: _kStorageConfig.levelProduct,
        items: data.ownStorage.map((c) => c.toJson()).toList()));
    if (data.categoryId.isNotEmpty)
      _pendingChanges.add(PendingChange(
          sheetName: _kStorageConfig.sheetName,
          entityId: data.categoryId,
          level: _kStorageConfig.levelCategory,
          items: data.baseStorage.map((c) => c.toJson()).toList()));
    _pendingChanges.add(PendingChange(
        sheetName: _kTransportConfig.sheetName,
        entityId: product.id,
        level: _kTransportConfig.levelProduct,
        items: data.ownTransport.map((c) => c.toJson()).toList()));
    if (data.categoryId.isNotEmpty)
      _pendingChanges.add(PendingChange(
          sheetName: _kTransportConfig.sheetName,
          entityId: data.categoryId,
          level: _kTransportConfig.levelCategory,
          items: data.baseTransport.map((c) => c.toJson()).toList()));

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData!;

    for (var config in [_kCompositionConfig, _kFillingConfig]) {
      clientData.compositions.removeWhere((c) =>
          c.sheetName == config.sheetName &&
          c.entityId.toString() == product.id.toString() &&
          c.level == config.levelProduct);
      clientData.compositions.addAll(data.ownData[config.sheetName] ?? []);
      if (data.categoryId.isNotEmpty) {
        clientData.compositions.removeWhere((c) =>
            c.sheetName == config.sheetName &&
            c.entityId.toString() == data.categoryId &&
            c.level == config.levelCategory);
        clientData.compositions.addAll(config.sheetName == _kFillingConfig
            ? data.baseFillings
            : data.baseCompositions);
      }
    }

    // ОБНОВЛЯЕМ СОСТАВЫ НАЧИНОК В ГЛОБАЛЬНОМ КЭШЕ
    for (var entry in allFillingComps.entries) {
      clientData.compositions.removeWhere((c) =>
          c.sheetName == 'Состав' &&
          c.entityId.toString() == entry.key &&
          c.level == 'Начинки');
      clientData.compositions.addAll(entry.value);
    }

    clientData.storageConditions.removeWhere((c) =>
        c.entityId.toString() == product.id.toString() &&
        c.level == _kStorageConfig.levelProduct);
    clientData.storageConditions.addAll(data.ownStorage);
    if (data.categoryId.isNotEmpty) {
      clientData.storageConditions.removeWhere((c) =>
          c.entityId.toString() == data.categoryId &&
          c.level == _kStorageConfig.levelCategory);
      clientData.storageConditions.addAll(data.baseStorage);
    }
    clientData.transportConditions.removeWhere((c) =>
        c.entityId.toString() == product.id.toString() &&
        c.level == _kTransportConfig.levelProduct);
    clientData.transportConditions.addAll(data.ownTransport);
    if (data.categoryId.isNotEmpty) {
      clientData.transportConditions.removeWhere((c) =>
          c.entityId.toString() == data.categoryId &&
          c.level == _kTransportConfig.levelCategory);
      clientData.transportConditions.addAll(data.baseTransport);
    }

    clientData.buildIndexes();
    setState(() {
      _hasLocalChanges = false;
      _isSaving = false;
    });
  }

  Future<void> _commitChanges() async {
    if (_pendingChanges.isEmpty) return;
    setState(() => _isSaving = true);
    final Map<String, PendingChange> uniqueChanges = {};
    for (var change in _pendingChanges) {
      uniqueChanges['${change.sheetName}_${change.entityId}_${change.level}'] =
          change;
    }
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? userPhone = authProvider.currentUser?.phone;
      if (userPhone == null || userPhone.isEmpty)
        throw Exception('Нет телефона');
      bool allSuccess = true;
      for (var change in uniqueChanges.values) {
        final success = await _apiService.saveConditions(
            phone: userPhone,
            sheetName: change.sheetName,
            entityId: change.entityId,
            level: change.level,
            items: change.items);
        if (!success) allSuccess = false;
      }
      await authProvider.saveToCache();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(allSuccess ? 'Сохранено' : 'Ошибка'),
            backgroundColor: allSuccess ? Colors.green : Colors.red));
      _pendingChanges.clear();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- ДИАЛОГИ ---

  void _showImageSourceDialog() {
    showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('URL'),
                  onTap: () {
                    Navigator.pop(context);
                    _showUrlDialog();
                  }),
              ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('Файл'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  }),
              if (_currentData.photoUrl.isNotEmpty)
                ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Удалить'),
                    onTap: () {
                      setState(() {
                        _currentData.photoUrl = '';
                        _currentData.imageBytes = null;
                        _hasLocalChanges = true;
                      });
                      Navigator.pop(context);
                    })
            ])));
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _currentData.imageBytes = result.files.first.bytes;
          _currentData.photoUrl = '';
          _hasLocalChanges = true;
        });
      }
    } catch (e) {
      debugPrint('Ошибка: $e');
    }
  }

  void _showUrlDialog() {
    final tempController = TextEditingController(text: _currentData.photoUrl);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('URL'),
                content: TextField(controller: tempController),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                  TextButton(
                      onPressed: () {
                        setState(() {
                          _currentData.photoUrl = tempController.text.trim();
                          _currentData.imageBytes = null;
                          _hasLocalChanges = true;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('ОК'))
                ]));
  }

  void _showCategoryDialog() {
    // Локальные контроллеры для полей ввода, чтобы они корректно обновлялись при смене категории
    final weightController = TextEditingController(text: _currentData.weight);
    final wasteController =
        TextEditingController(text: _currentData.wastePercentage.toString());
    final multController =
        TextEditingController(text: _currentData.multiplicity.toString());
    final packController = TextEditingController(
        text: _currentData
            .packagingName); // Убедитесь, что поле есть в ProductFormData

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Категория'),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                // 1. СПИСОК КАТЕГОРИЙ С НОВЫМ СТИЛЕМ
                DropdownButtonFormField<String>(
                    initialValue: _currentData.categoryName.isEmpty
                        ? null
                        : _currentData.categoryName,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Категория *', border: OutlineInputBorder()),
                    selectedItemBuilder: (context) {
                      return _categories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.name,
                          child: Text(c.name,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList();
                    },
                    items: _categories.map((c) {
                      final isSelected = c.name == _currentData.categoryName;
                      final textColor =
                          isSelected ? Colors.white : Colors.black87;
                      final nameColor =
                          isSelected ? Colors.white70 : Colors.black87;
                      final bgColor = isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent;

                      return DropdownMenuItem<String>(
                          value: c.name,
                          child: Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(c.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: nameColor)),
                          ));
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _currentData.categoryName = val;
                        final cat =
                            _categories.firstWhere((c) => c.name == val);
                        _currentData.categoryId = cat.id.toString();

                        // Обновляем контроллеры новыми данными из выбранной категории
                        weightController.text = cat.weight > 0
                            ? cat.weight.toString()
                            : _currentData.weight;
                        wasteController.text = cat.wastePercentage.toString();
                        multController.text = cat.packagingQuantity.toString();
                        packController.text = cat.packagingName.isNotEmpty
                            ? cat.packagingName
                            : '';

                        // Обновляем данные формы
                        if (cat.weight > 0)
                          _currentData.weight = weightController.text;
                        if (cat.unit.isNotEmpty) _currentData.unit = cat.unit;
                        _currentData.wastePercentage = cat.wastePercentage;
                        _currentData.multiplicity = cat.packagingQuantity;
                        _currentData.packagingName =
                            cat.packagingName; // Сохраняем тару

                        final clientData =
                            Provider.of<AuthProvider>(context, listen: false)
                                .clientData;
                        final String catIdStr = cat.id.toString();
                        if (catIdStr.isNotEmpty && clientData != null) {
                          _currentData.baseFillings = clientData.compositions
                              .where((c) =>
                                  c.sheetName == 'Категории прайса' &&
                                  c.entityId.toString() == catIdStr)
                              .toList();
                          for (var f in _currentData.baseFillings) {
                            _currentData.baseFillingCompositionsMap[
                                f.id
                                    .toString()] = clientData.compositions
                                .where((c) =>
                                    c.sheetName == 'Начинки' &&
                                    c.entityId.toString() == f.id.toString())
                                .toList();
                          }
                          _currentData.baseStorage = clientData
                              .storageConditions
                              .where((c) =>
                                  c.entityId.toString() == catIdStr &&
                                  c.level == _kStorageConfig.levelCategory)
                              .toList();
                          _currentData.baseTransport = clientData
                              .transportConditions
                              .where((c) =>
                                  c.entityId.toString() == catIdStr &&
                                  c.level == _kTransportConfig.levelCategory)
                              .toList();
                        } else {
                          _currentData.baseFillings = [];
                          _currentData.baseFillingCompositionsMap.clear();
                          _currentData.baseStorage = [];
                          _currentData.baseTransport = [];
                        }
                        _refreshTails();
                        _hasLocalChanges = true;
                      });
                      // Перерисовываем диалог, чтобы обновились значения в полях ниже
                      Navigator.pop(context);
                      _showCategoryDialog();
                    }),

                const SizedBox(height: 12),

                // 2. ВЕС
                TextFormField(
                    controller: weightController,
                    decoration: const InputDecoration(
                        labelText: 'Вес', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      _currentData.weight = val;
                      _hasLocalChanges = true;
                    }),

                const SizedBox(height: 12),

                // 3. ФАСОВКА В ТАРЕ (КРАТНОСТЬ)
                TextFormField(
                    controller: multController,
                    decoration: const InputDecoration(
                        labelText: 'Фасовка в таре (шт)',
                        border: OutlineInputBorder(),
                        helperText: 'Сколько штук в одном контейнере/банке'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      _currentData.multiplicity = int.tryParse(val) ?? 1;
                      _hasLocalChanges = true;
                    }),

                const SizedBox(height: 12),

                // 4. НАИМЕНОВАНИЕ УПАКОВКИ (ТАРА)
                TextFormField(
                    controller: packController,
                    decoration: const InputDecoration(
                        labelText: 'Тара',
                        border: OutlineInputBorder(),
                        helperText: 'Например: Транспортный контейнер, банка'),
                    onChanged: (val) {
                      _currentData.packagingName = val;
                      _hasLocalChanges = true;
                    }),

                const SizedBox(height: 12),

                // 5. ИЗДЕРЖКИ
                TextFormField(
                    controller: wasteController,
                    decoration: const InputDecoration(
                        labelText: 'Издержки (%)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      _currentData.wastePercentage = int.tryParse(val) ?? 10;
                      _hasLocalChanges = true;
                    }),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Готово'))
              ],
            ));
  }

  void _showDescriptionDialog() {
    final tempController =
        TextEditingController(text: _currentData.description);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Описание'),
                content: TextField(
                    controller: tempController,
                    maxLines: 5,
                    onChanged: (val) {
                      _currentData.description = val;
                      _hasLocalChanges = true;
                    }),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Готово'))
                ]));
  }

  void _showListActionSheet(_ListButtonConfig config) {
    final data = _currentData;
    int baseCount = 0;
    int ownCount = 0;

    if (config.isStorage) {
      baseCount = data.baseStorage.length;
      ownCount = data.ownStorage.length;
    } else if (config.isTransport) {
      baseCount = data.baseTransport.length;
      ownCount = data.ownTransport.length;
    } else if (config.sheetName == _kFillingConfig.sheetName) {
      baseCount = data.baseFillings.length;
      ownCount = (data.ownData[_kFillingConfig.sheetName] ?? []).length;
    } else if (config.sheetName == _kCompositionConfig.sheetName) {
      baseCount = data.baseCompositions.length;
      ownCount = (data.ownData[_kCompositionConfig.sheetName] ?? []).length;
    }

    final String categoryLabel =
        '${config.title} категории (${data.categoryName})';
    final String productLabel =
        data.name.isNotEmpty ? '${config.title} товара' : 'Собственные';

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        builder: (context) => SafeArea(
                child: Wrap(children: [
              Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(config.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              if (baseCount > 0)
                ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(categoryLabel),
                    subtitle: Text('$baseCount записей'),
                    onTap: () {
                      Navigator.pop(context);
                      _showListDialog(config, isBase: true);
                    }),
              ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(productLabel),
                  subtitle: Text('$ownCount записей'),
                  onTap: () {
                    Navigator.pop(context);
                    _showListDialog(config, isBase: false);
                  }),
              const SizedBox(height: 8),
              ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Отмена'),
                  onTap: () => Navigator.pop(context)),
            ])));
  }

  void _showListDialog(_ListButtonConfig config, {bool isBase = false}) {
    final data = _currentData;
    List<dynamic> sourceList = [];

    if (config.isStorage) {
      sourceList = isBase ? data.baseStorage : data.ownStorage;
    } else if (config.isTransport) {
      sourceList = isBase ? data.baseTransport : data.ownTransport;
    } else if (config.sheetName == _kFillingConfig.sheetName) {
      sourceList =
          isBase ? data.baseFillings : (data.ownData[config.sheetName] ?? []);
    } else if (config.sheetName == _kCompositionConfig.sheetName) {
      sourceList = isBase
          ? data.baseCompositions
          : (data.ownData[config.sheetName] ?? []);
    }

    List<dynamic> editableList = List.from(sourceList);
    final String dialogTitle = isBase
        ? '${config.title} (${data.categoryName})'
        : '${config.title} (${data.name})';

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(dialogTitle,
                                style: const TextStyle(fontSize: 16))),
                        IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.green, size: 28),
                            onPressed: () {
                              setDialogState(() {
                                final newId = DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString();
                                final currentLevel = isBase
                                    ? config.levelCategory
                                    : config.levelProduct;
                                final currentEntityId =
                                    isBase ? data.categoryId : data.productId;
                                if (config.isStorage) {
                                  editableList.add(StorageCondition(
                                      level: currentLevel,
                                      entityId: currentEntityId));
                                } else if (config.isTransport) {
                                  editableList.add(TransportCondition(
                                      sheetName: config.sheetName,
                                      entityId: currentEntityId,
                                      level: currentLevel));
                                } else {
                                  editableList.add(Composition(
                                      id: newId,
                                      sheetName: config.sheetName,
                                      level: currentLevel,
                                      entityId: currentEntityId));
                                }
                              });
                            }),
                      ]),
                  content: SizedBox(
                      width: double.maxFinite,
                      height: 500,
                      child: Column(children: [
                        if (isBase)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        'Влияет на все товары категории',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12)))
                              ])),
                        Expanded(
                            child: editableList.isEmpty
                                ? Center(
                                    child: Text(
                                        'Нет записей.\nНажмите + для добавления.',
                                        textAlign: TextAlign.center,
                                        style:
                                            TextStyle(color: Colors.grey[400])))
                                : ListView.separated(
                                    itemCount: editableList.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 16),
                                    itemBuilder: (context, index) {
                                      final item = editableList[index];
                                      return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                                child: _buildEditableFields(
                                                    config, item)),
                                            // ЕСЛИ ЭТО НАЧИНКА - ДОБАВЛЯЕМ КНОПКУ "СОСТАВ"
                                            if (config.sheetName ==
                                                _kFillingConfig.sheetName)
                                              IconButton(
                                                  icon: const Icon(
                                                      Icons.list_alt_outlined,
                                                      color: Colors.blue,
                                                      size: 20),
                                                  tooltip: 'Состав начинки',
                                                  onPressed: () =>
                                                      _showFillingCompositionDialog(
                                                          item, isBase)),
                                            SizedBox(
                                                width:
                                                    32, // Жестко ограничиваем ширину кнопки удаления
                                                height: 32,
                                                child: IconButton(
                                                    icon: Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red[300],
                                                        size: 20),
                                                    onPressed: () =>
                                                        setDialogState(() =>
                                                            editableList
                                                                .removeAt(
                                                                    index))))
                                          ]);
                                    })),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена')),
                    ElevatedButton(
                        onPressed: () {
                          setState(() {
                            if (config.isStorage) {
                              if (isBase)
                                data.baseStorage =
                                    editableList.cast<StorageCondition>();
                              else
                                data.ownStorage =
                                    editableList.cast<StorageCondition>();
                            } else if (config.isTransport) {
                              if (isBase)
                                data.baseTransport =
                                    editableList.cast<TransportCondition>();
                              else
                                data.ownTransport =
                                    editableList.cast<TransportCondition>();
                            } else if (config.sheetName ==
                                _kFillingConfig.sheetName) {
                              if (isBase)
                                data.baseFillings =
                                    editableList.cast<Composition>();
                              else
                                data.ownData[config.sheetName] =
                                    editableList.cast<Composition>();
                            } else if (config.sheetName ==
                                _kCompositionConfig.sheetName) {
                              if (isBase)
                                data.baseCompositions =
                                    editableList.cast<Composition>();
                              else
                                data.ownData[config.sheetName] =
                                    editableList.cast<Composition>();
                            }
                            _refreshTails();
                            _hasLocalChanges = true;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Сохранить')),
                  ],
                )));
  }

  // --- НОВЫЙ ДИАЛОГ ДЛЯ ВЛОЖЕННОГО СОСТАВА НАЧИНКИ ---
  void _showFillingCompositionDialog(Composition filling, bool isBaseFilling) {
    final data = _currentData;
    // Берем существующий состав начинки или пустой список
    final Map<String, List<Composition>> targetMap = isBaseFilling
        ? data.baseFillingCompositionsMap
        : data.ownFillingCompositionsMap;
    List<dynamic> editableCompList =
        List.from(targetMap[filling.id.toString()] ?? []);

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text('Состав: ${filling.displayName}',
                                style: const TextStyle(fontSize: 16))),
                        IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.green, size: 28),
                            onPressed: () {
                              setDialogState(() {
                                editableCompList.add(Composition(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  sheetName: 'Состав',
                                  level:
                                      'Начинки', // Указываем, что это состав начинки
                                  entityId: filling.id
                                      .toString(), // Привязываем к ID начинки
                                ));
                              });
                            }),
                      ]),
                  content: SizedBox(
                      width: double.maxFinite,
                      height: 400,
                      child: editableCompList.isEmpty
                          ? Center(
                              child: Text('Нет ингредиентов.\nНажмите +',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[400])))
                          : ListView.separated(
                              itemCount: editableCompList.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 12),
                              itemBuilder: (context, index) {
                                final item = editableCompList[index];
                                return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            TextField(
                                                controller:
                                                    TextEditingController(
                                                        text: item.displayName),
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: 'Ингредиент',
                                                        isDense: true),
                                                onChanged: (v) {
                                                  item.description = v;
                                                  item.ingredientName = v;
                                                }),
                                            const SizedBox(height: 4),
                                            Row(children: [
                                              Expanded(
                                                  child: TextField(
                                                      controller:
                                                          TextEditingController(
                                                              text: item
                                                                  .quantity
                                                                  .toString()),
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Кол-во',
                                                              isDense: true),
                                                      keyboardType:
                                                          TextInputType.number,
                                                      onChanged: (v) {
                                                        item.quantity =
                                                            double.tryParse(
                                                                    v) ??
                                                                0;
                                                      })),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: TextField(
                                                      controller:
                                                          TextEditingController(
                                                              text: item
                                                                  .unitSymbol),
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Ед.изм.',
                                                              isDense: true),
                                                      onChanged: (v) {
                                                        item.unitSymbol = v;
                                                      })),
                                            ])
                                          ])),
                                      SizedBox(
                                          width:
                                              32, // Жестко ограничиваем ширину кнопки удаления
                                          height: 32,
                                          child: IconButton(
                                              icon: Icon(Icons.delete_outline,
                                                  color: Colors.red[300],
                                                  size: 20),
                                              onPressed: () => setDialogState(
                                                  () => editableCompList
                                                      .removeAt(index))))
                                    ]);
                              })),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена')),
                    ElevatedButton(
                        onPressed: () {
                          setState(() {
                            targetMap[filling.id.toString()] =
                                editableCompList.cast<Composition>();
                            _hasLocalChanges = true;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Сохранить состав')),
                  ],
                )));
  }

  Widget _buildEditableFields(_ListButtonConfig config, dynamic item) {
    if (item is StorageCondition) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            controller: TextEditingController(text: item.storageLocation),
            decoration:
                const InputDecoration(labelText: 'Место', isDense: true),
            onChanged: (v) {
              item.storageLocation = v;
            }),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              flex: 2,
              child: TextField(
                  controller: TextEditingController(text: item.temperature),
                  decoration: const InputDecoration(
                      labelText: 'Температура', isDense: true),
                  onChanged: (v) {
                    item.temperature = v;
                  })),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: TextField(
                  controller: TextEditingController(text: item.shelfLife),
                  decoration:
                      const InputDecoration(labelText: 'Срок', isDense: true),
                  onChanged: (v) {
                    item.shelfLife = v;
                  })),
          const SizedBox(width: 8),
          Expanded(
              flex: 1,
              child: UnitSelector(
                mode: UnitSelectorMode.time,
                selectedUnit: item.unit,
                onUnitSelected: (v) {
                  if (v != null) item.unit = v;
                },
              )),
        ]),
      ]);
    }
    if (item is TransportCondition) {
      return TextField(
          controller: TextEditingController(text: item.description),
          decoration: const InputDecoration(
              labelText: 'Описание условия', isDense: true),
          maxLines: 2,
          onChanged: (v) {
            item.description = v;
          });
    }
    if (item is Composition) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            controller: TextEditingController(text: item.displayName),
            decoration:
                const InputDecoration(labelText: 'Название', isDense: true),
            onChanged: (v) {
              item.description = v;
              item.ingredientName = v;
            }),
        if (config.showQuantity || config.showUnit)
          Padding(
              padding: const EdgeInsets.only(top: 8.0),
              // 🔥 ЗАМЕНИЛИ Row НА Wrap ДЛЯ АДАПТИВНОСТИ
              child: Wrap(
                spacing: 8, // Отступ по горизонтали между элементами
                runSpacing:
                    8, // Отступ по вертикали при переносе на новую строку
                children: [
                  if (config.showQuantity)
                    SizedBox(
                        width: 80, // Фиксированная ширина для количества
                        child: TextField(
                            controller: TextEditingController(
                                text: item.quantity.toString()),
                            decoration: const InputDecoration(
                                labelText: 'Кол-во', isDense: true),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              item.quantity = double.tryParse(v) ?? 0;
                            })),
                  if (config.showUnit)
                    SizedBox(
                      width: 100, // Фиксированная ширина для селектора единиц
                      child: UnitSelector(
                        mode: UnitSelectorMode.ingredients,
                        selectedUnit: item.unitSymbol,
                        onUnitSelected: (v) {
                          if (v != null) item.unitSymbol = v;
                        },
                      ),
                    ),
                ],
              )),
      ]);
    }
    return const SizedBox.shrink();
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    if (_allProducts.isEmpty) {
      return Scaffold(
          appBar: AppBar(title: const Text('Загрузка...')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _currentIndex > 0
                    ? () => _goToPage(_currentIndex - 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
            Text('${_currentIndex + 1} / ${_allProducts.length}'),
            IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _currentIndex < _allProducts.length - 1
                    ? () => _goToPage(_currentIndex + 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ]),
          actions: [
            IconButton(
                icon: Icon(Icons.save,
                    color: _hasLocalChanges ? Colors.orange : null),
                onPressed: _isSaving ? null : _saveItemLocally)
          ]),
      body: PopScope(
          canPop: !_hasLocalChanges,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (_hasLocalChanges) {
              final save = await showDialog<bool>(
                  context: context,
                  builder: (ctx) =>
                      AlertDialog(title: const Text('Сохранить?'), actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Нет')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Да'))
                      ]));
              if (save == true) _saveItemLocally();
            }
            if (_pendingChanges.isNotEmpty) {
              final send = await showDialog<bool>(
                  context: context,
                  builder: (ctx) =>
                      AlertDialog(title: const Text('Отправить?'), actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Стереть')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Отправить'))
                      ]));
              if (send == true)
                await _commitChanges();
              else
                _pendingChanges.clear();
            }
          },
          child: PageView.builder(
              controller: _pageController,
              itemCount: _allProducts.length,
              onPageChanged: (i) {
                if (_hasLocalChanges) _saveItemLocally();
                _loadDataForIndex(i);
                setState(() => _currentIndex = i);
              },
              itemBuilder: (c, i) => _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                          key: ValueKey('f_$i'),
                          child: _buildGeneralBlock())))),
    );
  }

  Widget _buildGeneralBlock() {
    final data = _currentData;
    return Card(
        elevation: 2,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextFormField(
                  initialValue: data.name,
                  decoration: const InputDecoration(labelText: 'Название *'),
                  validator: (v) => v!.isEmpty ? 'Введите' : null,
                  onChanged: (v) {
                    data.name = v;
                    _hasLocalChanges = true;
                  }),
              const SizedBox(height: 12),
              IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Expanded(
                        flex: 2,
                        child: Column(children: [
                          ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 350),
                              child: GestureDetector(
                                  onTap: _showImageSourceDialog,
                                  child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey.shade300)),
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          child: _buildPhotoView(data))))),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveItemLocally,
                              icon: const Icon(Icons.save, size: 18),
                              label: Text(
                                  _hasLocalChanges
                                      ? 'Сохранить'
                                      : 'Нет изменений',
                                  style: const TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  backgroundColor: _hasLocalChanges
                                      ? Colors.green
                                      : Colors.grey)),
                        ])),
                    const SizedBox(width: 12),
                    Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              TextFormField(
                                  initialValue: data.price.toString(),
                                  decoration: const InputDecoration(
                                      labelText: 'Цена *', isDense: true),
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      v!.isEmpty ? 'Укажите' : null,
                                  onChanged: (v) {
                                    data.price = double.tryParse(v) ?? 0;
                                    _hasLocalChanges = true;
                                  }),
                              const SizedBox(height: 4),
                              TextFormField(
                                  initialValue: data.multiplicity.toString(),
                                  decoration: const InputDecoration(
                                      labelText: 'Кратность', isDense: true),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    data.multiplicity = int.tryParse(v) ?? 1;
                                    _hasLocalChanges = true;
                                  }),
                              const Divider(height: 16, thickness: 1),
                              _buildParamButton(
                                  icon: Icons.category,
                                  title: 'Категория',
                                  subtitle: data.categoryName.isEmpty
                                      ? '-'
                                      : data.categoryName,
                                  onTap: _showCategoryDialog),
                              const SizedBox(height: 4),
                              _buildParamButton(
                                  icon: Icons.scale,
                                  title: 'Вес',
                                  subtitle: '${data.weight} ${data.unit}',
                                  onTap: _showCategoryDialog),
                              const SizedBox(height: 4),
                              _buildParamButton(
                                  icon: Icons.description,
                                  title: 'Описание',
                                  subtitle:
                                      data.description.isEmpty ? '-' : 'Есть',
                                  onTap: _showDescriptionDialog),
                              const SizedBox(height: 12),
                              const Divider(height: 1, thickness: 1),
                              const SizedBox(height: 8),
                              _buildListButton(
                                  icon: Icons.restaurant_menu,
                                  title:
                                      'Состав ($_ownCompositionsCount / $_baseCompositionsCount)',
                                  onTap: () => _showListActionSheet(
                                      _kCompositionConfig)),
                              const SizedBox(height: 4),
                              _buildListButton(
                                  icon: Icons.cake,
                                  title:
                                      'Начинки ($_ownFillingsCount / $_baseFillingsCount)',
                                  onTap: () =>
                                      _showListActionSheet(_kFillingConfig)),
                              const SizedBox(height: 4),
                              _buildListButton(
                                  icon: Icons.inventory_2,
                                  title:
                                      'Хранение ($_ownStorageCount / $_baseStorageCount)',
                                  onTap: () =>
                                      _showListActionSheet(_kStorageConfig)),
                              const SizedBox(height: 4),
                              _buildListButton(
                                  icon: Icons.local_shipping,
                                  title:
                                      'Транспорт ($_ownTransportCount / $_baseTransportCount)',
                                  onTap: () =>
                                      _showListActionSheet(_kTransportConfig)),
                            ]))),
                  ])),
            ])));
  }

  Widget _buildPhotoView(ProductFormData data) {
    if (data.imageBytes != null)
      return Image.memory(data.imageBytes!, fit: BoxFit.cover);
    String p = data.photoUrl.trim();
    if (p.isEmpty &&
        _allProducts.isNotEmpty &&
        _currentIndex < _allProducts.length)
      p = 'assets/images/products/${_allProducts[_currentIndex].id}.webp';
    if (p.isNotEmpty) {
      if (p.startsWith('http'))
        return Image.network(p,
            fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildEmptyPhoto());
      return Image.asset(p.startsWith('assets/') ? p : 'assets/$p',
          fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildEmptyPhoto());
    }
    return _buildEmptyPhoto();
  }

  Widget _buildEmptyPhoto() =>
      Center(child: Icon(Icons.add_a_photo, size: 40, color: Colors.grey[600]));

  Widget _buildParamButton(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300)),
            child: Row(children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color),
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 9, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1)
                  ])),
              Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400)
            ])));
  }

  Widget _buildListButton(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300)),
            child: Row(children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodyLarge?.color),
                      overflow: TextOverflow.ellipsis)),
              Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400)
            ])));
  }

  void _goToPage(int index) {
    if (_hasLocalChanges) _saveItemLocally();
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }
}
