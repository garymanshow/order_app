// lib/screens/admin_price_item_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as ImagePackage;
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/google_sheets_service.dart';
import '../services/google_drive_service.dart';
import '../models/price_item.dart';
import '../models/ingredient_info.dart';
import '../models/nutrition_info.dart';

class AdminPriceItemFormScreen extends StatefulWidget {
  final PriceItem? item; // null для создания, не null для редактирования

  const AdminPriceItemFormScreen({Key? key, this.item}) : super(key: key);

  @override
  _AdminPriceItemFormScreenState createState() =>
      _AdminPriceItemFormScreenState();
}

class _AdminPriceItemFormScreenState extends State<AdminPriceItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sheetsService = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
  final _driveService = GoogleDriveService();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _multiplicityController;
  late TextEditingController _photoUrlController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController; // ← ДОБАВЛЕНО
  late TextEditingController _unitController; // ← ДОБАВЛЕНО

  String _photoSource = 'url'; // 'url' или 'camera'
  File? _selectedImage;
  bool _isUploading = false;
  bool _hasCamera = false;
  List<String> _allProductNames = [];
  bool _isLoadingNames = false;

  List<IngredientInfo> _ingredients = [];
  List<NutritionInfo> _nutritionItems = [];
  bool _isLoadingRelatedData = false;

  @override
  void initState() {
    super.initState();
    _checkCameraAvailability();

    if (widget.item == null) {
      _loadAllProductNames();
    }

    if (widget.item != null) {
      _nameController = TextEditingController(text: widget.item!.name);
      _priceController =
          TextEditingController(text: widget.item!.price.toString());
      _multiplicityController =
          TextEditingController(text: widget.item!.multiplicity.toString());
      _photoUrlController =
          TextEditingController(text: widget.item!.photoUrl ?? '');
      _descriptionController =
          TextEditingController(text: widget.item!.description ?? '');
      _categoryController =
          TextEditingController(text: widget.item!.category); // ← ДОБАВЛЕНО
      _unitController =
          TextEditingController(text: widget.item!.unit); // ← ДОБАВЛЕНО

      if (widget.item!.photoUrl?.contains('drive.google.com') == true) {
        _photoSource = 'camera';
      }

      _loadRelatedData();
    } else {
      _nameController = TextEditingController();
      _priceController = TextEditingController();
      _multiplicityController = TextEditingController(text: '1');
      _photoUrlController = TextEditingController();
      _descriptionController = TextEditingController();
      _categoryController = TextEditingController(); // ← ДОБАВЛЕНО
      _unitController = TextEditingController(text: 'шт'); // ← ДОБАВЛЕНО
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _multiplicityController.dispose();
    _photoUrlController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose(); // ← ДОБАВЛЕНО
    _unitController.dispose(); // ← ДОБАВЛЕНО
    super.dispose();
  }

  Future<void> _checkCameraAvailability() async {
    bool hasCamera = false;

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final cameras = await availableCameras();
        hasCamera = cameras.isNotEmpty;
      } catch (e) {
        print('Ошибка проверки камеры: $e');
        hasCamera = false;
      }
    }

    setState(() {
      _hasCamera = hasCamera;
    });
  }

  Future<void> _loadAllProductNames() async {
    setState(() {
      _isLoadingNames = true;
    });

    try {
      final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
      await service.init();
      final data = await service.read(sheetName: 'Прайс-лист');

      final names = data
          .map((row) => row['Название']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();

      names.sort();
      setState(() {
        _allProductNames = names;
      });
    } catch (e) {
      print('Ошибка загрузки названий: $e');
    } finally {
      setState(() {
        _isLoadingNames = false;
      });
    }
  }

  Future<void> _loadRelatedData() async {
    if (widget.item == null) return;

    setState(() {
      _isLoadingRelatedData = true;
    });

    try {
      await _sheetsService.init();

      final ingredientsData = await _sheetsService.read(sheetName: 'Состав');
      final filteredIngredients = ingredientsData
          .where((row) => row['ID Прайс-лист']?.toString() == widget.item!.id)
          .map((row) => IngredientInfo.fromMap(row))
          .toList();

      final nutritionData = await _sheetsService.read(sheetName: 'КБЖУ');
      final filteredNutrition = nutritionData
          .where((row) => row['ID Прайс-лист']?.toString() == widget.item!.id)
          .map((row) => NutritionInfo.fromMap(row))
          .toList();

      setState(() {
        _ingredients = filteredIngredients;
        _nutritionItems = filteredNutrition;
        _isLoadingRelatedData = false;
      });
    } catch (e) {
      print('Ошибка загрузки связанных данных: $e');
      setState(() {
        _isLoadingRelatedData = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _photoSource = 'camera';
      });
    }
  }

  Future<File> _convertToPng(File imageFile) async {
    final originalImage =
        ImagePackage.decodeImage(await imageFile.readAsBytes())!;
    final resizedImage = ImagePackage.copyResize(originalImage, width: 800);
    final pngBytes = ImagePackage.encodePng(resizedImage, level: 6);
    final pngFile = File('${imageFile.path}.png');
    await pngFile.writeAsBytes(pngBytes);
    return pngFile;
  }

  Future<String?> _uploadImageToDrive(File imageFile) async {
    try {
      final pngFile = await _convertToPng(imageFile);
      await _driveService.init();
      final fileId = await _driveService.uploadFile(
        pngFile,
        mimeType: 'image/png',
        folderId: dotenv.env['GOOGLE_DRIVE_IMAGES_FOLDER_ID']!,
      );
      await _driveService.makeFilePublic(fileId);
      return _driveService.getPublicUrl(fileId);
    } catch (e) {
      print('Ошибка загрузки: $e');
      return null;
    }
  }

  Future<void> _handleCameraUpload() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    final publicUrl = await _uploadImageToDrive(_selectedImage!);

    if (publicUrl != null) {
      _photoUrlController.text = publicUrl;
      setState(() {
        _isUploading = false;
      });
    } else {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки изображения')),
        );
      }
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(IngredientInfo(name: '', quantity: 0.0, unit: 'г'));
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _updateIngredient(int index, IngredientInfo updated) {
    setState(() {
      _ingredients[index] = updated;
    });
  }

  void _addNutrition() {
    setState(() {
      _nutritionItems.add(NutritionInfo());
    });
  }

  void _removeNutrition(int index) {
    setState(() {
      _nutritionItems.removeAt(index);
    });
  }

  void _updateNutrition(int index, NutritionInfo updated) {
    setState(() {
      _nutritionItems[index] = updated;
    });
  }

  Future<void> _saveItem() async {
    if (_photoSource == 'camera' &&
        _selectedImage != null &&
        _photoUrlController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, загрузите изображение')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final item = PriceItem(
      id: '',
      name: _nameController.text.trim(),
      price: double.parse(_priceController.text),
      category: _categoryController.text.trim(), // ← ОБЯЗАТЕЛЬНОЕ ПОЛЕ
      unit: _unitController.text.trim(), // ← ОБЯЗАТЕЛЬНОЕ ПОЛЕ
      multiplicity: int.parse(_multiplicityController.text),
      photoUrl: _photoUrlController.text.trim().isNotEmpty
          ? _photoUrlController.text.trim()
          : null,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
    );

    try {
      await _sheetsService.init();

      if (widget.item != null) {
        final mainRowIndex = await _sheetsService.findRowIndexByFilters(
          sheetName: 'Прайс-лист',
          filters: [
            {'column': 'ID', 'value': widget.item!.id}
          ],
        );

        if (mainRowIndex == null) {
          throw Exception('Не найдена основная запись для обновления');
        }

        final requests = <sheets.Request>[];

        requests.add(
          await _sheetsService.createUpdateRowRequest(
            sheetName: 'Прайс-лист',
            rowIndex: mainRowIndex,
            data: item.toMap(),
          ),
        );

        final currentIngredients =
            await _sheetsService.read(sheetName: 'Состав');
        final existingIngredientRows = currentIngredients
            .asMap()
            .entries
            .where((entry) =>
                entry.value['ID Прайс-лист']?.toString() == widget.item!.id)
            .map((entry) => entry.key + 2)
            .toList();

        final compositionSheetId = await _sheetsService.getSheetId('Состав');
        final nutritionSheetId = await _sheetsService.getSheetId('КБЖУ');

        for (final rowIndex in existingIngredientRows.reversed) {
          requests.add(
            sheets.Request(
              deleteDimension: sheets.DeleteDimensionRequest(
                range: sheets.DimensionRange(
                  sheetId: compositionSheetId,
                  dimension: 'ROWS',
                  startIndex: rowIndex - 1,
                  endIndex: rowIndex,
                ),
              ),
            ),
          );
        }

        final compositionRecords = <List<dynamic>>[];
        for (final ingredient in _ingredients) {
          if (ingredient.name.isNotEmpty) {
            compositionRecords.add([
              widget.item!.id,
              ingredient.name,
              ingredient.quantity.toString(),
              ingredient.unit,
            ]);
          }
        }

        if (compositionRecords.isNotEmpty) {
          requests.add(
            await _sheetsService.createAppendRowsRequest(
              sheetName: 'Состав',
              records: compositionRecords,
            ),
          );
        }

        final currentNutrition = await _sheetsService.read(sheetName: 'КБЖУ');
        final existingNutritionRows = currentNutrition
            .asMap()
            .entries
            .where((entry) =>
                entry.value['ID Прайс-лист']?.toString() == widget.item!.id)
            .map((entry) => entry.key + 2)
            .toList();

        for (final rowIndex in existingNutritionRows.reversed) {
          requests.add(
            sheets.Request(
              deleteDimension: sheets.DeleteDimensionRequest(
                range: sheets.DimensionRange(
                  sheetId: nutritionSheetId,
                  dimension: 'ROWS',
                  startIndex: rowIndex - 1,
                  endIndex: rowIndex,
                ),
              ),
            ),
          );
        }

        final nutritionRecords = <List<dynamic>>[];
        for (final nutrition in _nutritionItems) {
          nutritionRecords.add([
            widget.item!.id,
            nutrition.calories ?? '',
            nutrition.proteins ?? '',
            nutrition.fats ?? '',
            nutrition.carbohydrates ?? '',
          ]);
        }

        if (nutritionRecords.isNotEmpty) {
          requests.add(
            await _sheetsService.createAppendRowsRequest(
              sheetName: 'КБЖУ',
              records: nutritionRecords,
            ),
          );
        }

        await _sheetsService.batchUpdate(requests);

        final updatedItem = PriceItem(
          id: widget.item!.id,
          name: item.name,
          price: item.price,
          category: item.category, // ← ОБЯЗАТЕЛЬНОЕ ПОЛЕ
          unit: item.unit, // ← ОБЯЗАТЕЛЬНОЕ ПОЛЕ
          multiplicity: item.multiplicity,
          photoUrl: item.photoUrl,
          description: item.description,
        );

        Navigator.pop(context, updatedItem);
      } else {
        final record = [
          '',
          item.name,
          item.price.toString(),
          item.category, // ← ДОБАВЛЕНО
          item.unit, // ← ДОБАВЛЕНО
          item.multiplicity.toString(),
          item.photoUrl ?? '',
          item.description ?? '',
        ];

        await _sheetsService.create(
          sheetName: 'Прайс-лист',
          records: [record],
        );

        Navigator.pop(context, true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено успешно!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
      print('Ошибка сохранения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.item != null ? 'Редактировать позицию' : 'Новая позиция'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (widget.item != null) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Название *'),
                  validator: (value) =>
                      value!.trim().isEmpty ? 'Обязательное поле' : null,
                ),
              ] else if (_isLoadingNames) ...[
                ListTile(
                  title: Text('Загрузка названий...'),
                  leading: CircularProgressIndicator(),
                ),
              ] else if (widget.item == null) ...[
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return _allProductNames;
                    }
                    return _allProductNames.where((name) {
                      final nameLower = name.toLowerCase();
                      final inputLower = textEditingValue.text.toLowerCase();
                      return nameLower.contains(inputLower);
                    }).toList();
                  },
                  onSelected: (String selection) {
                    _nameController.text = selection;
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Название *',
                        hintText: 'Введите или выберите название',
                      ),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Обязательное поле' : null,
                      onFieldSubmitted: (value) => onFieldSubmitted(),
                    );
                  },
                ),
              ],

              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Цена *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.trim().isEmpty) return 'Обязательное поле';
                  if (double.tryParse(value) == null) return 'Неверный формат';
                  return null;
                },
              ),

              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(labelText: 'Категория *'),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Обязательное поле' : null,
              ),

              TextFormField(
                controller: _unitController,
                decoration: InputDecoration(labelText: 'Единица измерения *'),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Обязательное поле' : null,
              ),

              TextFormField(
                controller: _multiplicityController,
                decoration: InputDecoration(labelText: 'Кратность *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.trim().isEmpty) return 'Обязательное поле';
                  if (int.tryParse(value) == null) return 'Неверный формат';
                  return null;
                },
              ),

              if (_hasCamera) ...[
                ListTile(
                  title: Text('Источник изображения'),
                  subtitle: Text(_photoSource == 'url' ? 'Ссылка' : 'Камера'),
                  trailing: Switch(
                    value: _photoSource == 'camera',
                    onChanged: (value) {
                      setState(() {
                        _photoSource = value ? 'camera' : 'url';
                      });
                    },
                  ),
                ),
              ],

              if (_photoSource == 'url' || !_hasCamera) ...[
                TextFormField(
                  controller: _photoUrlController,
                  decoration: InputDecoration(
                      labelText: 'Ссылка на фото (Google Drive)'),
                ),
              ],

              if (_photoSource == 'camera' && _hasCamera) ...[
                if (_selectedImage != null)
                  Image.file(_selectedImage!, height: 200, fit: BoxFit.cover),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickImage,
                  icon: Icon(Icons.camera_alt),
                  label: Text('Сделать фото'),
                ),
                if (_selectedImage != null)
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _handleCameraUpload,
                    icon: Icon(Icons.cloud_upload),
                    label: Text('Загрузить в Google Drive'),
                  ),
                if (_isUploading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 8),
                        Text('Загрузка...'),
                      ],
                    ),
                  ),
                if (_photoUrlController.text.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Загружено: ${_photoUrlController.text}'),
                  ),
              ],

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),

              // Секция Состава
              if (widget.item != null) ...[
                SizedBox(height: 24),
                Row(
                  children: [
                    Text('Состав',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: _addIngredient,
                      tooltip: 'Добавить ингредиент',
                    ),
                  ],
                ),
                if (_isLoadingRelatedData)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 8),
                        Text('Загрузка состава...'),
                      ],
                    ),
                  ),
                if (!_isLoadingRelatedData)
                  Column(
                    children: List.generate(_ingredients.length, (index) {
                      final ingredient = _ingredients[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration:
                                      InputDecoration(hintText: 'Ингредиент'),
                                  controller: TextEditingController(
                                      text: ingredient.name),
                                  onChanged: (value) {
                                    _updateIngredient(
                                        index,
                                        IngredientInfo(
                                          name: value,
                                          quantity: ingredient.quantity,
                                          unit: ingredient.unit,
                                        ));
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  decoration:
                                      InputDecoration(hintText: 'Кол-во'),
                                  controller: TextEditingController(
                                      text: ingredient.quantity.toString()),
                                  onChanged: (value) {
                                    final parsedValue =
                                        double.tryParse(value) ?? 0.0;
                                    _updateIngredient(
                                        index,
                                        IngredientInfo(
                                          name: ingredient.name,
                                          quantity: parsedValue,
                                          unit: ingredient.unit,
                                        ));
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              SizedBox(
                                width: 60,
                                child: TextField(
                                  decoration: InputDecoration(hintText: 'Ед.'),
                                  controller: TextEditingController(
                                      text: ingredient.unit),
                                  onChanged: (value) {
                                    _updateIngredient(
                                        index,
                                        IngredientInfo(
                                          name: ingredient.name,
                                          quantity: ingredient.quantity,
                                          unit: value,
                                        ));
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeIngredient(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
              ],

              // Секция КБЖУ
              if (widget.item != null) ...[
                SizedBox(height: 24),
                Row(
                  children: [
                    Text('КБЖУ',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: Colors.blue),
                      onPressed: _addNutrition,
                      tooltip: 'Добавить запись КБЖУ',
                    ),
                  ],
                ),
                if (_isLoadingRelatedData)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 8),
                        Text('Загрузка КБЖУ...'),
                      ],
                    ),
                  ),
                if (!_isLoadingRelatedData)
                  Column(
                    children: List.generate(_nutritionItems.length, (index) {
                      final nutrition = _nutritionItems[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration:
                                      InputDecoration(hintText: 'Калории'),
                                  controller: TextEditingController(
                                      text: nutrition.calories ?? ''),
                                  onChanged: (value) {
                                    _updateNutrition(
                                        index,
                                        NutritionInfo(
                                          priceListId: widget.item!.id,
                                          calories: value,
                                          proteins: nutrition.proteins,
                                          fats: nutrition.fats,
                                          carbohydrates:
                                              nutrition.carbohydrates,
                                        ));
                                  },
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration:
                                      InputDecoration(hintText: 'Белки'),
                                  controller: TextEditingController(
                                      text: nutrition.proteins ?? ''),
                                  onChanged: (value) {
                                    _updateNutrition(
                                        index,
                                        NutritionInfo(
                                          priceListId: widget.item!.id,
                                          calories: nutrition.calories,
                                          proteins: value,
                                          fats: nutrition.fats,
                                          carbohydrates:
                                              nutrition.carbohydrates,
                                        ));
                                  },
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: InputDecoration(hintText: 'Жиры'),
                                  controller: TextEditingController(
                                      text: nutrition.fats ?? ''),
                                  onChanged: (value) {
                                    _updateNutrition(
                                        index,
                                        NutritionInfo(
                                          priceListId: widget.item!.id,
                                          calories: nutrition.calories,
                                          proteins: nutrition.proteins,
                                          fats: value,
                                          carbohydrates:
                                              nutrition.carbohydrates,
                                        ));
                                  },
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration:
                                      InputDecoration(hintText: 'Углеводы'),
                                  controller: TextEditingController(
                                      text: nutrition.carbohydrates ?? ''),
                                  onChanged: (value) {
                                    _updateNutrition(
                                        index,
                                        NutritionInfo(
                                          priceListId: widget.item!.id,
                                          calories: nutrition.calories,
                                          proteins: nutrition.proteins,
                                          fats: nutrition.fats,
                                          carbohydrates: value,
                                        ));
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeNutrition(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
              ],

              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveItem,
                child: Text(widget.item != null ? 'Сохранить' : 'Добавить'),
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
