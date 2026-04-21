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

// Конфигурация кнопок списков
class _ListButtonConfig {
  final String title;
  final IconData icon;
  final String sheetName;
  final String levelCategory;
  final String levelProduct;
  final bool showQuantity;
  final bool showUnit;
  final bool isStorage;

  const _ListButtonConfig({
    required this.title,
    required this.icon,
    required this.sheetName,
    required this.levelCategory,
    required this.levelProduct,
    this.showQuantity = false,
    this.showUnit = false,
    this.isStorage = false,
  });
}

// Модель данных формы
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
  int wastePercentage;

  Map<String, List<Composition>> baseLists = {};
  Map<String, List<Composition>> ownLists = {};

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
    this.wastePercentage = 10,
  });
}

// Модель очереди изменений
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
    levelCategory: 'Начинки',
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

  // ПЕРЕМЕННЫЕ ДЛЯ ОТОБРАЖЕНИЯ "ХВОСТОВ"
  List<Composition> _ownCompositions = [];
  List<Composition> _baseCompositions = [];
  List<Composition> _ownFillings = [];
  List<Composition> _baseFillings = [];
  List<StorageCondition> _ownStorage = [];
  List<StorageCondition> _baseStorage = [];
  List<TransportCondition> _ownTransport = [];
  List<TransportCondition> _baseTransport = [];

  ProductFormData get _currentData {
    if (_currentIndex < 0 || _currentIndex >= _allProducts.length) {
      return ProductFormData(productId: '');
    }
    final id = _allProducts[_currentIndex].id;
    return _formDataMap.putIfAbsent(id, () => ProductFormData(productId: id));
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadInitialData().then((_) {
      _initPageIndex();
    });
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
          productCategory = _categories.firstWhere(
            (c) => c.id.toString() == product.categoryId,
          );
        } catch (_) {
          productCategory = null;
        }
      }

      final data = ProductFormData(
        productId: product.id,
        name: product.name,
        price: product.price,
        multiplicity: product.multiplicity,
        photoUrl: product.imageUrl ?? '',
        description: product.composition ?? '',
        categoryId: productCategory?.id.toString() ?? product.categoryId,
        categoryName: productCategory?.name ?? product.categoryName ?? '',
        unit: productCategory?.unit ?? 'г',
        weight: productCategory?.weight.toString() ?? product.weight,
        wastePercentage:
            productCategory?.wastePercentage ?? product.wastePercentage,
      );

      final configs = [
        _kTransportConfig,
        _kStorageConfig,
        _kFillingConfig,
        _kCompositionConfig
      ];

      final String productIdStr = product.id.toString();
      final String? catIdStr = productCategory?.id.toString();

      for (var config in configs) {
        if (catIdStr != null && clientData != null) {
          data.baseLists[config.sheetName] = clientData.compositions
              .where((c) =>
                  c.sheetName == config.sheetName &&
                  c.level == config.levelCategory &&
                  c.entityId == catIdStr)
              .toList();
        }
        if (clientData != null) {
          data.ownLists[config.sheetName] = clientData.compositions
              .where((c) =>
                  c.sheetName == config.sheetName &&
                  c.level == config.levelProduct &&
                  c.entityId == productIdStr)
              .toList();
        }
      }
      _formDataMap[product.id] = data;
    }

    // === ЗАГРУЗКА "ХВОСТОВ" ДЛЯ ОТОБРАЖЕНИЯ ===

    final String productIdStr = product.id.toString();

    PriceCategory? currentCategory;
    String? catIdStr;
    if (product.categoryId.isNotEmpty) {
      try {
        currentCategory = _categories
            .firstWhere((c) => c.id.toString() == product.categoryId);
        catIdStr = currentCategory.id.toString();
      } catch (_) {
        currentCategory = null;
        catIdStr = null;
      }
    }

    // === ДИАГНОСТИКА ===
    debugPrint('🔎 ДИАГНОСТИКА ФИЛЬТРАЦИИ для ${product.name}:');
    debugPrint('   Ищем ID товара: $productIdStr');
    debugPrint('   Ищем ID кат: $catIdStr');

    // Проверяем, что вообще есть в compositions
    if (clientData != null && clientData.compositions.isNotEmpty) {
      final sample = clientData.compositions.first;
      debugPrint(
          '   Пример записи в comp: entityId="${sample.entityId}" | sheet="${sample.sheetName}" | level="${sample.level}"');
    } else {
      debugPrint('   ВНИМАНИЕ: compositions пуст!');
    }
    // ==================

    // Состав
    _ownCompositions = clientData?.compositions
            .where((c) =>
                c.sheetName == 'Состав' &&
                c.entityId == productIdStr &&
                c.level == 'Прайс-лист')
            .toList() ??
        [];
    _baseCompositions = (catIdStr != null && clientData != null)
        ? clientData.compositions
            .where((c) =>
                c.sheetName == 'Состав' &&
                c.entityId == catIdStr &&
                c.level == 'Категории прайса')
            .toList()
        : [];

    // Начинки
    _ownFillings = clientData?.compositions
            .where((c) =>
                c.sheetName == 'Начинки' &&
                c.entityId == productIdStr &&
                c.level == 'Прайс-лист')
            .toList() ??
        [];
    _baseFillings = (catIdStr != null && clientData != null)
        ? clientData.compositions
            .where((c) =>
                c.sheetName == 'Начинки' &&
                c.entityId == catIdStr &&
                c.level == 'Категории прайса')
            .toList()
        : [];

    // Хранение
    // Ищем СВОИ условия
    _ownStorage = clientData?.storageConditions
            .where((c) => c.entityId == productIdStr && c.level == 'Прайс-лист')
            .toList() ??
        [];

    // Ищем БАЗОВЫЕ условия (от категории)
    if (catIdStr != null && clientData != null) {
      final rawList = clientData.storageConditions;
      debugPrint('   Всего storageConditions в базе: ${rawList.length}');

      // Пробуем найти хоть что-то с этим ID
      final foundById = rawList.where((c) => c.entityId == catIdStr).toList();
      debugPrint('   Найдено storage по ID ($catIdStr): ${foundById.length}');

      // Теперь фильтруем по level
      _baseStorage =
          foundById.where((c) => c.level == 'Категории прайса').toList();

      // Если 0, выводим какие level есть у найденных
      if (foundById.isNotEmpty && _baseStorage.isEmpty) {
        debugPrint('   ВНИМАНИЕ: Найдены записи по ID, но level не совпал!');
        debugPrint(
            '   Level в записях: ${foundById.map((e) => e.level).toSet().toList()}');
      }
    } else {
      _baseStorage = [];
    }

    // Транспорт
    _ownTransport = clientData?.transportConditions
            .where((c) => c.entityId == productIdStr && c.level == 'Прайс-лист')
            .toList() ??
        [];
    _baseTransport = (catIdStr != null && clientData != null)
        ? clientData.transportConditions
            .where(
                (c) => c.entityId == catIdStr && c.level == 'Категории прайса')
            .toList()
        : [];

    // ЛОГ
    debugPrint('🧩 ИТОГО:');
    debugPrint(
        '   Начинок: Своих=${_ownFillings.length}, От кат=${_baseFillings.length}');
    debugPrint(
        '   Состав: Своего=${_ownCompositions.length}, Базового=${_baseCompositions.length}');
    debugPrint(
        '🧊 Хранение: Своих=${_ownStorage.length}, Базового=${_baseStorage.length}');

    setState(() {
      _hasLocalChanges = false;
    });
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

    final configs = [
      _kTransportConfig,
      _kStorageConfig,
      _kFillingConfig,
      _kCompositionConfig
    ];
    for (var config in configs) {
      final newOwnList = data.ownLists[config.sheetName] ?? [];
      _pendingChanges.add(PendingChange(
        sheetName: config.sheetName,
        entityId: product.id,
        level: config.levelProduct,
        items: newOwnList.map((c) => c.toJson()).toList(),
      ));
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData!;
    for (var config in configs) {
      clientData.compositions.removeWhere((c) =>
          c.sheetName == config.sheetName &&
          c.level == config.levelProduct &&
          c.entityId == product.id);
      clientData.compositions.addAll(data.ownLists[config.sheetName] ?? []);
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
      uniqueChanges['${change.sheetName}_${change.entityId}'] = change;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? userPhone = authProvider.currentUser?.phone;

      if (userPhone == null || userPhone.isEmpty) {
        throw Exception('Не удалось определить телефон пользователя');
      }

      bool allSuccess = true;

      for (var change in uniqueChanges.values) {
        final success = await _apiService.saveConditions(
          phone: userPhone,
          sheetName: change.sheetName,
          entityId: change.entityId,
          level: change.level,
          items: change.items,
        );
        if (!success) allSuccess = false;
      }

      await authProvider.saveToCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(allSuccess
                ? 'Все изменения успешно сохранены на сервере'
                : 'Часть изменений не сохранилась'),
            backgroundColor: allSuccess ? Colors.green : Colors.orange));
      }
      _pendingChanges.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ДИАЛОГИ

  void _showImageSourceDialog() {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
              child: Wrap(children: [
            ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Вставить URL'),
                onTap: () {
                  Navigator.pop(context);
                  _showUrlDialog();
                }),
            ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Выбрать файл'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                }),
            if (_currentData.photoUrl.isNotEmpty)
              ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Удалить фото'),
                  onTap: () {
                    setState(() {
                      _currentData.photoUrl = '';
                      _currentData.imageBytes = null;
                      _hasLocalChanges = true;
                    });
                    Navigator.pop(context);
                  }),
          ]));
        });
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
              title: const Text('URL изображения'),
              content: TextField(
                  controller: tempController,
                  decoration: const InputDecoration(hintText: 'https://...')),
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
                    child: const Text('ОК')),
              ],
            ));
  }

  void _showCategoryDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Категория и параметры'),
            contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
            content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                  value: _currentData.categoryName.isEmpty
                      ? null
                      : _currentData.categoryName,
                  decoration: const InputDecoration(
                      labelText: 'Категория *', border: OutlineInputBorder()),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                          value: c.name,
                          child: Text(c.name,
                              style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _currentData.categoryName = val;
                      final cat = _categories.firstWhere((c) => c.name == val);
                      _currentData.categoryId = cat.id.toString();
                      if (cat.weight > 0)
                        _currentData.weight = cat.weight.toString();
                      if (cat.unit.isNotEmpty) _currentData.unit = cat.unit;
                      _currentData.wastePercentage = cat.wastePercentage;
                      _hasLocalChanges = true;
                    });
                    Navigator.pop(context);
                    _showCategoryDialog();
                  }),
              const SizedBox(height: 12),
              TextFormField(
                  initialValue: _currentData.weight,
                  decoration: const InputDecoration(
                      labelText: 'Вес', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    _currentData.weight = val;
                    _hasLocalChanges = true;
                  }),
              const SizedBox(height: 12),
              TextFormField(
                  initialValue: _currentData.wastePercentage.toString(),
                  decoration: const InputDecoration(
                      labelText: 'Процент издержек (%)',
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
          );
        });
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
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  onChanged: (val) {
                    _currentData.description = val;
                    _hasLocalChanges = true;
                  }),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Готово'))
              ],
            ));
  }

  void _showListDialog(_ListButtonConfig config) {
    final data = _currentData;
    List<Composition> baseList = data.baseLists[config.sheetName] ?? [];
    List<Composition> ownList =
        List.from(data.ownLists[config.sheetName] ?? []);

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(config.title),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    if (baseList.isNotEmpty)
                      ExpansionTile(
                        title: Text("Унаследовано от категории",
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14)),
                        initiallyExpanded: true,
                        children: [
                          Container(
                            color: Colors.grey[100],
                            constraints: const BoxConstraints(maxHeight: 150),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: baseList.length,
                              itemBuilder: (context, index) {
                                final item = baseList[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.lock_outline,
                                      size: 16, color: Colors.grey),
                                  title: Text(
                                      config.isStorage
                                          ? item.formattedStorage
                                          : item.displayName,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                  subtitle: config.showQuantity
                                      ? Text(
                                          '${item.quantity} ${item.unitSymbol}')
                                      : null,
                                );
                              },
                            ),
                          ),
                          const Divider(),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: Text("Индивидуальные условия",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: ownList.length + 1,
                        itemBuilder: (context, index) {
                          if (index == ownList.length) {
                            return ListTile(
                              title: TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Добавить строку'),
                                onPressed: () {
                                  setDialogState(() {
                                    ownList.add(Composition(
                                      id: DateTime.now()
                                          .millisecondsSinceEpoch
                                          .toString(),
                                      sheetName: config.sheetName,
                                      level: config.levelProduct,
                                      entityId: data.productId,
                                    ));
                                  });
                                },
                              ),
                            );
                          }

                          final item = ownList[index];
                          return Dismissible(
                            key: ValueKey(item.id),
                            onDismissed: (_) =>
                                setDialogState(() => ownList.removeAt(index)),
                            background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete,
                                    color: Colors.white)),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: TextEditingController(
                                          text: config.isStorage
                                              ? item.storagePlace
                                              : item.displayName),
                                      decoration: InputDecoration(
                                          labelText: config.isStorage
                                              ? 'Место хранения / Описание'
                                              : 'Название',
                                          border: const OutlineInputBorder(),
                                          contentPadding:
                                              const EdgeInsets.all(8)),
                                      onChanged: (val) {
                                        if (config.isStorage) {
                                          item.storagePlace = val;
                                          item.description = val;
                                        } else {
                                          item.description = val;
                                          item.ingredientName = val;
                                        }
                                      },
                                    ),
                                    if (config.showQuantity || config.showUnit)
                                      Row(
                                        children: [
                                          if (config.showQuantity)
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    TextEditingController(
                                                        text: item.quantity
                                                            .toString()),
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: 'Кол-во'),
                                                keyboardType:
                                                    TextInputType.number,
                                                onChanged: (val) => item
                                                        .quantity =
                                                    double.tryParse(val) ?? 0,
                                              ),
                                            ),
                                          if (config.showUnit)
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    TextEditingController(
                                                        text: item.unitSymbol),
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: 'Ед.изм.'),
                                                onChanged: (val) =>
                                                    item.unitSymbol = val,
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                ElevatedButton(
                    onPressed: () {
                      setState(() {
                        data.ownLists[config.sheetName] = ownList;
                        _hasLocalChanges = true;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Сохранить')),
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_allProducts.isEmpty) {
      return Scaffold(
          appBar: AppBar(title: const Text('Загрузка...')),
          body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed:
                  _currentIndex > 0 ? () => _goToPage(_currentIndex - 1) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Text('${_currentIndex + 1} / ${_allProducts.length}'),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: _currentIndex < _allProducts.length - 1
                  ? () => _goToPage(_currentIndex + 1)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.save,
                color: _hasLocalChanges ? Colors.orange : null),
            onPressed: _isSaving ? null : _saveItemLocally,
            tooltip: 'Сохранить позицию',
          ),
        ],
      ),
      body: PopScope(
        canPop: !_hasLocalChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          if (_hasLocalChanges) {
            final saveLocal = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Сохранить изменения?'),
                content: const Text(
                    'У вас есть несохраненные изменения на этой позиции.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Нет')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Да')),
                ],
              ),
            );
            if (saveLocal == true) _saveItemLocally();
          }

          if (_pendingChanges.isNotEmpty) {
            final commit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Отправить изменения?'),
                content: Text(
                    'Есть ${_pendingChanges.length} ожидающих изменений. Отправить их на сервер?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Стереть')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Отправить')),
                ],
              ),
            );

            if (commit == true) {
              await _commitChanges();
            } else {
              _pendingChanges.clear();
            }
          }
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: _allProducts.length,
          onPageChanged: (index) {
            if (_hasLocalChanges) _saveItemLocally();
            _loadDataForIndex(index);
            setState(() => _currentIndex = index);
          },
          itemBuilder: (context, index) {
            return _isSaving
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: ValueKey('form_$index'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGeneralBlock(),
                          const SizedBox(height: 16),

                          // БЛОКИ "ХВОСТОВ"
                          _buildExpansionTile(
                            title: 'Состав',
                            icon: Icons.restaurant_menu,
                            ownCount: _ownCompositions.length,
                            baseCount: _baseCompositions.length,
                            content: _buildCompositionContent(),
                          ),
                          const SizedBox(height: 8),

                          _buildExpansionTile(
                            title: 'Начинки',
                            icon: Icons.cake,
                            ownCount: _ownFillings.length,
                            baseCount: _baseFillings.length,
                            content: _buildFillingsContent(),
                          ),
                          const SizedBox(height: 8),

                          _buildExpansionTile(
                            title: 'Условия хранения',
                            icon: Icons.inventory_2,
                            ownCount: _ownStorage.length,
                            baseCount: _baseStorage.length,
                            content: _buildStorageContent(),
                          ),
                          const SizedBox(height: 8),

                          _buildExpansionTile(
                            title: 'Условия транспортировки',
                            icon: Icons.local_shipping,
                            ownCount: _ownTransport.length,
                            baseCount: _baseTransport.length,
                            content: _buildTransportContent(),
                          ),

                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveItemLocally,
                              icon: const Icon(Icons.save),
                              label: Text(
                                  _hasLocalChanges
                                      ? 'Сохранить позицию'
                                      : 'Нет изменений',
                                  style: const TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: _hasLocalChanges
                                      ? Colors.green
                                      : Colors.grey)),
                        ],
                      ),
                    ),
                  );
          },
        ),
      ),
    );
  }

  Widget _buildGeneralBlock() {
    final data = _currentData;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
                initialValue: data.name,
                decoration:
                    const InputDecoration(labelText: 'Название товара *'),
                validator: (v) => v!.isEmpty ? 'Введите название' : null,
                onChanged: (val) {
                  data.name = val;
                  _hasLocalChanges = true;
                }),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  flex: 2,
                  child: AspectRatio(
                      aspectRatio: 1.0,
                      child: GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade300)),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7.0),
                                  child: _buildPhotoView(data)))))),
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
                                labelText: 'Цена *',
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12)),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Укажите' : null,
                            onChanged: (val) {
                              data.price = double.tryParse(val) ?? 0;
                              _hasLocalChanges = true;
                            }),
                        const SizedBox(height: 4),
                        TextFormField(
                            initialValue: data.multiplicity.toString(),
                            decoration: const InputDecoration(
                                labelText: 'Кратность',
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12)),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              data.multiplicity = int.tryParse(val) ?? 1;
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
                            subtitle: data.description.isEmpty ? '-' : 'Есть',
                            onTap: _showDescriptionDialog),
                      ]))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoView(ProductFormData data) {
    if (data.imageBytes != null)
      return Image.memory(data.imageBytes!, fit: BoxFit.cover);
    String photoPath = data.photoUrl.trim();
    if (photoPath.isEmpty &&
        _allProducts.isNotEmpty &&
        _currentIndex < _allProducts.length) {
      photoPath =
          'assets/images/products/${_allProducts[_currentIndex].id}.webp';
    }
    if (photoPath.isNotEmpty) {
      if (photoPath.startsWith('http'))
        return Image.network(photoPath,
            fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildEmptyPhoto());
      String fullPath =
          photoPath.startsWith('assets/') ? photoPath : 'assets/$photoPath';
      return Image.asset(fullPath,
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
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1)
                  ])),
              Icon(Icons.chevron_right, size: 14, color: Colors.grey[400])
            ])));
  }

  // ВСПОМОГАТЕЛЬНЫЕ БЛОКИ

  Widget _buildExpansionTile({
    required String title,
    required IconData icon,
    required int ownCount,
    required int baseCount,
    required Widget content,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Своих: $ownCount, От категории: $baseCount',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: content,
          )
        ],
      ),
    );
  }

  Widget _buildCompositionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_baseCompositions.isNotEmpty) ...[
          const Text('Унаследовано от категории:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey)),
          const SizedBox(height: 4),
          ..._baseCompositions.map((c) => _buildMiniItemCard(
              c.displayName, '${c.quantity} ${c.unitSymbol}')),
          const Divider(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Собственный состав:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _showListDialog(_kCompositionConfig),
              tooltip: 'Редактировать',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          ],
        ),
        const SizedBox(height: 4),
        if (_ownCompositions.isEmpty)
          const Text('Не указан',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
        else
          ..._ownCompositions.map((c) => _buildMiniItemCard(
              c.displayName, '${c.quantity} ${c.unitSymbol}')),
      ],
    );
  }

  Widget _buildFillingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_baseFillings.isNotEmpty) ...[
          const Text('Унаследовано:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey)),
          ..._baseFillings.map((c) => _buildMiniItemCard(c.displayName, '')),
          const Divider(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Собственные: ${_ownFillings.length}'),
            IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showListDialog(_kFillingConfig))
          ],
        ),
      ],
    );
  }

  Widget _buildStorageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_baseStorage.isNotEmpty) ...[
          const Text('Унаследовано:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey)),
          ..._baseStorage.map((s) => _buildMiniItemCard(s.storageLocation,
              '${s.temperature}°C, ${s.shelfLife} ${s.unit}')),
          const Divider(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Собственные: ${_ownStorage.length}'),
            IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showListDialog(_kStorageConfig))
          ],
        ),
      ],
    );
  }

  Widget _buildTransportContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_baseTransport.isNotEmpty) ...[
          const Text('Унаследовано:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey)),
          ..._baseTransport.map((t) => _buildMiniItemCard(t.description, '')),
          const Divider(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Собственные: ${_ownTransport.length}'),
            IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showListDialog(_kTransportConfig))
          ],
        ),
      ],
    );
  }

  Widget _buildMiniItemCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _goToPage(int index) {
    if (_hasLocalChanges) _saveItemLocally();
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }
}
