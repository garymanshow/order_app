import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import '../../models/client_data.dart';
import '../../models/composition.dart';
import '../../models/ingredient_info.dart';
import '../../models/price_item.dart';
import '../../models/price_category.dart';
import '../../models/unit_of_measure.dart';

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

  // Контроллеры
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _multiplicityController;
  late TextEditingController _photoUrlController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _categoryIdController;
  late TextEditingController _unitController;
  late TextEditingController _weightController;
  late TextEditingController _wastePercentageController;

  // Состояние
  List<IngredientInfo> _ingredients = [];
  bool _isSaving = false;
  Uint8List? _imageBytes;

  // Данные
  List<PriceCategory> _categories = [];
  List<UnitOfMeasure> _units = [];

  // === НОВОЕ: Для навигации ===
  List<Product> _allProducts = [];
  late PageController _pageController;
  int _currentIndex = 0;
  bool _hasChanges = false; // Флаг несохраненных изменений

  final Map<String, String> _unitCategoryLabels = {
    'weight': '⚖️ Вес',
    'volume': '🧪 Объем',
    'piece': '📦 Штуки',
  };

  @override
  void initState() {
    super.initState();

    // Инициализируем контроллеры пустыми значениями (для PageView)
    _initControllers();

    // Загружаем данные
    _loadInitialData().then((_) {
      // После загрузки данных находим индекс текущего товара
      _initPageIndex();
    });
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _priceController = TextEditingController();
    _multiplicityController = TextEditingController();
    _photoUrlController = TextEditingController();
    _descriptionController = TextEditingController();
    _categoryController = TextEditingController();
    _categoryIdController = TextEditingController();
    _unitController = TextEditingController();
    _weightController = TextEditingController();
    _wastePercentageController = TextEditingController();
  }

  void _initPageIndex() {
    if (_allProducts.isEmpty) return;

    // Находим индекс товара в списке
    final idToFind = widget.item?.id;
    if (idToFind != null && idToFind.isNotEmpty) {
      final index = _allProducts.indexWhere((p) => p.id == idToFind);
      if (index != -1) {
        _currentIndex = index;
      }
    }

    // Инициализируем контроллер страницы
    _pageController = PageController(initialPage: _currentIndex);

    // Загружаем данные для текущей страницы
    _loadDataForIndex(_currentIndex);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _multiplicityController.dispose();
    _photoUrlController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _categoryIdController.dispose();
    _unitController.dispose();
    _weightController.dispose();
    _wastePercentageController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ==========================================
  // ЗАГРУЗКА ДАННЫХ
  // ==========================================

  Future<void> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData;
    if (clientData == null) return;

    setState(() {
      _categories = clientData.priceCategories;
      _units = clientData.unitsOfMeasure;
      _allProducts = clientData.products; // Сохраняем полный список
    });
  }

  void _loadDataForIndex(int index) {
    if (index < 0 || index >= _allProducts.length) return;

    final product = _allProducts[index];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clientData = authProvider.clientData;

    // Заполняем контроллеры
    setState(() {
      _nameController.text = product.name;
      _priceController.text = product.price.toString();
      _multiplicityController.text = product.multiplicity.toString();
      _photoUrlController.text = product.imageUrl ?? '';
      _descriptionController.text = product.composition ?? '';
      _categoryController.text = product.categoryName ?? '';
      _categoryIdController.text = product.categoryId;
      _unitController.text = 'г'; // Дефолт
      _weightController.text = product.weight;
      _wastePercentageController.text = product.wastePercentage.toString();

      _imageBytes = null; // Сброс локального фото
      _hasChanges = false; // Сброс флага изменений
    });

    // Загрузка связанных данных (категории и т.д.)
    _loadRelatedDataForProduct(product, clientData);
  }

  void _loadRelatedDataForProduct(Product product, ClientData? clientData) {
    if (clientData == null) return;

    // Поиск категории
    PriceCategory? productCategory;
    if (product.categoryId.isNotEmpty) {
      try {
        productCategory = _categories.firstWhere(
            (c) => c.id.toString().trim() == product.categoryId.trim());
      } catch (_) {}
    }

    // Ингредиенты
    final ingredients = clientData.compositions
        .where(
            (comp) => comp.sheetName == 'Состав' && comp.entityId == product.id)
        .map((comp) => IngredientInfo(
            name: comp.ingredientName,
            quantity: comp.quantity,
            unit: comp.unitSymbol))
        .toList();

    setState(() {
      _ingredients = ingredients;
      if (productCategory != null) {
        if (productCategory.weight > 0)
          _weightController.text = productCategory.weight.toString();
        if (productCategory.unit.isNotEmpty)
          _unitController.text = productCategory.unit;
        _wastePercentageController.text =
            productCategory.wastePercentage.toString();
      }
    });
  }

  // ==========================================
  // СОХРАНЕНИЕ
  // ==========================================

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final product = _allProducts[_currentIndex];

      final priceItem = PriceItem(
        id: product.id,
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text),
        category: _categoryController.text.trim(),
        unit: _unitController.text.trim(),
        weight: double.tryParse(_weightController.text) ?? 0.0,
        multiplicity: int.parse(_multiplicityController.text),
        photoUrl: _photoUrlController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _categoryIdController.text,
      );

      // Обновляем продукт в списке
      final updatedProduct = Product(
        id: priceItem.id,
        name: priceItem.name,
        price: priceItem.price,
        multiplicity: priceItem.multiplicity,
        categoryId:
            priceItem.categoryId.isNotEmpty ? priceItem.categoryId : 'default',
        imageUrl: priceItem.photoUrl,
        composition: priceItem.description,
        weight: _weightController.text,
        nutrition: '',
        storage: '',
        packaging: '',
        categoryName: priceItem.category,
        wastePercentage: int.tryParse(_wastePercentageController.text) ?? 10,
        displayName: priceItem.name,
      );

      final index = authProvider.clientData!.products
          .indexWhere((p) => p.id == product.id);
      if (index != -1) {
        authProvider.clientData!.products[index] = updatedProduct;
        _allProducts[index] = updatedProduct; // Обновляем и локальный список
        authProvider.clientData!.buildIndexes();
        await _apiService.updateProduct(updatedProduct);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'client_data', jsonEncode(authProvider.clientData!.toJson()));

      setState(() => _hasChanges = false); // Изменения сохранены

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Товар сохранен'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================
  // ДИАЛОГИ (без изменений, только используем контроллеры)
  // ==========================================

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
            if (_photoUrlController.text.isNotEmpty || _imageBytes != null)
              ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Удалить фото'),
                  onTap: () {
                    setState(() {
                      _photoUrlController.clear();
                      _imageBytes = null;
                      _hasChanges = true;
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
          _imageBytes = result.files.first.bytes;
          _photoUrlController.clear();
          _hasChanges = true;
        });
      }
    } catch (e) {
      debugPrint('Ошибка: $e');
    }
  }

  void _showUrlDialog() {
    final tempController =
        TextEditingController(text: _photoUrlController.text);
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
                        _photoUrlController.text = tempController.text.trim();
                        _imageBytes = null;
                        _hasChanges = true;
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
                  value: _categoryController.text.isNotEmpty
                      ? _categoryController.text
                      : null,
                  decoration: const InputDecoration(
                      labelText: 'Категория *', border: OutlineInputBorder()),
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c.name, child: Text(c.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _categoryController.text = val;
                      final cat = _categories.firstWhere((c) => c.name == val);
                      _categoryIdController.text = cat.id.toString();
                      if (cat.weight > 0)
                        _weightController.text = cat.weight.toString();
                      if (cat.unit.isNotEmpty) _unitController.text = cat.unit;
                      _wastePercentageController.text =
                          cat.wastePercentage.toString();
                      _hasChanges = true;
                    });
                    Navigator.pop(context);
                    _showCategoryDialog();
                  }),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  value: _unitController.text.isNotEmpty
                      ? _unitController.text
                      : null,
                  decoration: const InputDecoration(
                      labelText: 'Ед. изм. *', border: OutlineInputBorder()),
                  items: ['weight', 'volume', 'piece']
                      .map((catKey) {
                        final units =
                            _units.where((u) => u.category == catKey).toList();
                        if (units.isEmpty) return <DropdownMenuItem<String>>[];
                        return [
                          DropdownMenuItem(
                              enabled: false,
                              value: 'h_$catKey',
                              child: Text(_unitCategoryLabels[catKey]!,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor))),
                          ...units.map((u) => DropdownMenuItem(
                              value: u.symbol,
                              child: Text('${u.symbol} (${u.name})',
                                  style:
                                      const TextStyle(color: Colors.white)))),
                        ];
                      })
                      .expand((x) => x)
                      .toList(),
                  onChanged: (val) {
                    if (val != null && !val.startsWith('h_'))
                      setState(() {
                        _unitController.text = val;
                        _hasChanges = true;
                      });
                  }),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                      labelText: 'Вес', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _hasChanges = true),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _wastePercentageController,
                  decoration: const InputDecoration(
                      labelText: 'Процент издержек (%)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _hasChanges = true),
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
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Описание'),
              content: TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  onChanged: (_) => _hasChanges = true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Готово'))
              ],
            ));
  }

  void _showIngredientsDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Начинки и состав'),
              content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: ListView(children: [
                    const Text('Ингредиенты',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._ingredients.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var ing = entry.value;
                      return ListTile(
                          dense: true,
                          title: Text(ing.name),
                          subtitle: Text('${ing.quantity} ${ing.unit}'),
                          trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () {
                                setDialogState(
                                    () => _ingredients.removeAt(idx));
                                setState(() => _hasChanges = true);
                              }));
                    }),
                    TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить'),
                        onPressed: () {
                          setDialogState(() => _ingredients.add(IngredientInfo(
                              name: 'Новый', quantity: 0, unit: 'г')));
                          setState(() => _hasChanges = true);
                        }),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Готово'))
              ],
            );
          });
        });
  }

  void _showFillingsStub() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Начинки'),
                content: const Text('Будет доступно в следующей версии.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ОК'))
                ]));
  }

  void _showStorageStub() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Хранение'),
                content: const Text('Будет доступно в следующей версии.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ОК'))
                ]));
  }

  void _showTransportStub() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Транспорт'),
                content: const Text('Будет доступно в следующей версии.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ОК'))
                ]));
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    // Если список пуст, показываем индикатор
    if (_allProducts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Загрузка...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_allProducts.isEmpty
            ? 'Товар'
            : '${_currentIndex + 1} из ${_allProducts.length}'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          // Стрелка ВЛЕВО
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed:
                _currentIndex > 0 ? () => _goToPage(_currentIndex - 1) : null,
          ),
          // Стрелка ВПРАВО
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _currentIndex < _allProducts.length - 1
                ? () => _goToPage(_currentIndex + 1)
                : null,
          ),
          // Сохранить
          IconButton(
            icon: Icon(Icons.save, color: _hasChanges ? Colors.orange : null),
            onPressed: _isSaving ? null : _saveItem,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _allProducts.length,
        onPageChanged: (index) {
          _loadDataForIndex(index);
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          // Всегда рисуем форму для текущей страницы.
          // Так как мы обновляем контроллеры в onPageChanged,
          // форма автоматически покажет новые данные.
          // Но для оптимизации можно проверять index == _currentIndex

          return _isSaving
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(children: [
                      _buildGeneralBlock(),
                      // Большая кнопка сохранения внизу
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveItem,
                          icon: const Icon(Icons.save),
                          label: Text(
                              _hasChanges
                                  ? 'Сохранить изменения'
                                  : 'Нет изменений',
                              style: const TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              backgroundColor:
                                  _hasChanges ? Colors.green : Colors.grey)),
                    ]),
                  ),
                );
        },
      ),
    );
  }

  // Навигация
  void _goToPage(int index) {
    // Здесь можно добавить проверку: "У вас есть несохраненные изменения, перейти?"
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // ==========================================
  // UI БЛОК (как был, но контроллеры теперь общие)
  // ==========================================
  Widget _buildGeneralBlock() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'Название товара *'),
                validator: (v) => v!.isEmpty ? 'Введите название' : null,
                onChanged: (_) => setState(() => _hasChanges = true)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  flex: 2,
                  child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Column(children: [
                        Expanded(
                            child: GestureDetector(
                                onTap: _showImageSourceDialog,
                                child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey.shade300)),
                                    child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(7.0),
                                        child: _buildPhotoView())))),
                        const SizedBox(height: 4),
                        _buildPhotoSourceInfo(),
                      ]))),
              const SizedBox(width: 12),
              Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                                labelText: 'Цена *',
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12)),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Укажите' : null,
                            onChanged: (_) =>
                                setState(() => _hasChanges = true)),
                        const SizedBox(height: 4),
                        TextFormField(
                            controller: _multiplicityController,
                            decoration: const InputDecoration(
                                labelText: 'Кратность',
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12)),
                            keyboardType: TextInputType.number,
                            onChanged: (_) =>
                                setState(() => _hasChanges = true)),
                        const Divider(height: 16, thickness: 1),
                        _buildParamButton(
                            icon: Icons.category,
                            title: 'Категория',
                            subtitle: _categoryController.text.isEmpty
                                ? '-'
                                : _categoryController.text,
                            onTap: _showCategoryDialog),
                        const SizedBox(height: 4),
                        _buildParamButton(
                            icon: Icons.scale,
                            title: 'Вес',
                            subtitle:
                                '${_weightController.text} ${_unitController.text}',
                            onTap: _showCategoryDialog),
                        const SizedBox(height: 4),
                        _buildParamButton(
                            icon: Icons.description,
                            title: 'Описание',
                            subtitle: _descriptionController.text.isEmpty
                                ? '-'
                                : 'Есть',
                            onTap: _showDescriptionDialog),
                        const SizedBox(height: 4),
                        _buildParamButton(
                            icon: Icons.restaurant_menu,
                            title: 'Состав',
                            subtitle: '${_ingredients.length} шт.',
                            onTap: _showIngredientsDialog),
                        const SizedBox(height: 4),
                        _buildParamButton(
                            icon: Icons.cake,
                            title: 'Начинки',
                            subtitle: 'Не заданы',
                            onTap: _showFillingsStub),
                        const SizedBox(height: 4),
                        _buildParamButton(
                            icon: Icons.inventory_2,
                            title: 'Хранение',
                            subtitle: 'Не заданы',
                            onTap: _showStorageStub),
                        const SizedBox(height: 4),
                        _buildParamButton(
                            icon: Icons.local_shipping,
                            title: 'Транспорт',
                            subtitle: 'Не заданы',
                            onTap: _showTransportStub),
                      ]))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoView() {
    if (_imageBytes != null)
      return Image.memory(_imageBytes!,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    String photoPath = _photoUrlController.text.trim();
    if (photoPath.isEmpty &&
        _allProducts.isNotEmpty &&
        _currentIndex < _allProducts.length) {
      photoPath =
          'assets/images/products/${_allProducts[_currentIndex].id}.webp';
    }
    if (photoPath.isNotEmpty) {
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://'))
        return Image.network(photoPath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (c, e, s) => _buildEmptyPhoto());
      String fullPath = photoPath;
      if (!fullPath.startsWith('assets/')) fullPath = 'assets/$fullPath';
      return Image.asset(fullPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (c, e, s) => _buildEmptyPhoto());
    }
    return _buildEmptyPhoto();
  }

  Widget _buildPhotoSourceInfo() {
    String infoText;
    IconData icon;
    Color color;
    if (_imageBytes != null) {
      infoText = 'Локальное фото';
      icon = Icons.phone_android;
      color = Colors.blue;
    } else if (_photoUrlController.text.startsWith('assets/')) {
      infoText = 'Из приложения';
      icon = Icons.apps;
      color = Colors.grey;
    } else if (_photoUrlController.text.contains('drive.google')) {
      infoText = 'Из облака';
      icon = Icons.cloud;
      color = Colors.green;
    } else if (_photoUrlController.text.startsWith('http')) {
      infoText = 'С сайта';
      icon = Icons.language;
      color = Colors.orange;
    } else {
      infoText = 'Нет фото';
      icon = Icons.image_not_supported;
      color = Colors.grey;
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(infoText,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w500))
    ]);
  }

  Widget _buildEmptyPhoto() => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_a_photo, size: 40, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text('Добавить фото',
            style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 16))
      ]));

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
}
